import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'checkout_screen.dart';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';
import 'verification_screen.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey =
    GlobalKey<_BookingsTabState>();

// Utility class for date filtering
class DateFilterUtils {
  static DateTime _parseDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) {
        print('Invalid date format: $input');
        return DateTime(1900);
      }
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    } catch (e) {
      print("Date parse error for '$input': $e");
      return DateTime(1900);
    }
  }

  static bool isEventInDateRange(Event event, String dateRange) {
    final eventDate = _parseDate(event.date);
    final now = DateTime.now();
    switch (dateRange) {
      case 'Today':
        return eventDate.day == now.day &&
            eventDate.month == now.month &&
            eventDate.year == now.year;
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return eventDate.isAfter(
              startOfWeek.subtract(const Duration(days: 1)),
            ) &&
            eventDate.isBefore(endOfWeek.add(const Duration(days: 1)));
      case 'This Month':
        return eventDate.month == now.month && eventDate.year == now.year;
      case 'All Dates':
        return true;
      default:
        return true;
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

  bool _isAdmin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.user?.email == 'kennedymutebi7@gmail.com' ?? false;
  }

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _loadBookedEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      print('Fetching events from Firestore...');
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('title', isNotEqualTo: '')
          .get();
      print('Retrieved ${snapshot.docs.length} documents');
      final fetchedEvents =
          snapshot.docs.map((doc) {
            print('Raw Firestore data for ${doc.id}: ${doc.data()}');
            return Event.fromFirestore(doc);
          }).toList()..sort((a, b) {
            final aDate = DateFilterUtils._parseDate(a.date);
            final bDate = DateFilterUtils._parseDate(b.date);
            final aPast = aDate.isBefore(DateTime.now());
            final bPast = bDate.isBefore(DateTime.now());
            return aPast && !bPast
                ? 1
                : !aPast && bPast
                ? -1
                : aDate.compareTo(bDate);
          });
      setState(() {
        events = fetchedEvents;
        _isLoading = false;
      });
      print('Fetched ${events.length} events');
      if (events.isEmpty) {
        print('No events found. Check Firestore data or permissions.');
      }
    } catch (e) {
      print('Error fetching events: $e');
      setState(() => _isLoading = false);
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
    if (userId == null) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book events')),
      );
      return;
    }

    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc('$userId-$eventId');
    try {
      final bookingDoc = await bookingRef.get();
      if (bookingDoc.exists) {
        print('Deleting booking for user: $userId, event: $eventId');
        await bookingRef.delete();
        setState(() {
          bookedEventIds.remove(eventId);
          _eventStatus.remove(eventId);
        });
        bookingsTabKey.currentState?._fetchBookings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Cancelled')),
        );
      } else {
        print('Creating booking for user: $userId, event: $eventId');
        await bookingRef.set({
          'userId': userId,
          'eventId': eventId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          bookedEventIds.add(eventId);
          _eventStatus[eventId] = 'Reserved';
        });
        bookingsTabKey.currentState?._fetchBookings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Successful')),
        );
      }
    } catch (e) {
      print('Error booking event: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error booking event: $e')));
    }
  }

  Future<void> _loadBookedEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for loading booked events');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      final bookedIds = snapshot.docs
          .map((doc) => doc['eventId'] as String)
          .toSet();
      print('Loaded ${bookedIds.length} booked events: $bookedIds');
      setState(() {
        bookedEventIds = bookedIds;
        for (var eventId in bookedIds) {
          _eventStatus[eventId] = 'Reserved';
        }
      });
      bookingsTabKey.currentState?._fetchBookings();
    } catch (e) {
      print('Error loading booked events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading booked events: $e')),
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
      print(
        'Event added: ${event.id}, organizerId: ${event.organizerId}, isVerified: ${event.isVerified}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event added successfully')));
    } catch (e) {
      print('Error adding event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEventDetailsModal(Event event) {
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
                  onPressed: () async {
                    await _bookEvent(event.id);
                    bookingsTabKey.currentState?.addBooking({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'event': event.title,
                      'total': double.tryParse(event.price.toString()) ?? 0.0,
                      'paid': false,
                      'eventId': event.id,
                      'ticketId': const Uuid().v4(),
                      'isVerified': event.isVerified,
                      'verificationStatus': event.verificationStatus,
                    });
                    setState(() {
                      _eventStatus[event.id] = 'Reserved';
                    });
                    Navigator.pop(context);
                    Fluttertoast.showToast(
                      msg: "Event Reservation Successful!",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.CENTER,
                      backgroundColor: Colors.orange,
                      textColor: Colors.white,
                      fontSize: 19.0,
                    );
                  },
                  child: const Text('Book/Reserve an Event'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () async {
                    await _bookEvent(event.id);
                    bookingsTabKey.currentState?.removeBookingByTitle(
                      event.title,
                    );
                    setState(() {
                      _eventStatus[event.id] = 'Cancelled Reservation!';
                    });
                    Navigator.pop(context);
                    Fluttertoast.showToast(
                      msg: "Event Reservation Cancelled!",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.CENTER,
                      backgroundColor: Colors.pink,
                      textColor: Colors.white,
                      fontSize: 19.0,
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                  child: const Text('Cancel Reservation'),
                ),
              ],
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerificationScreen(
                        event: event,
                        isVerified: event.isVerified,
                        verificationDocumentUrl: event.verificationDocumentUrl,
                        verificationStatus: event.verificationStatus,
                        rejectionReason: event.rejectionReason,
                        onBookingAdded: (booking) =>
                            bookingsTabKey.currentState?.addBooking(booking),
                        onStatusUpdate: (status) =>
                            setState(() => _eventStatus[event.id] = status),
                      ),
                    ),
                  );
                },
                child: const Text('Pay For Event'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
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

  void _showEventSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Event to Verify'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                title: Text(event.title),
                subtitle: Text(
                  event.isVerified ? 'Verified' : 'Unverified',
                  style: TextStyle(
                    color: event.isVerified ? Colors.green : Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerificationScreen(
                        event: event,
                        isVerified: event.isVerified,
                        verificationDocumentUrl: event.verificationDocumentUrl,
                        verificationStatus: event.verificationStatus,
                        rejectionReason: event.rejectionReason,
                        onBookingAdded: (booking) =>
                            bookingsTabKey.currentState?.addBooking(booking),
                        onStatusUpdate: (status) {
                          print(
                            'Status updated for event ${event.id}: $status',
                          );
                          setState(() {
                            _eventStatus[event.id] = status;
                            _fetchEvents();
                          });
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Widget> _getScreens() => [
    HomeTab(
      events: events,
      onAddEvent: _addEvent,
      onEventTap: _showEventDetailsModal,
      eventStatus: _eventStatus,
      bookedEventIds: bookedEventIds,
      bookEvent: _bookEvent,
    ),
    SearchTab(
      events: events,
      onEventTap: _showEventDetailsModal,
      eventStatus: _eventStatus,
      bookedEventIds: bookedEventIds,
      bookEvent: _bookEvent,
    ),
    BookingsTab(key: bookingsTabKey),
    const ProfileScreen(),
    const MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 25, 25, 95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: ConvexAppBar(
          style: TabStyle.react,
          backgroundColor: const Color.fromARGB(255, 25, 25, 95),
          activeColor: Colors.orange,
          color: Colors.white,
          height: 60,
          curveSize: 100,
          curve: Curves.easeInOut,
          items: const [
            TabItem(icon: Icons.home, title: 'Home'),
            TabItem(icon: Icons.search, title: 'Search'),
            TabItem(icon: Icons.bookmark, title: 'Bookings'),
            TabItem(icon: Icons.person, title: 'Profile'),
            TabItem(icon: Icons.map, title: 'Map'),
          ],
          initialActiveIndex: _selectedIndex,
          onTap: (int index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(Event) onEventTap;
  final Map<String, String> eventStatus;
  final Set<String> bookedEventIds;
  final Future<void> Function(String) bookEvent;

  const HomeTab({
    Key? key,
    required this.events,
    required this.onAddEvent,
    required this.onEventTap,
    required this.eventStatus,
    required this.bookedEventIds,
    required this.bookEvent,
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _selectedCategory = 'All';
  String _selectedDateRange = 'All Dates';
  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Month',
  ];
  List<Event> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _filterEvents();
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents =
          widget.events.where((event) {
            final matchesCategory =
                _selectedCategory == 'All' ||
                event.category == _selectedCategory;
            final matchesDateRange = DateFilterUtils.isEventInDateRange(
              event,
              _selectedDateRange,
            );
            return matchesCategory && matchesDateRange;
          }).toList()..sort((a, b) {
            final aDate = DateFilterUtils._parseDate(a.date);
            final bDate = DateFilterUtils._parseDate(b.date);
            final aPast = aDate.isBefore(DateTime.now());
            final bPast = bDate.isBefore(DateTime.now());
            return aPast && !bPast
                ? 1
                : !aPast && bPast
                ? -1
                : aDate.compareTo(bDate);
          });
      print('Filtered ${_filteredEvents.length} events in HomeTab');
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 25, 25, 95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset('assets/images/logoo.jpeg', height: 50),
                          Row(
                            children: [
                              if (Provider.of<AuthProvider>(
                                    context,
                                    listen: false,
                                  ).user !=
                                  null) ...[
                                GestureDetector(
                                  onTap: () => _showAddEventDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Color.fromARGB(255, 25, 25, 95),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                ),
                                child: const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    color: Color.fromARGB(255, 25, 25, 95),
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
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Discover ',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 20,
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                            TextSpan(
                              text: 'Amazing Events Near You....',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search events.....',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color.fromARGB(255, 25, 25, 95),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchTab(
                                events: widget.events,
                                onEventTap: widget.onEventTap,
                                eventStatus: widget.eventStatus,
                                bookedEventIds: widget.bookedEventIds,
                                bookEvent: widget.bookEvent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        onTap: () => setState(() {
                          _selectedCategory = 'All';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Concert',
                        isSelected: _selectedCategory == 'Concert',
                        onTap: () => setState(() {
                          _selectedCategory = 'Concert';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Conference',
                        isSelected: _selectedCategory == 'Conference',
                        onTap: () => setState(() {
                          _selectedCategory = 'Conference';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Workshop',
                        isSelected: _selectedCategory == 'Workshop',
                        onTap: () => setState(() {
                          _selectedCategory = 'Workshop';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Sports',
                        isSelected: _selectedCategory == 'Sports',
                        onTap: () => setState(() {
                          _selectedCategory = 'Sports';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Festival',
                        isSelected: _selectedCategory == 'Festival',
                        onTap: () => setState(() {
                          _selectedCategory = 'Festival';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Networking',
                        isSelected: _selectedCategory == 'Networking',
                        onTap: () => setState(() {
                          _selectedCategory = 'Networking';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Exhibition',
                        isSelected: _selectedCategory == 'Exhibition',
                        onTap: () => setState(() {
                          _selectedCategory = 'Exhibition';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Theater',
                        isSelected: _selectedCategory == 'Theater',
                        onTap: () => setState(() {
                          _selectedCategory = 'Theater';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Comedy',
                        isSelected: _selectedCategory == 'Comedy',
                        onTap: () => setState(() {
                          _selectedCategory = 'Comedy';
                          _filterEvents();
                        }),
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Other',
                        isSelected: _selectedCategory == 'Other',
                        onTap: () => setState(() {
                          _selectedCategory = 'Other';
                          _filterEvents();
                        }),
                      ),
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
                  onDateRangeChanged: (value) => setState(() {
                    _selectedDateRange = value;
                    _filterEvents();
                  }),
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
                      Column(
                        children: _filteredEvents
                            .map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: EventCard(
                                  event: event,
                                  onTap: () => widget.onEventTap(event),
                                  status: widget.eventStatus[event.id],
                                  isBooked: widget.bookedEventIds.contains(
                                    event.id,
                                  ),
                                  onBookToggle: () =>
                                      widget.bookEvent(event.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
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

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : const Color.fromARGB(255, 25, 25, 95),
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
          items: dateRangeOptions
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              )
              .toList(),
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

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final String? status;
  final bool isBooked;
  final VoidCallback onBookToggle;

  const EventCard({
    Key? key,
    required this.event,
    this.onTap,
    this.status,
    required this.isBooked,
    required this.onBookToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventDate = DateFilterUtils._parseDate(event.date);
    final isPast = eventDate.isBefore(DateTime.now());
    final isVerified = event.isVerified;
    final price = double.tryParse(event.price.toString()) ?? 0.0;

    print(
      'Rendering EventCard: ${event.title}, isBooked: $isBooked, isVerified: $isVerified, status: $status',
    );

    return GestureDetector(
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
          onTap?.call();
        }
      },
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isVerified ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.warning,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified' : 'Unverified',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'Paid'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status!,
                        style: TextStyle(
                          color: status == 'Paid'
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (event.imageUrl != null)
                ColorFiltered(
                  colorFilter: isPast
                      ? const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.saturation,
                        )
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      event.imageUrl!,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: Icon(
                          _getCategoryIcon(event.category),
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (event.imageUrl == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          25,
                          25,
                          95,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(event.category),
                        color: const Color.fromARGB(255, 25, 25, 95),
                        size: 24,
                      ),
                    ),
                  if (event.imageUrl == null) const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: price == 0
                                ? Colors.green[50]
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            price == 0 ? 'Free Entry' : 'Entry Fee: UGX $price',
                            style: TextStyle(
                              color: price == 0 ? Colors.green : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
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
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isBooked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isBooked ? Colors.orange : Colors.grey,
                                size: 35,
                              ),
                              tooltip: isBooked
                                  ? 'Cancel Booking'
                                  : 'Book Event',
                              onPressed: () {
                                if (isPast) {
                                  Fluttertoast.showToast(
                                    msg: "Cannot book past event",
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.CENTER,
                                    fontSize: 16.0,
                                  );
                                } else {
                                  onBookToggle();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.payment,
                                color: Color.fromARGB(255, 25, 25, 95),
                                size: 35,
                              ),
                              tooltip: 'Pay for Event',
                              onPressed: () {
                                if (isPast) {
                                  Fluttertoast.showToast(
                                    msg: "Cannot pay for past event",
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.CENTER,
                                    fontSize: 16.0,
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        event: event,
                                        total: price,
                                        onPaymentSuccess: () {
                                          Fluttertoast.showToast(
                                            msg: "Payment Successful!",
                                            backgroundColor: Colors.green,
                                            textColor: Colors.white,
                                            toastLength: Toast.LENGTH_LONG,
                                            gravity: ToastGravity.CENTER,
                                            fontSize: 16.0,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  event.category,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 25, 25, 95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class SearchTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onEventTap;
  final Map<String, String> eventStatus;
  final Set<String> bookedEventIds;
  final Future<void> Function(String) bookEvent;

  const SearchTab({
    Key? key,
    required this.events,
    required this.onEventTap,
    required this.eventStatus,
    required this.bookedEventIds,
    required this.bookEvent,
  }) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
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

  @override
  void initState() {
    super.initState();
    _filteredEvents = widget.events;
    print('SearchTab initialized with ${widget.events.length} events');
    _filterEvents();
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents =
          widget.events.where((event) {
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
                _selectedCategory == 'All' ||
                event.category == _selectedCategory;
            return matchesSearch && matchesCategory;
          }).toList()..sort((a, b) {
            final aDate = DateFilterUtils._parseDate(a.date);
            final bDate = DateFilterUtils._parseDate(b.date);
            final aPast = aDate.isBefore(DateTime.now());
            final bPast = bDate.isBefore(DateTime.now());
            return aPast && !bPast
                ? 1
                : !aPast && bPast
                ? -1
                : aDate.compareTo(bDate);
          });
      print('Filtered ${_filteredEvents.length} events in SearchTab');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
        toolbarHeight: 90,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Search',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' Events',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find Events that Match your Interests',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color.fromARGB(255, 25, 25, 95),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search events...',
                    fillColor: Colors.white,
                    filled: true,
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                  ),
                  onChanged: (value) => _filterEvents(),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _CategoryChip(
                              label: category,
                              isSelected: _selectedCategory == category,
                              onTap: () => setState(() {
                                _selectedCategory = category;
                                _filterEvents();
                              }),
                            ),
                          ),
                        )
                        .toList(),
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
                        child: EventCard(
                          event: event,
                          onTap: () => widget.onEventTap(event),
                          status: widget.eventStatus[event.id],
                          isBooked: widget.bookedEventIds.contains(event.id),
                          onBookToggle: () => widget.bookEvent(event.id),
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

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<Map<String, dynamic>> bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) {
      print('No user logged in for fetching bookings');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      final fetchedBookings = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final eventId = data['eventId'] as String?;
        if (eventId != null) {
          try {
            final eventDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();
            if (eventDoc.exists) {
              data['eventObj'] = Event.fromFirestore(eventDoc);
            }
          } catch (e) {
            print('Error fetching event for booking $eventId: $e');
          }
        }
        fetchedBookings.add(data);
      }
      setState(() {
        bookings = fetchedBookings;
      });
      print('Fetched ${bookings.length} bookings');
    } catch (e) {
      print('Error fetching bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error fetching bookings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addBooking(Map<String, dynamic> booking) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) {
      print('No user logged in for adding booking');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc('$userId-${booking['eventId']}')
          .set({
            'userId': userId,
            'event': booking['event'],
            'eventId': booking['eventId'],
            'price': booking['total'] ?? 0.0,
            'paid': booking['paid'] ?? false,
            'ticketId': booking['ticketId'] ?? const Uuid().v4(),
            'isVerified': booking['isVerified'] ?? false,
            'verificationStatus': booking['verificationStatus'],
            'timestamp': FieldValue.serverTimestamp(),
          });
      _fetchBookings();
      print('Booking added: ${booking['event']}');
    } catch (e) {
      print('Error saving booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving booking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void removeBookingByTitle(String title) {
    setState(() {
      bookings.removeWhere((booking) => booking['event'] == title);
    });
    print('Removed booking for event: $title');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
        toolbarHeight: 80,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
      body: bookings.isEmpty
          ? const Center(child: Text('No bookings yet.'))
          : ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final event = booking['eventObj'] as Event?;
                return ListTile(
                  title: Text(booking['event'] ?? 'Unknown Event'),
                  subtitle: Text(
                    'Total: UGX ${booking['price']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  trailing: booking['paid'] == true
                      ? const Text(
                          'Paid',
                          style: TextStyle(color: Colors.green),
                        )
                      : ElevatedButton(
                          child: const Text('Checkout'),
                          onPressed: () {
                            if (event == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Event data not available'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  event: event,
                                  total:
                                      double.tryParse(
                                        booking['price'].toString(),
                                      ) ??
                                      0.0,
                                  onPaymentSuccess: () {
                                    setState(() {
                                      bookings[index]['paid'] = true;
                                    });
                                    Fluttertoast.showToast(
                                      msg: "Payment Successful!",
                                      backgroundColor: Colors.green,
                                      textColor: Colors.white,
                                      toastLength: Toast.LENGTH_LONG,
                                      gravity: ToastGravity.CENTER,
                                      fontSize: 16.0,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
    );
  }
}
