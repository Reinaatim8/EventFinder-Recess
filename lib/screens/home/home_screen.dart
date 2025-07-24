import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'checkout_screen.dart';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';
import 'verification_screen.dart';
import '../../services/booking_service.dart';

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
  int selectedIndex = 0;
  List<Event> events = [];
  bool isLoading = true;
  Set<String> bookedEventIds = {};
  final Map<String, String> eventStatus = {};
  final BookingService _bookingService = BookingService();
  final Map<String, String> _eventStatus = {};

  bool _isAdmin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.user?.email?.toLowerCase().trim();
    final isAdmin = userEmail == 'kennedymutebi7@gmail.com';
    print('Checking admin status: user=$userEmail, isAdmin=$isAdmin');
    return isAdmin;
  }

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _loadBookedEvents();
  }

  Future<void> fetchEvents() async {
    setState(() => isLoading = true);
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
        isLoading = false;
      });
      print('Fetched ${events.length} events');
      if (events.isEmpty) {
        print('No events found. Check Firestore data or permissions.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
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

  Future<void> bookEvent(String eventId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for booking event');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book events')),
      );
      return;
    }

    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc('$userId-$eventId');

    try {
      // Validate event existence
      final event = events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event not found: $eventId'),
      );

      print(
        'Booking attempt: authUid=${FirebaseAuth.instance.currentUser?.uid}, userId=$userId, eventId=$eventId',
      );

      // Log booking data
      final bookingData = {
        'userId': userId,
        'eventId': eventId,
        'event': event.title,
        'price': event.price,
        'paid':
            event.price == '0' || event.price == '0.0' || event.price == '0.00'
            ? true
            : false,
        'ticketId': const Uuid().v4(),
        'isVerified': event.isVerified,
        'verificationStatus': event.verificationStatus,
        'timestamp': FieldValue.serverTimestamp(),
      };
      print('Booking data: $bookingData');

      if (await bookingRef.get().then((doc) => doc.exists)) {
        print('Deleting booking for user: $userId, event: $eventId');
        await bookingRef.delete();
        setState(() {
          bookedEventIds.remove(eventId);
          eventStatus.remove(eventId);
        });
        bookingsTabKey.currentState?._fetchBookings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Reservation Cancelled')),
        );
      } else {
        print('Creating booking for user: $userId, event: $eventId');
        await bookingRef.set(bookingData);
        setState(() {
          bookedEventIds.add(eventId);
          eventStatus[eventId] = 'Reserved';
        });
        bookingsTabKey.currentState?._fetchBookings();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Event Reservation Successful')),
        // );
      }
    } catch (e) {
      print('Error booking event: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error booking event: $e')),
      // );
    }
  }

  Future<void> loadBookedEvents() async {
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
          eventStatus[eventId] = 'Reserved';
        }
      });
      bookingsTabKey.currentState?._fetchBookings();
    } catch (e) {
      print('Error loading booked events: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error loading booked events: $e')),
      // );
    }
  }

  void toggleBooking(Event event) {
    bookEvent(event.id);
  }

  void addEvent(Event event) async {
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

  void handlePaymentSuccess(Event event) {
    setState(() {
      eventStatus[event.id] = 'Paid';
      bookedEventIds.add(event.id);
    });
    bookingsTabKey.currentState?._fetchBookings();
    Fluttertoast.showToast(
      msg: "Payment Successful!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void showEventDetailsModal(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 20),
            if (eventStatus[event.id] != 'Reserved') ...[
              ElevatedButton(
                onPressed: () async {
                  await bookEvent(event.id);
                  bookingsTabKey.currentState?.addBooking({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'event': event.title,
                    'total': event.price,
                    'paid':
                        event.price == '0' ||
                            event.price == '0.0' ||
                            event.price == '0.00'
                        ? true
                        : false,
                    'eventId': event.id,
                    'ticketId': const Uuid().v4(),
                    'isVerified': event.isVerified,
                    'verificationStatus': event.verificationStatus,
                  });
                  setState(() {
                    eventStatus[event.id] = 'Reserved';
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
                  await bookEvent(event.id);
                  bookingsTabKey.currentState?.removeBookingByTitle(
                    event.title,
                  );
                  setState(() {
                    eventStatus[event.id] = 'Cancelled Reservation!';
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
                if (!event.isVerified) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),

                      title: const Text(
                        'Caution: Unverified Event',
                        style: TextStyle(color: Colors.red),
                      ),

                      content: const Text(
                        'This event is not yet verified. Paying for an unverified event may carry risks, as the event details have not been confirmed by an administrator. Do you wish to proceed with payment?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(
                              context,
                            ); // Close the event details modal
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutScreen(
                                  event: event,
                                  total: event.price,
                                  ticketId: const Uuid().v4(),
                                  onPaymentSuccess: () =>
                                      handlePaymentSuccess(event),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Proceed'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(
                        event: event,
                        total: event.price,
                        ticketId: const Uuid().v4(),
                        onPaymentSuccess: () => handlePaymentSuccess(event),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Pay For Event'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void showEventSelectionDialog() {
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
                            eventStatus[event.id] = status;
                            _fetchEvents();
                          });
                          fetchEvents();
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

  List<Widget> getScreens() => [
    HomeTab(
      events: events,
      onAddEvent: addEvent,
      onEventTap: showEventDetailsModal,
      eventStatus: eventStatus,
      bookedEventIds: bookedEventIds,
      bookEvent: bookEvent,
    ),
    SearchTab(
      events: events,
      eventStatus: eventStatus,
      onEventTap: showEventDetailsModal,
      bookedEventIds: bookedEventIds,
      bookEvent: bookEvent,
    ),
    BookingsTab(key: bookingsTabKey),
    const ProfileScreen(),
    const MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : getScreens()[selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.fromARGB(255, 25, 25, 95),
            width: 0.2,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
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
            TabItem(icon: Icons.history, title: 'Pay-History'),
            TabItem(icon: Icons.person, title: 'Profile'),
            TabItem(icon: Icons.map, title: 'Map'),
          ],
          initialActiveIndex: selectedIndex,
          onTap: (int index) {
            setState(() {
              selectedIndex = index;
            });
          },
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

  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.user?.email?.toLowerCase().trim();
    final isAdmin = userEmail == 'kennedymutebi7@gmail.com';
    print('HomeTab - Checking admin status: user=$userEmail, isAdmin=$isAdmin');
    return isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> eventWidgets = events
        .map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 15, left: 0, right: 0),
            child: EventCard(
              event: event,
              onTap: () => onEventTap(event),
              status: eventStatus[event.id],
              isBooked: bookedEventIds.contains(event.id),
              onBookToggle: () => bookEvent(event.id),
              onPaymentSuccess: () {
                final homeScreenState = context
                    .findAncestorStateOfType<_HomeScreenState>();
                homeScreenState?.handlePaymentSuccess(event);
              },
            ),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 25, 25, 95),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(80),
                        bottomRight: Radius.circular(80),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: Offset(0, 2),
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
                              Image.asset(
                                'assets/images/logoo.jpeg',
                                height: 50,
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
                                      child: const Icon(
                                        Icons.add,
                                        color: Color.fromARGB(255, 25, 25, 95),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (_isAdmin(context))
                                    GestureDetector(
                                      onTap: () {
                                        final homeScreenState = context
                                            .findAncestorStateOfType<
                                              _HomeScreenState
                                            >();
                                        homeScreenState
                                            ?.showEventSelectionDialog();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.admin_panel_settings,
                                          color: Colors.blue,
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
                                    child: const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.person,
                                        color: Color.fromARGB(255, 25, 25, 95),
                                      ),
                                    ),
                                  ),
                                  //const SizedBox(width:10, ),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please log in to manage events',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.event,
                                      color: Colors.white,
                                      size: 20,
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
                              decoration: InputDecoration(
                                hintText: 'Search events.....',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color.fromARGB(255, 25, 25, 95),
                                  size: 20,
                                ),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Concert',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Conference',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Workshop',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Sports',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Festival',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Networking',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Exhibition',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Theater',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Comedy',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: 'Other',
                            events: events,
                            onEventTap: onEventTap,
                            bookEvent: bookEvent,
                            eventStatus: eventStatus,
                            bookedEventIds: bookedEventIds,
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
                          Column(children: eventWidgets),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
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
  final VoidCallback onTap;
  final Map<String, String> eventStatus;
  final Set<String> bookedEventIds;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.eventStatus,
    required this.bookedEventIds,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchTab(
              events: label == 'All'
                  ? events
                  : events.where((event) => event.category == label).toList(),
              onEventTap: onEventTap,
              eventStatus: eventStatus,
              bookedEventIds: bookedEventIds,
              bookEvent: bookEvent,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.black.withOpacity(0.05),
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
  final VoidCallback? onPaymentSuccess;
  final VoidCallback onBookToggle;

  const EventCard({
    Key? key,
    required this.event,
    this.onTap,
    this.status,
    required this.isBooked,
    this.onPaymentSuccess,
    required this.onBookToggle,
  }) : super(key: key);

  IconData getCategoryIcon(String category) {
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

  @override
  Widget build(BuildContext context) {
    final eventDate = DateFilterUtils._parseDate(event.date);
    final isPast = eventDate.isBefore(DateTime.now());
    final isVerified = event.isVerified;

    print(
      'EventCard verification status for ${event.title}: isVerified=$isVerified, verificationStatus=${event.verificationStatus}, displayed as ${isVerified ? "Verified" : "Unverified"}',
    );

    return GestureDetector(
      onTap: () {
        if (isPast) {
          Fluttertoast.showToast(
            msg: "Oops! Event Passed, Sorry!",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 18.0,
          );
        } else {
          onTap();
        }
      },
      child: Opacity(
        opacity: isPast ? 0.3 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 5, right: 0, left: 0),
          padding: const EdgeInsets.all(16),

          width: MediaQuery.of(context).size.width - 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
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
                      color: isVerified ? Colors.blue : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.warning,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified' : 'Unverified',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (event.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
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
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: Icon(
                          getCategoryIcon(event.category),
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
                        getCategoryIcon(event.category),
                        color: const Color.fromARGB(255, 25, 25, 95),
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
                      event.title.toUpperCase(),
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
                        Icon(Icons.location_on, size: 32, color: Colors.red),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:
                        (event.price == '0' ||
                            event.price == '0.0' ||
                            event.price == '0.00')
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Free Entry',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 250, 186, 137),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Entry Fee: UGX ${event.price}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      isBooked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBooked ? Colors.orange : Colors.grey,
                      size: 35,
                    ),
                    tooltip: isBooked ? 'Cancel Booking' : 'Book Event',
                    onPressed: () {
                      if (!isPast) {
                        onBookToggle();
                      } else {
                        Fluttertoast.showToast(
                          msg: "Cannot book past event",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.CENTER,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
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
                      if (!isPast) {
                        if (!event.isVerified) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              title: const Text(
                                'Caution: Unverified Event',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),

                              content: const Text(
                                'This event is not yet verified. Paying for an unverified event may carry risks, as the event details have not been confirmed by an administrator. Do you wish to proceed with payment?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      backgroundColor: Colors.white,
                                      fontSize: 19,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CheckoutScreen(
                                          event: event,
                                          total: event.price,
                                          ticketId: const Uuid().v4(),
                                          onPaymentSuccess: onPaymentSuccess,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: const Text('Proceed'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                event: event,
                                total: event.price,
                                ticketId: const Uuid().v4(),
                                onPaymentSuccess: onPaymentSuccess,
                              ),
                            ),
                          );
                        }
                      } else {
                        Fluttertoast.showToast(
                          msg: "Cannot pay for past event",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.CENTER,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
  final TextEditingController searchController = TextEditingController();
  String selectedCategory = 'All';
  List<Event> filteredEvents = [];
  final List<String> categories = [
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
    filteredEvents = widget.events;
    print('SearchTab initialized with ${widget.events.length} events');
    filterEvents();
  }

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

  void filterEvents() {
    setState(() {
      filteredEvents = widget.events.where((event) {
        final matchesSearch =
            event.title.toLowerCase().contains(
              searchController.text.toLowerCase(),
            ) ||
            event.description.toLowerCase().contains(
              searchController.text.toLowerCase(),
            ) ||
            event.location.toLowerCase().contains(
              searchController.text.toLowerCase(),
            );
        final matchesCategory =
            selectedCategory == 'All' || event.category == selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
      filteredEvents.sort((a, b) {
        final aDate = parseEventDate(a.date);
        final bDate = parseEventDate(b.date);
        final aPast = aDate.isBefore(DateTime.now());
        final bPast = bDate.isBefore(DateTime.now());
        if (aPast && !bPast) return 1;
        if (!aPast && bPast) return -1;
        return aDate.compareTo(bDate);
      });
      print('Filtered ${filteredEvents.length} events in SearchTab');
    });
  }

  void handlePaymentSuccess(Event event) {
    setState(() {
      widget.eventStatus[event.id] = 'Paid';
      widget.bookedEventIds.add(event.id);
    });
    bookingsTabKey.currentState?._fetchBookings();
    Fluttertoast.showToast(
      msg: "Payment Successful!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void showEventDetailsModal(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    'paid':
                        event.price == '0' ||
                            event.price == '0.0' ||
                            event.price == '0.00'
                        ? true
                        : false,
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
                  bookingsTabKey.currentState?.removeBookingByTitle(
                    event.title,
                  );
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
                if (!event.isVerified) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Caution: Unverified Event',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                      content: const Text(
                        'This event is not yet verified. Paying for an unverified event may carry risks, as the event details have not been confirmed by an administrator. Do you wish to proceed with payment?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(
                              context,
                            ); // Close the event details modal
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutScreen(
                                  event: event,
                                  total: event.price,
                                  ticketId: const Uuid().v4(),
                                  onPaymentSuccess: () =>
                                      handlePaymentSuccess(event),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Proceed'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(
                        event: event,
                        total: event.price,
                        ticketId: const Uuid().v4(),
                        onPaymentSuccess: () => handlePaymentSuccess(event),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Pay For Event'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
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
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
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
            const SizedBox(height: 10),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/blue2.jpeg', fit: BoxFit.cover),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color.fromARGB(255, 25, 25, 95),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search events...',
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                      ),
                      onChanged: (value) => filterEvents(),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryFilterChip(
                              label: category,
                              isSelected: selectedCategory == category,
                              onTap: () {
                                setState(() {
                                  selectedCategory = category;
                                });
                                filterEvents();
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
                child: filteredEvents.isEmpty
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
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: EventCard(
                              event: event,
                              onTap: () => showEventDetailsModal(event),
                              status: widget.eventStatus[event.id],
                              isBooked: widget.bookedEventIds.contains(
                                event.id,
                              ),
                              onBookToggle: () => widget.bookEvent(event.id),
                              onPaymentSuccess: () =>
                                  handlePaymentSuccess(event),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.transparent,
          ),
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

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) {
      print('No user logged in for fetching bookings');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view bookings')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      final fetchedBookings = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Validate price field
        if (data['price'] != null &&
            double.tryParse(data['price'].toString()) == null) {
          print('Invalid price format for booking ${doc.id}: ${data['price']}');
          continue;
        }
        fetchedBookings.add({
          'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'event': data['event'] ?? 'Unknown Event',
          'total': data['price'] ?? '0',
          'paid': data['paid'] ?? false,
          'ticketId': data['ticketId'] ?? const Uuid().v4(),
          'isVerified': data['isVerified'] ?? false,
          'verificationStatus': data['verificationStatus'],
          'eventId': data['eventId'] ?? '',
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Sort bookings by timestamp (most recent first)
      fetchedBookings.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      setState(() {
        bookings = fetchedBookings;
        isLoading = false;
      });
      print('Fetched ${bookings.length} bookings for user: $userId');
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching bookings: $e')));
    }
  }

  void addBooking(Map<String, dynamic> booking) {
    setState(() {
      bookings.add(booking);
      bookings.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );
    });
    print('Added booking: ${booking['event']}');
  }

  void removeBookingByTitle(String eventTitle) {
    setState(() {
      bookings.removeWhere((booking) => booking['event'] == eventTitle);
    });
    print('Removed booking for event: $eventTitle');
  }

  Future<void> _cancelBooking(String eventId, String eventTitle) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for cancelling booking');
      return;
    }

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc('$userId-$eventId');
      await bookingRef.delete();
      setState(() {
        bookings.removeWhere((booking) => booking['eventId'] == eventId);
      });
      final homeScreenState = context
          .findAncestorStateOfType<_HomeScreenState>();
      homeScreenState?.setState(() {
        homeScreenState.bookedEventIds.remove(eventId);
        homeScreenState.eventStatus.remove(eventId);
      });
      Fluttertoast.showToast(
        msg: "Booking for $eventTitle cancelled",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.pink,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      Fluttertoast.showToast(
        msg: 'Error cancelling booking: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
        title: const Text('Payments History'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'No Payments history found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Book/Pay events from the Home or Search tab',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final isVerified = booking['isVerified'] ?? false;
                final isPaid = booking['paid'] ?? false;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      isVerified ? Icons.verified : Icons.warning,
                      color: isVerified ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      booking['event'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price: ${booking['total'] == '0' || booking['total'] == '0.0' || booking['total'] == '0.00' ? 'Free' : 'UGX ${booking['total']}'}',
                        ),
                        Text(
                          'Status: ${isPaid ? 'Paid' : 'Reserved'}',
                          style: TextStyle(
                            color: isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                        if (!isVerified)
                          const Text(
                            'Unverified Event',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _cancelBooking(booking['eventId'], booking['event']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
