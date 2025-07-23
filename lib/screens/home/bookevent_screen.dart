import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Booking State Manager
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
      final bookingData = _eventBookings.map((key, value) =>
          MapEntry(key, value.toJson()));
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

// 2. Booking Status Model
class BookingStatus {
  final String ticketId;
  final String status; // 'pending', 'completed', 'failed'
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

// 3. Payment Network Enum
enum PaymentNetwork { mtn, airtel }

// 4. Enhanced Checkout Screen
class CheckoutScreen extends StatefulWidget {
  final double total;
  final String? eventId;
  final String? eventTitle;
  final VoidCallback? onPaymentSuccess;

  const CheckoutScreen({
    super.key,
    required this.total,
    this.eventId,
    this.eventTitle,
    this.onPaymentSuccess,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  bool subscribeOrganizer = true;
  bool subscribeUpdates = true;
  PaymentNetwork? _selectedNetwork;
  String? _validatedPhone;
  String? _ticketId;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey _qrKey = GlobalKey();
  int numberOfTickets = 1;
  double get totalAmount => widget.total * numberOfTickets;


  // Booking state manager
  final BookingStateManager _bookingManager = BookingStateManager();
  StreamSubscription<Map<String, BookingStatus>>? _bookingSubscription;

  // API credentials
  final String subscriptionKey = "aab1d593853c454c9fcec8e4e02dde3c";
  final String apiUser = "815d497c-9cb6-477c-8e30-23c3c2b3bea6";
  final String apiKey = "5594113210ab4f3da3a7329b0ae65f40";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeBookingState();
  }

  Future<void> _initializeBookingState() async {
    await _bookingManager.loadFromPersistentStorage();

    // Listen to booking state changes
    _bookingSubscription = _bookingManager.bookingStream.listen((bookings) {
      if (mounted && widget.eventId != null) {
        final booking = bookings[widget.eventId!];
        if (booking != null && booking.status == 'completed') {
          // Update UI to show booking completed
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }

  // Load user data from Firebase Auth or SharedPreferences
  Future<void> _loadUserData() async {
    // Try to get user from Firebase Auth first
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        email = currentUser.email ?? '';
        firstName = currentUser.displayName?.split(' ').first ?? '';
        lastName = currentUser.displayName?.split(' ').skip(1).join(' ') ?? '';
      });
    } else {
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        firstName = prefs.getString('user_first_name') ?? '';
        lastName = prefs.getString('user_last_name') ?? '';
        email = prefs.getString('user_email') ?? '';
      });
    }
  }

  // Check if event is already booked
  bool get isEventBooked {
    if (widget.eventId == null) return false;
    final booking = _bookingManager.getBookingStatus(widget.eventId!);
    return booking?.status == 'completed';
  }

  // Save booking to Firebase Firestore
  Future<void> _saveBookingToFirestore(Map<String, dynamic> bookingData) async {
    try {
      final User? currentUser = _auth.currentUser;

      // Add user ID if available
      if (currentUser != null) {
        bookingData['userId'] = currentUser.uid;
      }

      // Save to 'bookings' collection
      await _firestore.collection('bookings').doc(_ticketId).set(bookingData);

      // Also save to user's personal bookings subcollection if user is logged in
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('bookings')
            .doc(_ticketId)
            .set(bookingData);
      }

      // Save to local storage as backup
      await _saveBookingLocally(bookingData);

      print('Booking saved to Firestore successfully: $_ticketId');
    } catch (e) {
      print('Error saving booking to Firestore: $e');
      // Still save locally if Firestore fails
      await _saveBookingLocally(bookingData);
      throw e;
    }
  }

  // Save booking locally as backup
  Future<void> _saveBookingLocally(Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current booking
      await prefs.setString('current_booking', jsonEncode(bookingData));

      // Save to booking history
      List<String> bookings = prefs.getStringList('booking_history') ?? [];
      bookings.add(jsonEncode(bookingData));
      await prefs.setStringList('booking_history', bookings);

      // Save user data for future use
      await prefs.setString('user_first_name', firstName);
      await prefs.setString('user_last_name', lastName);
      await prefs.setString('user_email', email);

      print('Booking saved locally successfully');
    } catch (e) {
      print('Error saving booking locally: $e');
    }
  }

  // Load booking from Firestore
  Future<Map<String, dynamic>?> _loadBookingFromFirestore(String ticketId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(ticketId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error loading booking from Firestore: $e');
      return null;
    }
  }

  // Load user's booking history
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

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final bookingList = prefs.getStringList('booking_history') ?? [];
      return bookingList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error loading booking history: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle zero-price event
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
            title: const Text("Free Event",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                const Text(
                  "This is a free event!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (widget.eventTitle != null)
                  Text(
                    widget.eventTitle!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _bookFreeEvent(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text("Reserve Your Spot",
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back to Event"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show different UI if already booked
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
            title: const Text("Already Booked ✅",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                const Text(
                  "You have already booked this event!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (widget.eventTitle != null)
                  Text(
                    widget.eventTitle!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _showBookingHistory(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text("View My Tickets",
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back to Event"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Original checkout UI
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
          title: const Text("Checkout Your Ticket",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.purple.shade900,
          actions: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () => _showBookingHistory(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Event Info Card
            if (widget.eventTitle != null) ...[
              Card(
                elevation: 3,
                color: Colors.purple.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("🎫 Event Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Event: ${widget.eventTitle}", style: const TextStyle(fontSize: 16)),
                      Text("Total: €${widget.total.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Billing Information Card
            Card(
              elevation: 3,
              color: const Color.fromARGB(255, 212, 228, 245),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  const Text("💳 Billing Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: firstName,
                            decoration: const InputDecoration(labelText: "First Name *", filled: false),
                            onChanged: (val) => firstName = val,
                            validator: (val) => val!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: lastName,
                            decoration: const InputDecoration(labelText: "Surname *"),
                            onChanged: (val) => lastName = val,
                            validator: (val) => val!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: email,
                        decoration: const InputDecoration(labelText: "Email Address *"),
                        onChanged: (val) => email = val,
                        validator: (val) => val!.isEmpty ? "Required" : null,
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
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Network Selection
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
            const Spacer(),

            // Checkout Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.purple.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (_selectedNetwork == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select a payment network")),
                    );
                    return;
                  }
                  _openMobileMoneyDialog(_selectedNetwork!);
                }
              },
              child: const Text("Get Your Ticket", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ]),
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
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
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
            title: Text("Pay with $provider Mobile Money" ,),
            titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            icon: const Icon(Icons.mobile_friendly, color: Colors.orange, size: 30, ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone Number",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                          color: Colors.yellow,
                          width: 1.5,
                        ),
                      ),
                    ),
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                  
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_validatedPhone != null) {
                    final token = await getAccessToken();
                    if (token != null) {
                      try {
                        await requestToPay(phoneNumber: _validatedPhone!, accessToken: token, amount: widget.total);
                        Navigator.pop(context); // Close the dialog
                        await _showSuccessDialog();
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookFreeEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _ticketId = const Uuid().v4();

    // Update booking state immediately
    if (widget.eventId != null) {
      _bookingManager.updateBookingStatus(
        widget.eventId!,
        BookingStatus(
          ticketId: _ticketId!,
          status: 'completed',
          timestamp: DateTime.now(),
          amount: widget.total,
        ),
      );
    }

    // Create booking data
    final bookingData = {
      'ticketId': _ticketId,
      'eventId': widget.eventId,
      'eventTitle': widget.eventTitle,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': _validatedPhone,
      'amount': widget.total,
      'currency': 'EUR',
      'paymentMethod': 'Free Event',
      'paymentStatus': 'completed',
      'subscribeOrganizer': subscribeOrganizer,
      'subscribeUpdates': subscribeUpdates,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await _saveBookingToFirestore(bookingData);
      await _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(e);
    }
  }

  Future<void> _showSuccessDialog() async {
    _ticketId = const Uuid().v4();

    // Update booking state immediately
    if (widget.eventId != null) {
      _bookingManager.updateBookingStatus(
        widget.eventId!,
        BookingStatus(
          ticketId: _ticketId!,
          status: 'completed',
          timestamp: DateTime.now(),
          amount: widget.total,
        ),
      );
    }

    // Create booking data
    final bookingData = {
      'ticketId': _ticketId,
      'eventId': widget.eventId,
      'eventTitle': widget.eventTitle,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': _validatedPhone,
      'amount': widget.total,
      'currency': 'EUR',
      'paymentMethod': widget.total == 0 ? 'Free Event' : (_selectedNetwork == PaymentNetwork.mtn ? 'MTN Mobile Money' : 'Airtel Money'),
      'paymentStatus': 'completed',
      'subscribeOrganizer': subscribeOrganizer,
      'subscribeUpdates': subscribeUpdates,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await _saveBookingToFirestore(bookingData);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Reservation Successful ✅",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.total == 0
                  ? "Your spot for ${widget.eventTitle} has been reserved!"
                  : "Your Event ticket for €${widget.total.toStringAsFixed(2)}."),
              const SizedBox(height: 16),
              const Text("🎟 Your Ticket QR Code",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (_ticketId != null)
                SizedBox(
                  width: 180,
                  height: 180,
                  child: PrettyQrView.data(
                    data: _ticketId!,
                    errorCorrectLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              const SizedBox(height: 8),
              if (_ticketId != null)
                Text('QR Code for: $_ticketId'),
              const SizedBox(height: 10),
              const Text("Save or screenshot this QR for entry. Your ticket is also saved in your booking history.",
                  style: TextStyle(fontSize: 12, color: Colors.black)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _showBookingHistory(),
              child: const Text("View History"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                if (widget.onPaymentSuccess != null) {
                  widget.onPaymentSuccess!();
                }
                Navigator.pop(context); // Go back to previous screen
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Handle error but keep booking state
      _showErrorDialog(e);
    }
  }

  void _showErrorDialog(dynamic error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Reservation Successful ✅",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
           children: [
            Text("Your Event-entry QR Code for UGX${totalAmount.toStringAsFixed(2)}."),
            Text("Tickets Purchased: $numberOfTickets"),
          children: [
            Text(widget.total == 0
                ? "Your spot for ${widget.eventTitle} has been reserved!"
                : "Your Event ticket for €${widget.total.toStringAsFixed(2)}."),
            const SizedBox(height: 16),
            const Text("🎟 Your Ticket QR Code", style: TextStyle(fontWeight: FontWeight.bold,)),
             if (_ticketId != null)
              RepaintBoundary(
                key: _qrKey,
               child: SizedBox(
                 width: 180,
                 height: 180,
                 child: PrettyQrView.data(
                   data: _ticketId!,
                   errorCorrectLevel: QrErrorCorrectLevel.M,
                   
                 ),
                 ),
               ),
               const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _downloadQRCode,
                    icon: Icon(Icons.download),
                    label: Text("Download QR Code"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

            const SizedBox(height: 8),
            if (_ticketId != null)
              Text('QR Code for: $_ticketId'),
            const SizedBox(height: 10),
            const Text("⚠️ Please screenshot this QR code immediately as backup storage failed.",
                style: TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (widget.onPaymentSuccess != null) {
                widget.onPaymentSuccess!();
              }
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Show booking history
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
              const Text(
                "🎫 Booking History",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUserBookingHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final bookings = snapshot.data ?? [];

                    if (bookings.isEmpty) {
                      return const Center(
                        child: Text(
                          'No bookings found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

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
                              children: [
                                Text('€${booking['amount']} - ${booking['firstName']} ${booking['lastName']}'),
                                Text('${booking['createdAt'] ?? 'Unknown date'}'),
                              ],
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show QR code for a specific booking
  void _showQRCode(String ticketId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ticket QR Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: PrettyQrView.data(
                data: ticketId,
                errorCorrectLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 8),
            Text('Ticket ID: $ticketId'),
            const SizedBox(height: 10),
            const Text(
              "Present this QR code at the event",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Get access token for API requests
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

  // Validate mobile money account
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
      print("✅ Account is active: $phone");
    } else {
      print("❌ Account not active: ${response.body}");
      throw Exception("Account not active: ${response.body}");
    }
  }
  Future<void> _downloadQRCode() async {
  try {
    if (!(await Permission.storage.request().isGranted)) {
      Fluttertoast.showToast(msg: "Storage permission denied.");
      return;
    }

    RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    final directory = await getExternalStorageDirectory();
    final downloadPath = "${directory!.path}/EventTicket_${_ticketId!}.png";

    final file = await File(downloadPath).create();
    await file.writeAsBytes(pngBytes);

    Fluttertoast.showToast(
      msg: "🎉 QR Code saved to Downloads!",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  } catch (e) {
    print("Error saving QR: $e");
    Fluttertoast.showToast(
      msg: "❌ Failed to save QR code.",
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }
}

  // Request payment
  Future<void> requestToPay({
    required String phoneNumber,
    required String accessToken,
    required double amount,
  }) async {
    try {
      final referenceId = const Uuid().v4();
      final body = jsonEncode({
        'amount': amount.toString(),
        'currency': 'EUR',
        'externalId': referenceId,
        'payer': {
          'partyIdType': 'MSISDN',
          'partyId': phoneNumber,
        },
        'payerMessage': 'Event ticket payment for ${widget.eventTitle}',
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
        // Check payment status
        await _checkPaymentStatus(referenceId, accessToken);
      } else {
        throw Exception('Failed to initiate payment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error requesting payment: $e');
      throw e;
    }
  }

  // Check payment status
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
          if (data['status'] == 'SUCCESSFUL') {
            return;
          } else if (data['status'] == 'FAILED' || data['status'] == 'REJECTED') {
            throw Exception('Payment ${data['status'].toLowerCase()}');
          }
        }
      }
      throw Exception('Payment timeout');
    } catch (e) {
      print('Error checking payment status: $e');
      throw e;
    }
  }
}