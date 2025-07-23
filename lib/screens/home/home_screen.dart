import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'checkout_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'verification_screen.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey = GlobalKey<_BookingsTabState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final Map<String, String> _eventStatus = {};

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Event> events = [];
  bool _isLoading = true;
  Set<String> bookedEventIds = {};

  bool _isAdmin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.user?.email == 'kennedymutebi7@gmail.com' ?? false;
    return isAdmin;
  }

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _loadBookedEvents();
  }

  DateTime parseEventDate(String input) {
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

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      print('Fetching events from Firestore...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('title', isNotEqualTo: '') // Filter out invalid events
          .get();
      print('Retrieved ${snapshot.docs.length} documents');
      List<Event> fetchedEvents = snapshot.docs.map((doc) {
        print('Raw Firestore data for ${doc.id}: ${doc.data()}');
        return Event.fromFirestore(doc);
      }).toList();
      fetchedEvents.sort((a, b) {
        final aDate = parseEventDate(a.date);
        final bDate = parseEventDate(b.date);
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
      print('Fetched ${events.length} events');
      if (events.isEmpty) {
        print('No events found. Check Firestore data or permissions.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching events: $e');
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
          _eventStatus.remove(eventId); // Sync eventStatus
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
          _eventStatus[eventId] = 'Reserved'; // Sync eventStatus
        });
        bookingsTabKey.currentState?._fetchBookings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Successful')),
        );
      }
    } catch (e) {
      print('Error booking event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking event: $e')),
      );
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
      final bookedIds = snapshot.docs.map((doc) => doc['eventId'] as String).toSet();
      print('Loaded ${bookedIds.length} booked events: $bookedIds');
      setState(() {
        bookedEventIds = bookedIds;
        // Sync eventStatus with bookedEventIds
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

  void _toggleBooking(Event event) {
    _bookEvent(event.id);
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
      print('Event added to Firestore: ${event.id}, organizerId: ${event.organizerId}, isVerified: ${event.isVerified}, verificationStatus: ${event.verificationStatus}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added successfully')),
      );
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
        content: Column(
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
                    'total': event.price,
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
                  bookingsTabKey.currentState?.removeBookingByTitle(event.title);
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
                      onBookingAdded: (booking) {
                        bookingsTabKey.currentState?.addBooking(booking);
                      },
                      onStatusUpdate: (status) {
                        setState(() {
                          _eventStatus[event.id] = status;
                        });
                      },
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
                        onBookingAdded: (booking) {
                          bookingsTabKey.currentState?.addBooking(booking);
                        },
                        onStatusUpdate: (status) {
                          print('Status updated for event ${event.id}: $status');
                          setState(() {
                            _eventStatus[event.id] = status;
                          });
                          _fetchEvents(); // Refetch events to update UI
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
          eventStatus: _eventStatus,
          onEventTap: _showEventDetailsModal,
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
      floatingActionButton: _isAdmin()
          ? FloatingActionButton(
              onPressed: _showEventSelectionDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.admin_panel_settings, color: Colors.white),
            )
          : null,
    );
  }
}

class HomeTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    List<Widget> eventWidgets = events.map(
      (event) => Padding(
        padding: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
        child: EventCard(
          event: event,
          onTap: () => onEventTap(event),
          status: eventStatus[event.id],
          isBooked: bookedEventIds.contains(event.id),
          onBookToggle: () => onEventTap(event),
        ),
      ),
    ).toList();

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
                                onTap: () {
                                  _showAddEventDialog(context);
                                },
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
                                      builder: (context) => const ProfileScreen(),
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
                                  final authProvider = Provider.of<AuthProvider>(
                                    context,
                                    listen: false,
                                  );
                                  if (authProvider.user != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const EventManagementScreen(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please log in to manage events'),
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
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchTab(
                            events: events,
                            onEventTap: onEventTap,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                            bookEvent: bookEvent,
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
                        isSelected: true,
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Concert',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Conference',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Workshop',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Sports',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Festival',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Networking',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Exhibition',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Theater',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Comedy',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Other',
                        events: events,
                        onEventTap: onEventTap,
                        bookEvent: bookEvent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (events.isEmpty)
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
                      Text(
                        'Events (${events.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Column(
                        children: eventWidgets,
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

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(onAddEvent: onAddEvent),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final List<Event> events;
  final Function(Event) onEventTap;
  final Future<void> Function(String) bookEvent;

  const _CategoryChip({
    required this.label,
    this.isSelected = false,
    required this.events,
    required this.onEventTap,
    required this.bookEvent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchTab(
              events: events,
              onEventTap: onEventTap,
              eventStatus: _eventStatus,
              bookedEventIds: _eventStatus.keys.toSet(),
              bookEvent: bookEvent,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
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

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final String? status;
  final VoidCallback onBookToggle;
  final bool isBooked;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
    this.status,
    required this.onBookToggle,
    required this.isBooked,
  }) : super(key: key);

  DateTime parseEventDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) {
        print('Invalid date format in EventCard: $input');
        return DateTime(1900);
      }
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    } catch (e) {
      print("Date parse error in EventCard for '$input': $e");
      return DateTime(1900);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Rendering EventCard: ${event.title}, isBooked: $isBooked, isVerified: ${event.isVerified}, verificationStatus: ${event.verificationStatus}, verificationDocumentUrl: ${event.verificationDocumentUrl != null ? "present" : "null"}');
    final eventDate = parseEventDate(event.date);
    final isPast = eventDate.isBefore(DateTime.now());
    final isVerified = event.isVerified; // Fixed: Use only event.isVerified

    // Debug log to confirm verification status rendering
    print('EventCard verification status for ${event.title}: isVerified=$isVerified, verificationStatus=${event.verificationStatus}, displayed as ${isVerified ? "Verified" : "Unverified"}');

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
          onBookToggle();
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Paid'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status!,
                        style: TextStyle(
                          color: status == 'Paid' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (event.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColorFiltered(
                    colorFilter: isPast
                        ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: Image.network(
                      event.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: const Color.fromARGB(255, 111, 110, 110),
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
              const SizedBox(height: 12),
              if (event.imageUrl == null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(event.category),
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
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
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
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
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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
                        ],
                      ),
                    ),
                  ],
                ),
              if (event.imageUrl != null)
                Column(
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
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
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
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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
                  ],
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
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

  DateTime parseEventDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) {
        print('Invalid date format in SearchTab: $input');
        return DateTime(1900);
      }
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    } catch (e) {
      print("Date parse error in SearchTab for '$input': $e");
      return DateTime(1900);
    }
  }

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
  }

  void _showEventDetailsModal(Event event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 20),
            if (widget.eventStatus[event.id] != 'Reserved') ...[
              ElevatedButton(
                onPressed: () async {
                  await widget.bookEvent(event.id);
                  bookingsTabKey.currentState?.addBooking({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'event': event.title,
                    'total': event.price,
                    'paid': false,
                    'eventId': event.id,
                    'ticketId': const Uuid().v4(),
                    'isVerified': event.isVerified,
                    'verificationStatus': event.verificationStatus,
                  });
                  setState(() {
                    widget.eventStatus[event.id] = 'Reserved';
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
                  await widget.bookEvent(event.id);
                  bookingsTabKey.currentState?.removeBookingByTitle(event.title);
                  setState(() {
                    widget.eventStatus[event.id] = 'Cancelled Reservation!';
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
                      onBookingAdded: (booking) {
                        bookingsTabKey.currentState?.addBooking(booking);
                      },
                      onStatusUpdate: (status) {
                        setState(() {
                          widget.eventStatus[event.id] = status;
                        });
                      },
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
    );
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = widget.events.where((event) {
        final matchesSearch = event.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            event.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            event.location
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        final matchesCategory =
            _selectedCategory == 'All' || event.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
      _filteredEvents.sort((a, b) {
        final aDate = parseEventDate(a.date);
        final bDate = parseEventDate(b.date);
        final aPast = aDate.isBefore(DateTime.now());
        final bPast = bDate.isBefore(DateTime.now());
        if (aPast && !bPast) return 1;
        if (!aPast && bPast) return -1;
        return aDate.compareTo(bDate);
      });
      print('Filtered ${_filteredEvents.length} events in SearchTab');
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
                TextField(
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
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryFilterChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _filterEvents();
                          },
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: EventCard(
                          event: event,
                          onTap: () => _showEventDetailsModal(event),
                          status: widget.eventStatus[event.id],
                          isBooked: widget.bookedEventIds.contains(event.id),
                          onBookToggle: () => _showEventDetailsModal(event),
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

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
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
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
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
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> fetchedBookings = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final eventId = data['eventId'] as String?;
        if (eventId != null) {
          try {
            final eventDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();
            if (eventDoc.exists) {
              final event = Event.fromFirestore(eventDoc);
              data['eventObj'] = event;
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
      print("Error fetching bookings: $e");
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
        'price': booking['total'],
        'paid': booking['paid'],
        'ticketId': booking['ticketId'] ?? const Uuid().v4(),
        'isVerified': booking['isVerified'] ?? false,
        'verificationStatus': booking['verificationStatus'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      _fetchBookings();
      print('Booking added: ${booking['event']}');
    } catch (e) {
      print("Error saving booking: $e");
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
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: bookings.isEmpty
          ? const Center(child: Text('No bookings yet.'))
          : ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final event = booking['eventObj'] as Event?;
                return ListTile(
                  title: Text(booking['event'] ?? ''),
                  subtitle: Text('Total: €${booking['price']?.toStringAsFixed(2) ?? '0.00'}'),
                  trailing: booking['paid'] == true
                      ? const Text('Paid', style: TextStyle(color: Colors.green))
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
                                builder: (_) => VerificationScreen(
                                  event: event,
                                  isVerified: event.isVerified,
                                  verificationDocumentUrl: event.verificationDocumentUrl,
                                  verificationStatus: event.verificationStatus,
                                  rejectionReason: event.rejectionReason,
                                  onBookingAdded: (booking) {
                                    bookingsTabKey.currentState?.addBooking(booking);
                                  },
                                  onStatusUpdate: (status) {
                                    setState(() {
                                      bookings[index]['paid'] = status == 'Paid';
                                    });
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