import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
//import 'package:image_picker/image_picker.dart';
//import 'package:firebase_storage/firebase_storage.dart';
//import 'dart:io';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'bookevent_screen.dart';
import 'package:flutter/foundation.dart';
//import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey = GlobalKey<_BookingsTabState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Event> events = [];
  Set<String> bookedEventIds = {}; // Track which events the user has booked

  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }
  //Parse date string for date format "1/7/2025"
  DateTime parseEventDate(String input) {
    try {
      // Expecting input format like "1/7/2025" (dd/mm/yyyy)
      final parts = input.split('/');
      if (parts.length != 3) return DateTime(1900); // invalid format fallback

      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;

      return DateTime(year, month, day); // Return DateTime object
    } catch (e) {
      print("Date parse error for '$input': $e");
      return DateTime(1900); // fallback date
    }
  }
//fetch events from firestore
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('events').get();

      List<Event> fetchedEvents = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();


      // ✅ Sort: upcoming events first, past events last
      fetchedEvents.sort((a, b) {

        final aDate   = parseEventDate(a.date);
        final bDate   = parseEventDate(b.date);

        final aPast   = aDate.isBefore(DateTime.now());
        final bPast   = bDate.isBefore(DateTime.now());

        if (aPast && !bPast) return 1;  // put a after b
        if (!aPast && bPast) return -1; // put a before b
        return aDate.compareTo(bDate);  // both past or both future → natural order
      });

      setState(() {
        events = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        _isLoading = false;
      });
      print('Fetched ${events.length} events');
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
  void _toggleBooking(Event event) {
    setState(() {
      if (bookedEventIds.contains(event.id)) {
        bookedEventIds.remove(event.id); // Unbook
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unbooked: ${event.title}')),
        );
      } else {
        bookedEventIds.add(event.id); // Book
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booked: ${event.title}')),
        );
      }
    });
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
      print('Event added to Firestore: ${event.id}, organizerId: ${event.organizerId}');
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
  // (iii) Track booking/payment status per event
  final Map<String, String> _eventStatus = {};

// (i) Show bottom sheet with event details and actions
  void _showEventDetailsModal(Event event) {
    showDialog(
      context: context,
      //shape: const RoundedRectangleBorder(
       // borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      builder: (_) => AlertDialog (
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 20),
            if (_eventStatus[event.id] != 'Reserved') ...[
              ElevatedButton(
                onPressed: () {
                  bookingsTabKey.currentState?.addBooking({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'event': event.title,
                    'total': event.price,
                    'paid': false,
                  });
                  setState(() {
                    _eventStatus[event.id] = 'Reserved';
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event Reserved!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text('Book Event'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  // UNBOOK logic
                  bookingsTabKey.currentState?.removeBookingByTitle(event.title); // You'll create this method next
                  setState(() {
                    _eventStatus[event.id] = 'unbooked';
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reservation canceled.'),
                      backgroundColor: Colors.grey,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Unbook Event'),
              ),
            ],

            ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            total: event.price,
                            onPaymentSuccess: () {
                              bookingsTabKey.currentState?.addBooking({
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'event': event.title,
                                'total': event.price,
                                'paid': true,
                              });
                              setState(() {
                                _eventStatus[event.id] = 'Paid';
                              });
                            },
                          ),
                        ),
                      );
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
        );
  }

  List<Widget> _getScreens() => [
        HomeTab(events: events, onAddEvent: _addEvent, onEventTap: _showEventDetailsModal, eventStatus: _eventStatus,),
        SearchTab(events: events),
        BookingsTab(key: bookingsTabKey),
        const ProfileScreen(),
        const MapScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react, // other styles: fixedCircle, flip, reactCircle
        backgroundColor: Theme.of(context).primaryColor,
        activeColor: Colors.white,
        color: Colors.white,
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

class HomeTab extends StatelessWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(Event) onEventTap; // (i) Used to trigger event details bottom sheet
  final Map<String, String> eventStatus;
  const HomeTab({Key? key,
    required this.events,
    required this.onAddEvent,
    required this.onEventTap,
    required this.eventStatus,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {

    List<Event> sortedEvents = [...events];

// Optional: Sort by upcoming first (assumes `event.date` is ISO string like "2025-07-01")
   // sortedEvents.sort((a, b) => a.date.compareTo(b.date));

    List<Widget> eventWidgets = sortedEvents.map((event) {
      final isBooked = eventStatus[event.id] == 'Booked'; // Getting booking state
      return Padding(
        padding: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
        child: _EventCard(
          event: event,
          onTap: () => onEventTap(event),
            isBooked: eventStatus[event.id] == 'Reserved',
            onBookToggle: () {
              // Call _showEventDetailsModal(event) to handle booking/unbooking
              onEventTap(event);
            }, // will now toggle booking
            status: eventStatus[event.id], // Replace if needed
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                                        builder: (context) =>
                                            const ProfileScreen()),
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
                                      listen: false);
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
                                              'Please log in to manage events')),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchTab(events: events),
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
                      _CategoryChip(label: 'All', isSelected: true, events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Concert', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Conference', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Workshop', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Sports', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Festival', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Networking', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Exhibition', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Theater', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Comedy', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Other', events: events),
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

  const _CategoryChip({
    required this.label,
    this.isSelected = false,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchTab(events: events),
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

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final String? status;
  final VoidCallback onBookToggle;
  final bool isBooked;

  const _EventCard({required this.event,
    required this.onTap,
    this.status,
    required this.onBookToggle,
    required this.isBooked,
  });
   DateTime parseEventDate(String dateString) {
    try {
      // Expecting format: day/month/year e.g. "1/7/2025"
      final parts = dateString.split('/');
      if (parts.length != 3) return DateTime.now(); // fallback

      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;

      return DateTime(year, month, day);
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now(); // fallback
    }
  }


  @override
  Widget build(BuildContext context) {
    final eventDate = parseEventDate(event.date);
    final isPast = eventDate.isBefore(DateTime.now());

    return GestureDetector(
      //onTap: isPast ? null : onTap,
      onTap: () {
        if (isPast) {
          Fluttertoast.showToast(
            msg: "Oops! Event Passed, Sorry!",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.white,
            textColor: Colors.red,
          );
        } else {
          onTap?.call();
        }
      },
      child: Opacity(
        opacity: isPast ? 0.3 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha((0.4 * 255).toInt()),
                spreadRadius: 1,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.imageUrl == null)
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
                        if (event.imageUrl == null)
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
                                        color: Colors.grey[900],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (status != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'Paid'
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status!,
                                    style: TextStyle(
                                      color: status == 'Paid' ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (isPast)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Oops! Sorry Event Passed!',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (event.description.isNotEmpty)
                                Column(
                                  children: [
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
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
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
                      ],
                    ),
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

class SearchTab extends StatefulWidget {
  final List<Event> events;


  const SearchTab({Key? key, required this.events}) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}
 Map<String, String> _eventStatus = {};
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
  }

  void _showEventDetailsModal(Event event) {
    showDialog(
      context: context,

      builder: (_) => AlertDialog (
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 20),
            if (_eventStatus[event.id] != 'Reserved') ...[
              ElevatedButton(
                onPressed: () {
                  bookingsTabKey.currentState?.addBooking({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'event': event.title,
                    'total': event.price,
                    'paid': false,
                  });
                  setState(() {
                    _eventStatus[event.id] = 'Event Reserved';
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event Reserved!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text('Book/Reserve an Event'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  // UNBOOK logic
                  bookingsTabKey.currentState?.removeBookingByTitle(event.title);
                  setState(() {
                    _eventStatus[event.id] = 'Cancelled Reservation!';
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reservation canceled.'),
                      backgroundColor: Colors.grey,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                child: const Text('Cancel Reservation.'),
              ),
            ],

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      total: event.price,
                      onPaymentSuccess: () {
                        bookingsTabKey.currentState?.addBooking({
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'event': event.title,
                          'total': event.price,
                          'paid': true,
                        });
                        setState(() {
                          _eventStatus[event.id] = 'Paid';
                        });
                      },
                    ),
                  ),
                );
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
                        child: _EventCard(event: _filteredEvents[index],
                          onTap: () => _showEventDetailsModal(event),
                           isBooked: _eventStatus[event.id] == 'Reserved',
                           onBookToggle: () => _showEventDetailsModal(event),),
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
  Map<String, String> _eventStatus = {};
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
        bookings = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
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
  void removeBookingByTitle(String title) {
    setState(() {
      bookings.removeWhere((booking) => booking['event'] == title);
    });
  }

  void addBooking(Map<String, dynamic> booking) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    // setState(() {
    //   bookings.add(booking);
    // });
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
      print("Error saving booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving booking'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          return ListTile(
            title: Text(booking['event'] ?? ''),
            subtitle: Text('Total: €${booking['price']}'),
            trailing: booking['paid'] == true
                ? const Text('Paid', style: TextStyle(color: Colors.green))
                : ElevatedButton(
              child: const Text('Checkout'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      total: booking['price'],
                      onPaymentSuccess: () {
                        setState(() {
                          bookings[index]['paid'] = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
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
          );
        },
      ),
    );
  }
}
