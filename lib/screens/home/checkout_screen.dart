import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/booking_service.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';

// Booking State Manager
class BookingStateManager {
  static final BookingStateManager _instance = BookingStateManager._internal();
  factory BookingStateManager() => _instance;
  BookingStateManager._internal();

  final Map<String, BookingStatus> _eventBookings = {};
  final StreamController<Map<String, BookingStatus>> _bookingController =
      StreamController<Map<String, BookingStatus>>.broadcast();

  Stream<Map<String, BookingStatus>> get bookingStream => _bookingController.stream;

  void updateBookingStatus(String eventId, BookingStatus status) {
    _eventBookings[eventId] = status;
    _bookingController.add(Map.from(_eventBookings));
    _saveToPersistentStorage();
  }

  BookingStatus? getBookingStatus(String eventId) {
    return _eventBookings[eventId];
  }

  Future<void> _saveToPersistentStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingData = _eventBookings.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString('event_bookings', jsonEncode(bookingData));
    } catch (e) {
      print('Error saving booking state: $e');
    }
  }

  Future<void> loadFromPersistentStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingData = prefs.getString('event_bookings');
      if (bookingData != null) {
        final Map<String, dynamic> decoded = jsonDecode(bookingData);
        _eventBookings.clear();
        decoded.forEach((key, value) {
          _eventBookings[key] = BookingStatus.fromJson(value);
        });
        _bookingController.add(Map.from(_eventBookings));
      }
    } catch (e) {
      print('Error loading booking state: $e');
    }
  }

  void dispose() {
    _bookingController.close();
  }
}

// Booking Status Model
class BookingStatus {
  final String ticketId;
  final String status;
  final DateTime timestamp;
  final double amount;

  BookingStatus({
    required this.ticketId,
    required this.status,
    required this.timestamp,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'ticketId': ticketId,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'amount': amount,
      };

  factory BookingStatus.fromJson(Map<String, dynamic> json) => BookingStatus(
        ticketId: json['ticketId'],
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
        amount: json['amount'].toDouble(),
      );
}

// Payment Network Enum
enum PaymentNetwork { mtn, airtel }

class CheckoutScreen extends StatefulWidget {
  final Event event;
  final String ticketId;
  final double total;
  final VoidCallback? onPaymentSuccess;

  const CheckoutScreen({
    super.key,
    required this.event,
    required this.ticketId,
    required this.total,
    this.onPaymentSuccess,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool subscribeOrganizer = true;
  bool subscribeUpdates = true;
  bool _isLoading = false;
  PaymentNetwork? _selectedNetwork;
  String? _validatedPhone;
  String? _ticketId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BookingStateManager _bookingManager = BookingStateManager();
  final BookingService _bookingService = BookingService();
  StreamSubscription<Map<String, BookingStatus>>? _bookingSubscription;

  final String subscriptionKey = "aab1d593853c454c9fcec8e4e02dde3c";
  final String apiUser = "815d497c-9cb6-477c-8e30-23c3c2b3bea6";
  final String apiKey = "5594113210ab4f3da3a7329b0ae65f40";

  @override
  void initState() {
    super.initState();
    _ticketId = widget.ticketId;
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to book an event'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        });
      } else {
        _loadUserData();
        _initializeBookingState();
      }
    });
  }

  Future<void> _initializeBookingState() async {
    await _bookingManager.loadFromPersistentStorage();
    _bookingSubscription = _bookingManager.bookingStream.listen((bookings) {
      if (mounted) {
        final booking = bookings[widget.event.id];
        if (booking != null && booking.status == 'completed') {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _emailController.text = currentUser.email ?? '';
        _firstNameController.text = currentUser.displayName?.split(' ').first ?? '';
        _lastNameController.text = currentUser.displayName?.split(' ').skip(1).join(' ') ?? '';
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _firstNameController.text = prefs.getString('user_first_name') ?? '';
        _lastNameController.text = prefs.getString('user_last_name') ?? '';
        _emailController.text = prefs.getString('user_email') ?? '';
      });
    }
  }

  bool get isEventBooked {
    final booking = _bookingManager.getBookingStatus(widget.event.id);
    return booking?.status == 'completed';
  }

  Future<void> _saveBookingToFirestore(Map<String, dynamic> bookingData) async {
  try {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to book an event');
    }

    // Debug: Print current user info
    print('=== BOOKING DEBUG INFO ===');
    print('Current User UID: ${currentUser.uid}');
    print('Current User Email: ${currentUser.email}');
    print('Current User Display Name: ${currentUser.displayName}');
    print('User is anonymous: ${currentUser.isAnonymous}');
    
    // Check if user has custom claims (admin status)
    final idTokenResult = await currentUser.getIdTokenResult();
    print('User custom claims: ${idTokenResult.claims}');

    // Ensure userId is set correctly
    bookingData['userId'] = currentUser.uid;

    // Debug: Print the booking data being sent
    print('Booking data being sent to Firestore:');
    bookingData.forEach((key, value) {
      print('  $key: $value (${value.runtimeType})');
    });

    // Validate required fields for Firestore rules
    final requiredFields = ['userId', 'eventId', 'eventTitle', 'ticketId'];
    for (String field in requiredFields) {
      if (bookingData[field] == null || bookingData[field].toString().trim().isEmpty) {
        throw Exception('Missing or empty required field: $field');
      }
    }

    // Additional field mapping with better validation
    bookingData['event'] = bookingData['eventTitle'] ?? widget.event.title;
    bookingData['price'] = (bookingData['amount'] ?? widget.total).toDouble();
    bookingData['paid'] = bookingData['paymentStatus'] == 'completed';
    bookingData['eventId'] = bookingData['eventId'] ?? widget.event.id;
    bookingData['isVerified'] = widget.event.isVerified ?? false;
    bookingData['verificationStatus'] = widget.event.verificationStatus ?? 'pending';
    bookingData['ticketId'] = bookingData['ticketId'] ?? _ticketId;

    print('Final booking data after mapping:');
    bookingData.forEach((key, value) {
      print('  $key: $value');
    });

    print('Attempting to save to Firestore...');

    // Try to save to main bookings collection with better error handling
    DocumentReference? bookingRef;
    try {
      bookingRef = await _firestore.collection('bookings').add(bookingData);
      print('✅ Booking saved to main collection: ${bookingRef.id}');
    } catch (firestoreError) {
      print('❌ Error saving to main bookings collection: $firestoreError');
      
      // Check if it's a permission error
      if (firestoreError.toString().contains('permission-denied') || 
          firestoreError.toString().contains('Missing or insufficient permissions')) {
        print('🔒 This is a permission error. Checking Firestore rules...');
        
        // Log what the rules are expecting vs what we're sending
        print('Rules expect: authenticated user with userId matching auth.uid');
        print('We are sending: userId = ${bookingData['userId']}, auth.uid = ${currentUser.uid}');
        print('Match: ${bookingData['userId'] == currentUser.uid}');
      }
      
      throw firestoreError;
    }

    // Try to save to user's subcollection
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingRef!.id)
          .set(bookingData);
      print('✅ Booking saved to user subcollection');
    } catch (userSubcollectionError) {
      print('❌ Error saving to user subcollection: $userSubcollectionError');
      // Don't throw here as main booking was successful
    }

    // Save locally as backup
    await _saveBookingLocally(bookingData);
    print('✅ Booking saved locally');

    print('=== BOOKING SUCCESS ===');

  } catch (e) {
    print('=== BOOKING FAILED ===');
    print('Error details: $e');
    print('Error type: ${e.runtimeType}');
    
    // Save locally as fallback
    try {
      await _saveBookingLocally(bookingData);
      print('✅ Fallback: Booking saved locally');
    } catch (localError) {
      print('❌ Even local save failed: $localError');
    }
    
    rethrow;
  }
}

// Add this method to check user authentication status
Future<void> _debugUserAuth() async {
  final User? currentUser = _auth.currentUser;
  
  print('=== AUTH DEBUG ===');
  if (currentUser == null) {
    print('❌ No user is currently signed in');
    return;
  }
  
  print('✅ User is signed in');
  print('UID: ${currentUser.uid}');
  print('Email: ${currentUser.email}');
  print('Email Verified: ${currentUser.emailVerified}');
  print('Display Name: ${currentUser.displayName}');
  print('Phone Number: ${currentUser.phoneNumber}');
  print('Is Anonymous: ${currentUser.isAnonymous}');
  print('Provider Data: ${currentUser.providerData.map((e) => e.providerId).toList()}');
  
  try {
    final idToken = await currentUser.getIdToken();
    if (idToken != null) {
      print('✅ ID Token obtained (length: ${idToken.length})');
    } else {
      print('❌ ID Token is null');
    }
    
    final idTokenResult = await currentUser.getIdTokenResult();
    print('Token Claims: ${idTokenResult.claims}');
    print('Auth Time: ${idTokenResult.authTime}');
    print('Issued At: ${idTokenResult.issuedAtTime}');
    print('Expiration: ${idTokenResult.expirationTime}');
  } catch (tokenError) {
    print('❌ Error getting ID token: $tokenError');
  }
  
  // Test Firestore access
  try {
    await _firestore.collection('users').doc(currentUser.uid).get();
    print('✅ Can access Firestore with current auth');
  } catch (firestoreError) {
    print('❌ Cannot access Firestore: $firestoreError');
  }
}
  Future<void> _saveBookingLocally(Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_booking', jsonEncode(bookingData));
      List<String> bookings = prefs.getStringList('booking_history') ?? [];
      bookings.add(jsonEncode(bookingData));
      await prefs.setStringList('booking_history', bookings);
      await prefs.setString('user_first_name', _firstNameController.text);
      await prefs.setString('user_last_name', _lastNameController.text);
      await prefs.setString('user_email', _emailController.text);
      print('Booking saved locally successfully');
    } catch (e) {
      print('Error saving booking locally: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.total == 0) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("Free Event", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.green.shade700,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                const Text("This is a free event!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(widget.event.title, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _bookFreeEvent,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size(200, 50)),
                  child: const Text("Reserve Your Spot", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Back to Event")),
              ],
            ),
          ),
        ),
      );
    }

    if (isEventBooked) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("Already Booked ✅", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.green.shade700,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                const Text("You have already booked this event!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(widget.event.title, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _showBookingHistory(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size(200, 50)),
                  child: const Text("View My Tickets", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Back to Event")),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF81D4FA)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Checkout", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () => _showBookingHistory()),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  color: Colors.purple.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("🎫 Event Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(widget.event.title, style: const TextStyle(fontSize: 16)),
                        Text('Date: ${widget.event.date}'),
                        Text('Location: ${widget.event.location}'),
                        Text(
                          'Total: €${widget.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.total == 0.0 ? Colors.green : Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 3,
                  color: const Color.fromARGB(255, 212, 228, 245),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("💳 Booking Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: "First Name *", border: OutlineInputBorder()),
                          validator: (value) => value == null || value.trim().isEmpty ? "First name is required" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: "Last Name *", border: OutlineInputBorder()),
                          validator: (value) => value == null || value.trim().isEmpty ? "Last name is required" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: "Email Address *", border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return "Email is required";
                            if (!value.contains('@') || !value.contains('.')) return "Please enter a valid email address";
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          title: const Text("Keep me updated on more events and news from this organiser."),
                          value: subscribeOrganizer,
                          onChanged: (val) => setState(() => subscribeOrganizer = val!),
                        ),
                        CheckboxListTile(
                          title: const Text("Send me emails about the best events happening nearby or online."),
                          value: subscribeUpdates,
                          onChanged: (val) => setState(() => subscribeUpdates = val!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Mobile Money Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildNetworkCard(
                  value: PaymentNetwork.mtn,
                  title: "MTN Mobile Money",
                  image: "assets/images/mtn.jpg",
                  bgColor: Colors.yellow.shade100,
                  borderColor: Colors.orange,
                ),
                _buildNetworkCard(
                  value: PaymentNetwork.airtel,
                  title: "Airtel Money",
                  image: "assets/images/airtel.png",
                  bgColor: Colors.red.shade50,
                  borderColor: Colors.redAccent,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedNetwork == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a payment network")));
                                return;
                              }
                              _openMobileMoneyDialog(_selectedNetwork!);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Pay €${widget.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkCard({
    required PaymentNetwork value,
    required String title,
    required String image,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isSelected = _selectedNetwork == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedNetwork = value),
      child: Card(
        color: bgColor,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isSelected ? borderColor : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(image, height: 30, width: 50, fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              if (isSelected) Icon(Icons.check_circle, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }

  void _openMobileMoneyDialog(PaymentNetwork network) {
    String phone = '';
    String provider = network == PaymentNetwork.mtn ? 'MTN' : 'Airtel';
    bool isLoading = false;
    bool _hasShownToast = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Pay with $provider Mobile Money"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone Number"),
                    onChanged: (val) async {
                      phone = val;
                      if (phone.length == 10 && !_hasShownToast) {
                        setState(() {
                          isLoading = true;
                          _hasShownToast = true;
                        });
                        final token = await getAccessToken();
                        if (token != null) {
                          try {
                            await validateAccountHolder(phone, token);
                            _validatedPhone = phone;
                            Fluttertoast.showToast(
                              msg: "📲 Valid Mobile Money account. You may now proceed to Confirm Payment.",
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.TOP,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                            );
                          } catch (e) {
                            Fluttertoast.showToast(
                              msg: "❌ Invalid account or error verifying number.",
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.TOP,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                            _validatedPhone = null;
                            _hasShownToast = false;
                          }
                        }
                        setState(() => isLoading = false);
                      } else if (phone.length < 10) {
                        _hasShownToast = false;
                        _validatedPhone = null;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isLoading) const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text("Hold on as we validate your phone number has a Mobile Money account for your payment."),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (_validatedPhone != null) {
                    final token = await getAccessToken();
                    if (token != null) {
                      try {
                        await requestToPay(phoneNumber: _validatedPhone!, accessToken: token, amount: widget.total);
                        Navigator.pop(context);
                        await _bookPaidEvent();
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: "❌ Payment failed: ${e.toString()}",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    }
                  } else {
                    Fluttertoast.showToast(
                      msg: "❌ Please enter and validate a valid number first.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.TOP,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                },
                child: const Text("Confirm Payment"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookFreeEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final bookingData = {
        'ticketId': _ticketId,
        'eventId': widget.event.id,
        'eventTitle': widget.event.title,
        'event': widget.event.title,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _validatedPhone ?? '',
        'amount': 0.0,
        'price': 0.0,
        'currency': 'EUR',
        'paymentMethod': 'Free Event',
        'paymentStatus': 'completed',
        'paid': true,
        'subscribeOrganizer': subscribeOrganizer,
        'subscribeUpdates': subscribeUpdates,
        'bookingDate': Timestamp.now(),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'isVerified': widget.event.isVerified,
        'verificationStatus': widget.event.verificationStatus,
      };

      _bookingManager.updateBookingStatus(
        widget.event.id,
        BookingStatus(ticketId: _ticketId!, status: 'completed', timestamp: DateTime.now(), amount: 0.0),
      );

      await _saveBookingToFirestore(bookingData);

      Fluttertoast.showToast(
        msg: "Free event booking successful!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      await _showSuccessDialog();
    } catch (e) {
      print('Error in _bookFreeEvent: $e');
      Fluttertoast.showToast(
        msg: "Error booking event: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      _showErrorDialog(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bookPaidEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final bookingData = {
        'ticketId': _ticketId,
        'eventId': widget.event.id,
        'eventTitle': widget.event.title,
        'event': widget.event.title,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _validatedPhone,
        'amount': widget.total,
        'price': widget.total,
        'currency': 'EUR',
        'paymentMethod': _selectedNetwork == PaymentNetwork.mtn ? 'MTN Mobile Money' : 'Airtel Money',
        'paymentStatus': 'completed',
        'paid': true,
        'subscribeOrganizer': subscribeOrganizer,
        'subscribeUpdates': subscribeUpdates,
        'bookingDate': Timestamp.now(),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'isVerified': widget.event.isVerified,
        'verificationStatus': widget.event.verificationStatus,
      };

      _bookingManager.updateBookingStatus(
        widget.event.id,
        BookingStatus(
          ticketId: _ticketId!,
          status: 'completed',
          timestamp: DateTime.now(),
          amount: widget.total,
        ),
      );

      await _saveBookingToFirestore(bookingData);

      Fluttertoast.showToast(
        msg: "Booking successful!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      await _showSuccessDialog();
    } catch (e) {
      print('Error in _bookPaidEvent: $e');
      Fluttertoast.showToast(
        msg: "Error processing payment: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      _showErrorDialog(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Reservation Successful ✅", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.total == 0 ? "Your spot for ${widget.event.title} has been reserved!" : "Your Event ticket for €${widget.total.toStringAsFixed(2)}."),
            const SizedBox(height: 16),
            const Text("🎟 Your Ticket QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_ticketId != null) SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: _ticketId!, errorCorrectLevel: QrErrorCorrectLevel.M)),
            const SizedBox(height: 8),
            if (_ticketId != null) Text('QR Code for: $_ticketId'),
            const SizedBox(height: 10),
            const Text("Save or screenshot this QR for entry. Your ticket is also saved in your booking history.", style: TextStyle(fontSize: 12, color: Colors.black)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _showBookingHistory(), child: const Text("View History")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onPaymentSuccess != null) widget.onPaymentSuccess!();
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(dynamic error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Booking Failed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Failed to book ${widget.event.title}: $error"),
            const SizedBox(height: 16),
            if (_ticketId != null) ...[
              const Text("🎟 Your Ticket QR Code (Backup)", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: _ticketId!, errorCorrectLevel: QrErrorCorrectLevel.M)),
              const SizedBox(height: 8),
              Text('QR Code for: $_ticketId'),
              const SizedBox(height: 10),
              const Text("⚠️ Please screenshot this QR code as backup storage failed.", style: TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showBookingHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🎫 Booking History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUserBookingHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    final bookings = snapshot.data ?? [];
                    if (bookings.isEmpty) return const Center(child: Text('No bookings found', style: TextStyle(fontSize: 16, color: Colors.grey)));
                    return ListView.builder(
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(booking['eventTitle'] ?? 'Unknown Event'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [Text('€${booking['amount']} - ${booking['firstName']} ${booking['lastName']}'), Text('${booking['createdAt'] ?? 'Unknown date'}')],
                            ),
                            trailing: const Icon(Icons.qr_code),
                            onTap: () => _showQRCode(booking['ticketId']),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRCode(String ticketId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ticket QR Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: ticketId, errorCorrectLevel: QrErrorCorrectLevel.M)),
            const SizedBox(height: 8),
            Text('Ticket ID: $ticketId'),
            const SizedBox(height: 10),
            const Text("Present this QR code at the event", style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Future<String?> getAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/token/'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$apiUser:$apiKey'))}',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        print('Failed to get access token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  Future<bool> validateAccountHolder(String phoneNumber, String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/accountholder/msisdn/$phoneNumber/active'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'X-Target-Environment': 'sandbox',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] == true;
      }
      return false;
    } catch (e) {
      print('Error validating account holder: $e');
      return false;
    }
  }

  Future<void> requestToPay({required String phoneNumber, required String accessToken, required double amount}) async {
    try {
      final referenceId = const Uuid().v4();
      final body = jsonEncode({
        'amount': amount.toString(),
        'currency': 'EUR',
        'externalId': referenceId,
        'payer': {'partyIdType': 'MSISDN', 'partyId': phoneNumber},
        'payerMessage': 'Event ticket payment for ${widget.event.title}',
        'payeeNote': 'Ticket purchase'
      });
      final response = await http.post(
        Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Reference-Id': referenceId,
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: body,
      );
      if (response.statusCode == 202) {
        await _checkPaymentStatus(referenceId, accessToken);
      } else {
        throw Exception('Failed to initiate payment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error requesting payment: $e');
      throw e;
    }
  }

  Future<void> _checkPaymentStatus(String referenceId, String accessToken) async {
    try {
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(seconds: 3));
        final response = await http.get(
          Uri.parse('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay/$referenceId'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'X-Target-Environment': 'sandbox',
            'Ocp-Apim-Subscription-Key': subscriptionKey,
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'SUCCESSFUL') return;
          if (data['status'] == 'FAILED' || data['status'] == 'REJECTED') throw Exception('Payment ${data['status'].toLowerCase()}');
        }
      }
      throw Exception('Payment timeout');
    } catch (e) {
      print('Error checking payment status: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> _loadUserBookingHistory() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final querySnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('bookings')
            .orderBy('timestamp', descending: true)
            .get();
        return querySnapshot.docs.map((doc) => doc.data()).toList();
      }
      final prefs = await SharedPreferences.getInstance();
      final bookingList = prefs.getStringList('booking_history') ?? [];
      return bookingList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error loading booking history: $e');
      return [];
    }
  }
}