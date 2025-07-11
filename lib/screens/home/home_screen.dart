import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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

//final GlobalKey<BookingsTabState> bookingsTabKey =
//GlobalKey<BookingsTabState>();
final GlobalKey bookingsTabKey = GlobalKey();
//final GlobalKey<BookingsTabState> bookingsTabKey = GlobalKey<BookingsTabState>();
//final GlobalKey bookingsTabKey = GlobalKey();
//final GlobalKey<BookingsTabState> bookingsTabKey = GlobalKey<BookingsTabState>();

class Event {
  final String id;
  final String title;
  final String description;
  final String date;
  final String location;
  final String category;
  final String? imageUrl;
  final String organizerId;
  final double price;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.category,
    this.imageUrl,
    required this.organizerId,
    required this.price,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: data['date'] ?? '',
      location: data['location'] ?? '',
      category: data['category'] ?? 'Other',
      imageUrl: data['imageUrl'],
      organizerId: data['organizerId'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
      'category': category,
      'imageUrl': imageUrl,
      'organizerId': organizerId,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

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

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();
      setState(() {
        events = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
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

  void _addEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());
      setState(() {
        events.add(event);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Widget> _getScreens() => [
    HomeTab(events: events, onAddEvent: _addEvent),
    SearchTab(events: events),
    BookingsTab(key: bookingsTabKey),
    const ProfileScreen(),
  ];
  Widget BookingsTab({required Key key}) {
    // Return your bookings tab widget here
    return Container(
      key: key,
      child: Center(child: Text('Bookings Tab Content')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;

  const HomeTab({Key? key, required this.events, required this.onAddEvent})
    : super(key: key);

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
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Event>> eventsByDate = {};
    for (var event in _filteredEvents) {
      eventsByDate.putIfAbsent(event.date, () => []).add(event);
    }

    var sortedDates = eventsByDate.keys.toList()
      ..sort((a, b) {
        try {
          DateTime dateA = DateFilterUtils._parseDate(a);
          DateTime dateB = DateFilterUtils._parseDate(b);
          return dateA.compareTo(dateB);
        } catch (e) {
          return a.compareTo(b);
        }
      });

    List<Widget> eventWidgets = [];
    for (var date in sortedDates) {
      if (eventsByDate[date]!.isNotEmpty) {
        eventWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        );
        eventWidgets.addAll(
          eventsByDate[date]!.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
              child: _EventCard(event: entry.value, onTap: () {}),
            ),
          ),
        );
      }
    }

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
                          builder: (context) =>
                              SearchTab(events: widget.events),
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
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _DateRangeDropdown(
                        selectedDateRange: _selectedDateRange,
                        dateRangeOptions: _dateRangeOptions,
                        onDateRangeChanged: (value) {
                          setState(() {
                            _selectedDateRange = value;
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Concert',
                        isSelected: _selectedCategory == 'Concert',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Concert';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Conference',
                        isSelected: _selectedCategory == 'Conference',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Conference';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Workshop',
                        isSelected: _selectedCategory == 'Workshop',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Workshop';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Sports',
                        isSelected: _selectedCategory == 'Sports',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Sports';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Festival',
                        isSelected: _selectedCategory == 'Festival',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Festival';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Networking',
                        isSelected: _selectedCategory == 'Networking',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Networking';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Exhibition',
                        isSelected: _selectedCategory == 'Exhibition',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Exhibition';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Theater',
                        isSelected: _selectedCategory == 'Theater',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Theater';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Comedy',
                        isSelected: _selectedCategory == 'Comedy',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Comedy';
                          });
                          _filterEvents();
                        },
                      ),
                      const SizedBox(width: 10),
                      _CategoryChip(
                        label: 'Other',
                        isSelected: _selectedCategory == 'Other',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Other';
                          });
                          _filterEvents();
                        },
                      ),
                    ],
                  ),
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

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(onAddEvent: widget.onAddEvent),
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
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  Future<void> _trackView(BuildContext context) async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String? city = placemarks.isNotEmpty ? placemarks[0].locality : null;
      String? country = placemarks.isNotEmpty ? placemarks[0].country : null;

      // Save view record
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .collection('views')
          .add({
            'eventId': event.id,
            'timestamp': FieldValue.serverTimestamp(),
            'city': city,
            'country': country,
          });
    } catch (e) {
      print('Error tracking view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _trackView(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              total: event.price,
              onPaymentSuccess: () {
                if (bookingsTabKey.currentState != null) {
                  bookingsTabKey.currentState!.addBooking({
                    //(bookingsTabKey.currentState as BookingsTabState).addBooking({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'event': event.title,
                    'total': event.price,
                    'paid': true,
                  });
                }
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
    _searchController.addListener(_filterEvents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _EventCard(event: event, onTap: () {}),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
