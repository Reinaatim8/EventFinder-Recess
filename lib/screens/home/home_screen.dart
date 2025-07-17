import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'bookevent_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'dart:async';

// View Record Model (consistent with event_management_screen.dart)
class ViewRecord {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final String? city;
  final String? country;
  final String userId;
  final String platform;
  final String viewType;

  ViewRecord({
    required this.id,
    required this.eventId,
    required this.timestamp,
    this.city,
    this.country,
    required this.userId,
    required this.platform,
    required this.viewType,
  });

  factory ViewRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ViewRecord(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      city: data['city'],
      country: data['country'],
      userId: data['userId'] ?? 'anonymous',
      platform: data['platform'] ?? 'unknown',
      viewType: data['viewType'] ?? 'detail_view',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'timestamp': Timestamp.fromDate(timestamp),
      'city': city,
      'country': country,
      'userId': userId,
      'platform': platform,
      'viewType': viewType,
    };
  }
}

// Note: Ensure 'geolocator' and 'geocoding' are added to pubspec.yaml:
// dependencies:
//   geolocator: ^10.1.0
//   geocoding: ^2.1.0

final GlobalKey<BookingsTabState> bookingsTabKey =
    GlobalKey<BookingsTabState>();

class DateFilterUtils {
  static bool isEventInDateRange(Event event, String dateRange) {
    if (dateRange == 'All Dates') return true;

    try {
      DateTime eventDate = _parseDate(event.date);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime eventDay = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      );

      switch (dateRange) {
        case 'Today':
          return eventDay.isAtSameMomentAs(today);
        case 'This Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfWeek = today.subtract(Duration(days: daysFromMonday));
          DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
          return !eventDay.isBefore(startOfWeek) &&
              !eventDay.isAfter(endOfWeek);
        case 'This Weekend':
          int daysUntilSaturday = 6 - now.weekday;
          if (daysUntilSaturday < 0) daysUntilSaturday += 7;
          DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));
          DateTime thisSunday = thisSaturday.add(const Duration(days: 1));
          if (now.weekday == 7) {
            thisSunday = today;
            thisSaturday = today.subtract(const Duration(days: 1));
          }
          return eventDay.isAtSameMomentAs(thisSaturday) ||
              eventDay.isAtSameMomentAs(thisSunday);
        case 'Next Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfThisWeek = today.subtract(
            Duration(days: daysFromMonday),
          );
          DateTime startOfNextWeek = startOfThisWeek.add(
            const Duration(days: 7),
          );
          DateTime endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));
          return !eventDay.isBefore(startOfNextWeek) &&
              !eventDay.isAfter(endOfNextWeek);
        case 'This Month':
          DateTime startOfMonth = DateTime(now.year, now.month, 1);
          DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
          return !eventDay.isBefore(startOfMonth) &&
              !eventDay.isAfter(endOfMonth);
        default:
          return true;
      }
    } catch (e) {
      print('Error parsing date: $e');
      return true;
    }
  }

  static DateTime _parseDate(String date) {
    try {
      return DateTime.parse(date);
    } catch (e) {
      try {
        final formatter = DateFormat('dd/MM/yyyy');
        return formatter.parseStrict(date);
      } catch (e) {
        try {
          final formatter = DateFormat('yyyy/MM/dd');
          return formatter.parseStrict(date);
        } catch (e) {
          throw FormatException('Invalid date format: $date');
        }
      }
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Event> events = [];
  bool _isLoading = true;
  Set<String> bookedEventIds = {};
  final Map<String, String> _eventStatus = {};

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _loadBookedEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();
      List<Event> fetchedEvents = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .toList();
      fetchedEvents.sort((a, b) {
        final aDate = DateFilterUtils._parseDate(a.date);
        final bDate = DateFilterUtils._parseDate(b.date);
        final aPast = aDate.isBefore(DateTime.now());
        final bPast = bDate.isBefore(DateTime.now());
        if (aPast && !bPast) return 1;
        if (!aPast && bPast) return -1;
        return aDate.compareTo(bDate);
      });
      setState(() {
        events = fetchedEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _bookEvent(String eventId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc('$userId-$eventId');
    final bookingDoc = await bookingRef.get();

    try {
      if (bookingDoc.exists) {
        await bookingRef.delete();
        setState(() {
          bookedEventIds.remove(eventId);
          _eventStatus.remove(eventId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Cancelled')),
        );
      } else {
        await bookingRef.set({
          'userId': userId,
          'eventId': eventId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          bookedEventIds.add(eventId);
          _eventStatus[eventId] = 'Reserved';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Successful')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadBookedEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        bookedEventIds = snapshot.docs
            .map((doc) => doc['eventId'] as String)
            .toSet();
        for (var doc in snapshot.docs) {
          _eventStatus[doc['eventId']] = 'Reserved';
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());
      setState(() {
        events.add(event);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event added successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recordView(String eventId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    String? city;
    String? country;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      city = placemarks.isNotEmpty ? placemarks[0].locality : null;
      country = placemarks.isNotEmpty ? placemarks[0].country : null;
    } catch (e) {
      print('Error getting location: $e');
    }

    final viewRecord = ViewRecord(
      id: const Uuid().v4(),
      eventId: eventId,
      timestamp: DateTime.now(),
      city: city,
      country: country,
      userId: userId,
      platform: Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
          ? 'iOS'
          : 'Unknown',
      viewType: 'detail_view',
    );

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('views')
          .doc(viewRecord.id)
          .set(viewRecord.toFirestore());
    } catch (e) {
      print('Error recording view: $e');
    }
  }

  void _showEventDetailsModal(Event event) {
    // Record view when event details are opened
    _recordView(event.id);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.description),
              const SizedBox(height: 20),
              if (_eventStatus[event.id] != 'Reserved') ...[
                ElevatedButton(
                  onPressed: () {
                    _bookEvent(event.id);
                    bookingsTabKey.currentState?.addBooking({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'event': event.title,
                      'total': event.price is num
                          ? event.price
                          : double.tryParse(event.price.toString()) ?? 0.0,
                      'paid': false,
                    });
                    setState(() {
                      _eventStatus[event.id] = 'Reserved';
                    });
                    Navigator.pop(context);
                    Fluttertoast.showToast(
                      msg: "Event Reserved!",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.CENTER,
                      backgroundColor: Colors.orange,
                      textColor: Colors.white,
                      fontSize: 19.0,
                    );
                  },
                  child: const Text('Book Event'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () {
                    _bookEvent(event.id);
                    bookingsTabKey.currentState?.removeBookingByTitle(
                      event.title,
                    );
                    setState(() {
                      _eventStatus[event.id] = 'Reservation Cancelled';
                    });
                    Navigator.pop(context);
                    Fluttertoast.showToast(
                      msg: "Reservation Cancelled!",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.CENTER,
                      backgroundColor: Colors.grey,
                      textColor: Colors.pink,
                      fontSize: 18.0,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 246, 105, 50),
                  ),
                  child: const Text('Cancel Reservation'),
                ),
              ],
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final priceString = event.price
                      .toString()
                      .trim()
                      .toLowerCase();
                  final eventPrice = priceString == "free"
                      ? 0.0
                      : double.tryParse(priceString) ?? 0.0;

                  if (eventPrice <= 0) {
                    final ticketId = const Uuid().v4();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("🎟 Free Entry: Event Ticket"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Here's your QR code ticket:"),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: PrettyQrView.data(
                                data: ticketId,
                                errorCorrectLevel: QrErrorCorrectLevel.M,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Ticket ID: $ticketId",
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Please present this QR code at the event.",
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              bookingsTabKey.currentState?.addBooking({
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'event': event.title,
                                'total': 0.0,
                                'paid': true,
                              });
                              setState(() {
                                _eventStatus[event.id] = 'Paid';
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Done"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          total: eventPrice,
                          onPaymentSuccess: () {
                            bookingsTabKey.currentState?.addBooking({
                              'id': DateTime.now().millisecondsSinceEpoch,
                              'event': event.title,
                              'total': eventPrice,
                              'paid': true,
                            });
                            setState(() {
                              _eventStatus[event.id] = 'Paid';
                            });
                          },
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Pay For Event'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _getScreens() => [
    HomeTab(
      events: events,
      onAddEvent: _addEvent,
      onEventTap: _showEventDetailsModal,
      eventStatus: _eventStatus,
    ),
    SearchTab(
      events: events,
      eventStatus: _eventStatus,
      onEventTap: _showEventDetailsModal,
    ),
    BookingsTab(key: bookingsTabKey),
    const ProfileScreen(),
    const MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        backgroundColor: Theme.of(context).primaryColor,
        activeColor: Colors.white,
        color: Colors.white60,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.search, title: 'Search'),
          TabItem(icon: Icons.bookmark, title: 'Bookings'),
          TabItem(icon: Icons.person, title: 'Profile'),
          TabItem(icon: Icons.map, title: 'Map'),
        ],
        initialActiveIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(Event) onEventTap;
  final Map<String, String> eventStatus;

  const HomeTab({
    Key? key,
    required this.events,
    required this.onAddEvent,
    required this.onEventTap,
    required this.eventStatus,
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _selectedCategory = 'All';
  String _selectedDateRange = 'All Dates';
  List<Event> _filteredEvents = [];

  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Weekend',
    'Next Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _filteredEvents = widget.events;
    _filterEvents();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _filterEvents();
    }
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = widget.events.where((event) {
        final matchesCategory =
            _selectedCategory == 'All' || event.category == _selectedCategory;
        final matchesDateRange = DateFilterUtils.isEventInDateRange(
          event,
          _selectedDateRange,
        );
        return matchesCategory && matchesDateRange;
      }).toList();
      _filteredEvents.sort((a, b) {
        final aDate = DateFilterUtils._parseDate(a.date);
        final bDate = DateFilterUtils._parseDate(b.date);
        final aPast = aDate.isBefore(DateTime.now());
        final bPast = bDate.isBefore(DateTime.now());
        if (aPast && !bPast) return 1;
        if (!aPast && bPast) return -1;
        return aDate.compareTo(bDate);
      });
    });
  }

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(onAddEvent: widget.onAddEvent),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> eventWidgets = _filteredEvents.map((event) {
      final isPast = DateFilterUtils._parseDate(
        event.date,
      ).isBefore(DateTime.now());
      return Padding(
        padding: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
        child: _EventCard(
          event: event,
          onTap: () {
            if (isPast) {
              Fluttertoast.showToast(
                msg: "Oops! Event Passed, Sorry!",
                backgroundColor: Colors.red,
                textColor: Colors.white,
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
                fontSize: 18.0,
              );
            } else {
              widget.onEventTap(event);
            }
          },
          status: widget.eventStatus[event.id],
          isBooked: widget.eventStatus[event.id] == 'Reserved',
          onBookToggle: () => widget.onEventTap(event),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Event Finder',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showAddEventDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () {
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (authProvider.user != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EventManagementScreen(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please log in to manage events',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_note,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Discover amazing events near you',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchTab(
                            events: widget.events,
                            onEventTap: widget.onEventTap,
                            eventStatus: widget.eventStatus,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'All',
                        isSelected: _selectedCategory == 'All',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'All';
                            _filterEvents();
                          });
                        },
                        onEventTap: widget.onEventTap,
                        events: widget.events,
                        eventStatus: widget.eventStatus,
                      ),
                      ...[
                            'Concert',
                            'Conference',
                            'Workshop',
                            'Sports',
                            'Festival',
                            'Networking',
                            'Exhibition',
                            'Theater',
                            'Comedy',
                            'Other',
                          ]
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _CategoryChip(
                                label: category,
                                isSelected: _selectedCategory == category,
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                    _filterEvents();
                                  });
                                },
                                onEventTap: widget.onEventTap,
                                events: widget.events,
                                eventStatus: widget.eventStatus,
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _DateRangeDropdown(
                  selectedDateRange: _selectedDateRange,
                  dateRangeOptions: _dateRangeOptions,
                  onDateRangeChanged: (value) {
                    setState(() {
                      _selectedDateRange = value;
                      _filterEvents();
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),
              if (_filteredEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(50.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Try changing your filter or search criteria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Events (${_filteredEvents.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedDateRange != 'All Dates') ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedDateRange,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 15),
                      Column(children: eventWidgets),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Event) onEventTap;
  final List<Event> events;
  final Map<String, String> eventStatus;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.onEventTap,
    required this.events,
    required this.eventStatus,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DateRangeDropdown extends StatelessWidget {
  final String selectedDateRange;
  final List<String> dateRangeOptions;
  final Function(String) onDateRangeChanged;

  const _DateRangeDropdown({
    required this.selectedDateRange,
    required this.dateRangeOptions,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selectedDateRange != 'All Dates'
            ? Theme.of(context).primaryColor
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedDateRange != 'All Dates'
              ? Theme.of(context).primaryColor
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDateRange,
          icon: Icon(
            Icons.calendar_today,
            size: 16,
            color: selectedDateRange != 'All Dates'
                ? Colors.white
                : Colors.grey[600],
          ),
          style: TextStyle(
            color: selectedDateRange != 'All Dates'
                ? Colors.white
                : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          items: dateRangeOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onDateRangeChanged(newValue);
            }
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final String? status;
  final bool isBooked;
  final VoidCallback onBookToggle;

  const _EventCard({
    required this.event,
    this.onTap,
    this.status,
    required this.isBooked,
    required this.onBookToggle,
  });

  DateTime parseEventDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) return DateTime(1900);
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime(1900);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventDate = parseEventDate(event.date);
    final isPast = eventDate.isBefore(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isPast ? 0.3 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: ColorFiltered(
                    colorFilter: isPast
                        ? const ColorFilter.mode(
                            Colors.grey,
                            BlendMode.saturation,
                          )
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                    child: Image.network(
                      event.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(
                            _getCategoryIcon(event.category),
                            size: 60,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (event.imageUrl == null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getCategoryIcon(event.category),
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                        if (event.imageUrl == null) const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    event.date,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      event.location,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (status != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status == 'Paid'
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status!,
                                    style: TextStyle(
                                      color: status == 'Paid'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            event.category,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        event.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'concert':
      case 'festival':
        return Icons.music_note;
      case 'conference':
        return Icons.computer;
      case 'workshop':
        return Icons.build;
      case 'sports':
        return Icons.sports;
      case 'networking':
        return Icons.group;
      case 'exhibition':
        return Icons.museum;
      case 'theater':
        return Icons.theater_comedy;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.event;
    }
  }
}

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  BookingsTabState createState() => BookingsTabState();
}

class BookingsTabState extends State<BookingsTab> {
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        _bookings = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'event': data['event'] ?? 'Unknown Event',
            'total': data['price'] ?? 0.0,
            'paid': data['paid'] ?? false,
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addBooking(Map<String, dynamic> booking) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': userId,
        'event': booking['event'],
        'price': booking['total'],
        'paid': booking['paid'],
        'timestamp': FieldValue.serverTimestamp(),
      });
      _fetchBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void removeBookingByTitle(String title) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('event', isEqualTo: title)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      _fetchBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your booked events will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking['event'] ?? 'Unknown Event',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: booking['paid'] == true
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                booking['paid'] == true ? 'Paid' : 'Pending',
                                style: TextStyle(
                                  color: booking['paid'] == true
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Booking ID: ${booking['id']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: €${booking['total']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (booking['paid'] != true)
                          ElevatedButton(
                            child: const Text('Checkout'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckoutScreen(
                                    total: booking['total']?.toDouble() ?? 0.0,
                                    onPaymentSuccess: () {
                                      setState(() {
                                        _bookings[index]['paid'] = true;
                                      });
                                      FirebaseFirestore.instance
                                          .collection('bookings')
                                          .doc(booking['id'])
                                          .update({'paid': true});
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Payment Successful!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SearchTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onEventTap;
  final Map<String, String> eventStatus;

  const SearchTab({
    Key? key,
    required this.events,
    required this.onEventTap,
    required this.eventStatus,
  }) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedDateRange = 'All Dates';
  List<Event> _filteredEvents = [];

  final List<String> _categories = [
    'All',
    'Concert',
    'Conference',
    'Workshop',
    'Sports',
    'Festival',
    'Networking',
    'Exhibition',
    'Theater',
    'Comedy',
    'Other',
  ];

  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Weekend',
    'Next Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    _filteredEvents = widget.events;
    _filterEvents();
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _filterEvents();
    }
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = widget.events.where((event) {
        final matchesSearch =
            event.title.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            event.description.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            event.location.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );
        final matchesCategory =
            _selectedCategory == 'All' || event.category == _selectedCategory;
        final matchesDateRange = DateFilterUtils.isEventInDateRange(
          event,
          _selectedDateRange,
        );
        return matchesSearch && matchesCategory && matchesDateRange;
      }).toList();
      _filteredEvents.sort((a, b) {
        final aDate = DateFilterUtils._parseDate(a.date);
        final bDate = DateFilterUtils._parseDate(b.date);
        final aPast = aDate.isBefore(DateTime.now());
        final bPast = bDate.isBefore(DateTime.now());
        if (aPast && !bPast) return 1;
        if (!aPast && bPast) return -1;
        return aDate.compareTo(bDate);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Search Events'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search events...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) => _filterEvents(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DateRangeDropdown(
                      selectedDateRange: _selectedDateRange,
                      dateRangeOptions: _dateRangeOptions,
                      onDateRangeChanged: (value) {
                        setState(() {
                          _selectedDateRange = value;
                          _filterEvents();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _CategoryChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                              _filterEvents();
                            });
                          },
                          onEventTap: widget.onEventTap,
                          events: widget.events,
                          eventStatus: widget.eventStatus,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      final isPast = DateFilterUtils._parseDate(
                        event.date,
                      ).isBefore(DateTime.now());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _EventCard(
                          event: event,
                          onTap: () {
                            if (isPast) {
                              Fluttertoast.showToast(
                                msg: "Oops! Event Passed, Sorry!",
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                toastLength: Toast.LENGTH_LONG,
                                gravity: ToastGravity.CENTER,
                                fontSize: 18.0,
                              );
                            } else {
                              widget.onEventTap(event);
                            }
                          },
                          status: widget.eventStatus[event.id],
                          isBooked: widget.eventStatus[event.id] == 'Reserved',
                          onBookToggle: () => widget.onEventTap(event),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
