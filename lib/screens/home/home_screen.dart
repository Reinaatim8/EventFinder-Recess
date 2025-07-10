import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'bookevent_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey = GlobalKey<_BookingsTabState>();

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
  final int viewCount; // Added for view tracking

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
    this.viewCount = 0,
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
      viewCount: (data['viewCount'] ?? 0).toInt(),
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
      'viewCount': viewCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
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
  WebSocketChannel? _channel;
  Timer? _viewTimer;
  String? _currentEventId;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://your-websocket-server-url'), // Replace with your WebSocket server URL
      );
      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('events').get();
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

  Future<void> _sendViewEvent(String eventId, String location) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      final viewData = {
        'eventId': eventId,
        'userId': userId,
        'location': location,
        Kirchner
        'timestamp': DateTime.now().toIso8601String(),
      };
      _channel?.sink.add(jsonEncode({'type': 'view_event', 'data': viewData}));
      
      // Update Firestore view count
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
            'viewCount': FieldValue.increment(1),
          });
    } catch (e) {
      print('Error sending view event: $e');
    }
  }

  Future<String> _getUserLocationМетод() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Unknown';
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return 'Lat: ${position.latitude}, Long: ${position.longitude}';
    } catch (e) {
      print('Error getting location: $e');
      return 'Unknown';
    }
  }

  List<Widget> _getScreens() => [
        HomeTab(events: events, onAddEvent: _addEvent, onViewEvent: _sendViewEvent),
        SearchTab(events: events, onViewEvent: _sendViewEvent),
        BookingsTab(key: bookingsTabKey),
        const ProfileScreen(),
      ];

  @override
  void dispose() {
    _channel?.sink.close();
    _viewTimer?.cancel();
    super.dispose();
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label:

System: I notice the provided code for `home_screen.dart` was cut off. I'll complete the implementation and provide both updated files with the real-time analytics functionality using WebSockets. The implementation will include:

1. **home_screen.dart**: 
   - View tracking when users view events
   - Sending view events to the backend via WebSocket
   - Tracking view duration and location

2. **event_management_screen.dart**:
   - Real-time view count updates with animated counters
   - Live activity feed showing recent views
   - Visual indicators for view milestones

Below are the complete updated files:

<xaiArtifact artifact_id="34cb142c-24e3-4205-9c83-1155d18e5723" artifact_version_id="b9f3ef87-79bf-474a-833b-67ece147cf36" title="home_screen.dart" contentType="text/x-dart">
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'bookevent_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey = GlobalKey<_BookingsTabState>();

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
  final int viewCount;

  Event({
    required this.id,
    required this FACILITY: this.imageUrl,
    required this.organizerId,
    required this.price,
    this.viewCount = 0,
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
      viewCount: (data['viewCount'] ?? 0).toInt(),
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
      'viewCount': viewCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
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
  WebSocketChannel? _channel;
  Timer? _viewTimer;
  String? _currentEventId;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://your-websocket-server-url'), // Replace with your WebSocket server URL
      );
      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('events').get();
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

  Future<void> _sendViewEvent(String eventId, String location) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      final viewData = {
        'eventId': eventId,
        'userId': userId,
        'location': location,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _channel?.sink.add(jsonEncode({'type': 'view_event', 'data': viewData}));
      
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
            'viewCount': FieldValue.increment(1),
          });
      
      // Start tracking view duration
      _currentEventId = eventId;
      _viewTimer?.cancel();
      _viewTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (_currentEventId == eventId) {
          _channel?.sink.add(jsonEncode({
            'type': 'view_duration',
            'data': {
              'eventId': eventId,
              'userId': userId,
              'duration': 5,
            },
          }));
        }
      });
    } catch (e) {
      print('Error sending view event: $e');
    }
  }

  Future<String> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Unknown';
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return 'Lat: ${position.latitude}, Long: ${position.longitude}';
    } catch (e) {
      print('Error getting location: $e');
      return 'Unknown';
    }
  }

  List<Widget> _getScreens() => [
        HomeTab(events: events, onAddEvent: _addEvent, onViewEvent: _sendViewEvent),
        SearchTab(events: events, onViewEvent: _sendViewEvent),
        BookingsTab(key: bookingsTabKey),
        const ProfileScreen(),
      ];

  @override
  void dispose() {
    _channel?.sink.close();
    _viewTimer?.cancel();
    super.dispose();
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(String, String) onViewEvent;

  const HomeTab({
    Key? key,
    required this.events,
    required this.onAddEvent,
    required this.onViewEvent,
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
        final matchesDateRange = _isEventInDateRange(event, _selectedDateRange);
        return matchesCategory && matchesDateRange;
      }).toList();
    });
  }

  bool _isEventInDateRange(Event event, String dateRange) {
    if (dateRange == 'All Dates') return true;

    try {
      DateTime eventDate = DateTime.parse(event.date);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      switch (dateRange) {
        case 'Today':
          DateTime eventDay =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          return eventDay.isAtSameMomentAs(today);
        case 'This Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfWeek = today.subtract(Duration(days: daysFromMonday));
          DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
          return eventDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        case 'This Weekend':
          int daysUntilSaturday = (6 - now.weekday) % 7;
          if (now.weekday == 7) {
            daysUntilSaturday = 6;
          }
          DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));
          DateTime thisSunday = thisSaturday.add(const Duration(days: 1));
          if (now.weekday == 7) {
            thisSaturday = today.subtract(const Duration(days: 1));
            thisSunday = today;
          }
          DateTime eventDay =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          return eventDay.isAtSameMomentAs(thisSaturday) ||
                 eventDay.isAtSameMomentAs(thisSunday);
        case 'Next Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfThisWeek = today.subtract(Duration(days: daysFromMonday));
          DateTime startOfNextWeek = startOfThisWeek.add(const Duration(days: 7));
          DateTime endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));
          return eventDate.isAfter(startOfNextWeek.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfNextWeek.add(const Duration(days: 1)));
        case 'This Month':
          DateTime startOfMonth = DateTime(now.year, now.month, 1);
          DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
          return eventDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfMonth.add(const Duration(days: 1)));
        default:
          return true;
      }
    } catch (e) {
      print('Error parsing date: $e');
      return true;
    }
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
          DateTime dateA = DateTime.parse(a);
          DateTime dateB = DateTime.parse(b);
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                  child: _EventCard(
                    event: entry.value,
                    onTap: () async {
                      String location = await _getUserLocation();
                      widget.onViewEvent(entry.value.id, location);
                    },
                  ),
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
                          builder: (context) => SearchTab(
                            events: widget.events,
                            onViewEvent: widget.onViewEvent,
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
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
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
            color: selectedDateRange != 'All Dates' ? Colors.white : Colors.grey[600],
          ),
          style: TextStyle(
            color: selectedDateRange != 'All Dates' ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          items: dateRangeOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              total: event.price,
              onPaymentSuccess: () {
                if (bookingsTabKey.currentState != null) {
                  bookingsTabKey.currentState!.addBooking({
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
        onTap();
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
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey[600]),
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
                                Icon(Icons.location_on,
                                    size: 16, color: Colors.grey[600]),
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
                            horizontal: 12, vertical: 6),
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
  final Function(String, String) onViewEvent;

  const SearchTab({Key? key, required this.events, required this.onViewEvent})
      : super(key: key);

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
        final matchesDateRange = _isEventInDateRange(event, _selectedDateRange);
        return matchesSearch && matchesCategory && matchesDateRange;
      }).toList();
    });
  }

  bool _isEventInDateRange(Event event, String dateRange) {
    if (dateRange == 'All Dates') return true;

    try {
      DateTime eventDate = DateTime.parse(event.date);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      switch (dateRange) {
        case 'Today':
          DateTime eventDay =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          return eventDay.isAtSameMomentAs(today);
        case 'This Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfWeek = today.subtract(Duration(days: daysFromMonday));
          DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
          return eventDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        case 'This Weekend':
          int daysUntilSaturday = (6 - now.weekday) % 7;
          if (now.weekday == 7) {
            daysUntilSaturday = 6;
          }
          DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));
          DateTime thisSunday = thisSaturday.add(const Duration(days: 1));
          if (now.weekday == 7) {
            thisSaturday = today.subtract(const Duration(days: 1));
            thisSunday = today;
          }
          DateTime eventDay =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          return eventDay.isAtSameMomentAs(thisSaturday) ||
                 eventDay.isAtSameMomentAs(thisSunday);
        case 'Next Week':
          int daysFromMonday = now.weekday - 1;
          DateTime startOfThisWeek = today.subtract(Duration(days: daysFromMonday));
          DateTime startOfNextWeek = startOfThisWeek.add(const Duration(days: 7));
          DateTime endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));
          return eventDate.isAfter(startOfNextWeek.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfNextWeek.add(const Duration(days: 1)));
        case 'This Month':
          DateTime startOfMonth = DateTime(now.year, now.month, 1);
          DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
          return eventDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                 eventDate.isBefore(endOfMonth.add(const Duration(days: 1)));
        default:
          return true;
      }
    } catch (e) {
      print('Error parsing date: $e');
      return true;
    }
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
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryFilterChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                              _filterEvents();
                            });
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _EventCard(
                          event: _filteredEvents[index],
                          onTap: () async {
                            String location = await _getUserLocation();
                            widget.onViewEvent(_filteredEvents[index].id, location);
                          },
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
  List<Map<String, dynamic>> bookings = [
    {'id': 1, 'event': 'Concert A', 'total': 50.0, 'paid': false},
    {'id': 2, 'event': 'Festival B', 'total': 30.0, 'paid': false},
    {'id': 3, 'event': 'Theatre C', 'total': 40.0, 'paid': true},
  ];

  void addBooking(Map<String, dynamic> booking) {
    setState(() {
      bookings.add(booking);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return ListTile(
            title: Text(booking['event']),
            subtitle: Text('Total: €${booking['total']}'),
            trailing: booking['paid']
                ? const Text('Paid', style: TextStyle(color: Colors.green))
                : ElevatedButton(
                    child: const Text('Checkout'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            total: booking['total'],
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