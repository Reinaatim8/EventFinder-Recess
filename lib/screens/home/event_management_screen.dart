import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../../models/event.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

// View Record Model (aligned with home_screen.dart)
class ViewRecord {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final String? city;
  final String? country;
  final String userId;
  final String platform;
  final String viewType;
  final String? organizerId;

  ViewRecord({
    required this.id,
    required this.eventId,
    required this.timestamp,
    this.city,
    this.country,
    required this.userId,
    required this.platform,
    required this.viewType,
    this.organizerId,
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
      organizerId: data['organizerId'],
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
      'organizerId': organizerId,
    };
  }
}

// Booking Model
class Booking {
  final String id;
  final String eventId;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime bookingDate;
  final double total;
  final bool paid;

  Booking({
    required this.id,
    required this.eventId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.bookingDate,
    required this.total,
    required this.paid,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Booking(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      bookingDate:
          (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      paid: data['paid'] ?? false,
    );
  }
}

// Add Event Screen
class AddEventScreen extends StatelessWidget {
  final VoidCallback onEventAdded;

  const AddEventScreen({Key? key, required this.onEventAdded})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Add Event Screen - Implementation Coming Soon',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}

// Edit Event Screen
class EditEventScreen extends StatelessWidget {
  final Event event;
  final VoidCallback onEventUpdated;

  const EditEventScreen({
    Key? key,
    required this.event,
    required this.onEventUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Edit Event Screen - Implementation Coming Soon',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}

// Event Details Screen
class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Future<void> _logView(String eventId) async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ??
        'anonymous';
    String? city;
    String? country;
    String? organizerId;

    try {
      // Fetch event to get organizerId
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (eventDoc.exists) {
        organizerId = eventDoc.data()?['organizerId'] as String?;
      } else {
        print('Event does not exist: $eventId');
        return;
      }

      // Get location data
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            print('Location permissions are denied.');
          }
        }

        if (permission != LocationPermission.deniedForever) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          city = placemarks.isNotEmpty ? placemarks[0].locality : null;
          country = placemarks.isNotEmpty ? placemarks[0].country : null;
        }
      }
    } catch (e) {
      print('Error getting location or event data: $e');
    }

    final viewRecord = ViewRecord(
      id: const Uuid().v4(),
      eventId: eventId,
      timestamp: DateTime.now(),
      city: city,
      country: country,
      userId: userId,
      platform: 'Unknown', // Platform detection can be added if needed
      viewType: 'detail_view',
      organizerId: organizerId,
    );

    try {
      await FirebaseFirestore.instance
          .collection('eventStats')
          .doc(viewRecord.id)
          .set(viewRecord.toFirestore());
    } catch (e) {
      print('Error recording view: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording view: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _logView(widget.event.id); // Record view when screen is opened
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Category: ${widget.event.category}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Date: ${widget.event.date}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Location: ${widget.event.location}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Description: ${widget.event.description}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EventAnalyticsScreen(event: widget.event),
                  ),
                );
              },
              child: const Text('View Analytics'),
            ),
          ],
        ),
      ),
    );
  }
}

// Attendees Screen
class AttendeesScreen extends StatelessWidget {
  final Event event;

  const AttendeesScreen({Key? key, required this.event}) : super(key: key);

  Future<List<Booking>> _getEventBookings(String eventId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: eventId)
          .get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      //if (context.mounted) {
      //ScaffoldMessenger.of(context).showSnackBar(
      //SnackBar(
      //content: Text('Error fetching bookings: $e'),
      //backgroundColor: Colors.red,
      //),
      //);
      //}
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendees for ${event.title}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Booking>>(
        future: _getEventBookings(event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookings = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text('${booking.firstName} ${booking.lastName}'),
                  subtitle: Text(
                    'Email: ${booking.email}\nPaid: ${booking.paid}',
                  ),
                  trailing: Text('€${booking.total.toStringAsFixed(2)}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Event Analytics Screen
class EventAnalyticsScreen extends StatefulWidget {
  final Event event;

  const EventAnalyticsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventAnalyticsScreen> createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  int _totalViews = 0;
  int _currentViewers = 0;
  Map<String, int> _hourlyViews = {};
  Map<String, int> _geoViews = {};
  List<Map<String, dynamic>> _activityFeed = [];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    FirebaseFirestore.instance
        .collection('eventStats')
        .where('eventId', isEqualTo: widget.event.id)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _totalViews = snapshot.docs.length;
              _currentViewers = snapshot.docs
                  .where(
                    (doc) => _isWithinLastMinute(doc['timestamp'] as Timestamp),
                  )
                  .length;
              _hourlyViews = _aggregateHourlyViews(snapshot.docs);
              _geoViews = _aggregateGeoViews(snapshot.docs);
              _activityFeed = _generateActivityFeed(snapshot.docs);
            });
          }
        });
  }

  bool _isWithinLastMinute(Timestamp timestamp) {
    final now = DateTime.now();
    final viewTime = timestamp.toDate();
    return now.difference(viewTime).inMinutes < 1;
  }

  Map<String, int> _aggregateHourlyViews(List<DocumentSnapshot> docs) {
    final hourlyMap = <String, int>{};
    final now = DateTime.now();
    for (var doc in docs) {
      final timestamp = (doc['timestamp'] as Timestamp).toDate();
      final hourKey = DateFormat('yyyy-MM-dd HH:00').format(timestamp);
      hourlyMap[hourKey] = (hourlyMap[hourKey] ?? 0) + 1;
    }
    return hourlyMap;
  }

  Map<String, int> _aggregateGeoViews(List<DocumentSnapshot> docs) {
    final geoMap = <String, int>{};
    for (var doc in docs) {
      final city = doc['city'] as String? ?? 'Unknown';
      final country = doc['country'] as String? ?? 'Unknown';
      final key = '$city, $country';
      geoMap[key] = (geoMap[key] ?? 0) + 1;
    }
    return geoMap;
  }

  List<Map<String, dynamic>> _generateActivityFeed(
    List<DocumentSnapshot> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      return {
        'userId': data['userId'],
        'city': data['city'] ?? 'Unknown',
        'country': data['country'] ?? 'Unknown',
        'timestamp': timestamp,
      };
    }).toList()..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics for ${widget.event.title}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Total Views: $_totalViews',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current Viewers: $_currentViewers',
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hourly Views',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _hourlyViews.entries.map((entry) {
                                final hour = DateTime.parse(entry.key);
                                return FlSpot(
                                  hour.millisecondsSinceEpoch.toDouble(),
                                  entry.value.toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 2,
                            ),
                          ],
                          minX: _hourlyViews.keys
                              .map(DateTime.parse)
                              .reduce((a, b) => a.isBefore(b) ? a : b)
                              .millisecondsSinceEpoch
                              .toDouble(),
                          maxX: _hourlyViews.keys
                              .map(DateTime.parse)
                              .reduce((a, b) => a.isAfter(b) ? a : b)
                              .millisecondsSinceEpoch
                              .toDouble(),
                          minY: 0,
                          maxY:
                              _hourlyViews.values.reduce(
                                (a, b) => a > b ? a : b,
                              ) +
                              1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Geographic Views',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _geoViews.length,
                      itemBuilder: (context, index) {
                        final entry = _geoViews.entries.elementAt(index);
                        return ListTile(
                          title: Text(entry.key),
                          trailing: Text(entry.value.toString()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activityFeed.length > 5
                          ? 5
                          : _activityFeed.length,
                      itemBuilder: (context, index) {
                        final activity = _activityFeed[index];
                        return ListTile(
                          title: Text('User ${activity['userId']}'),
                          subtitle: Text(
                            '${activity['city']}, ${activity['country']} - ${DateFormat('yyyy-MM-dd HH:mm').format(activity['timestamp'])}',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main Event Management Screen
class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({Key? key}) : super(key: key);

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  List<Event> organizerEvents = [];
  bool _isLoading = true;
  String? organizerId;
  bool _hasAccess = false;
  StreamSubscription? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeOrganizer();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeOrganizer() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      organizerId = authProvider.user?.uid;

      if (organizerId != null) {
        await _checkAccessAndFetchEvents();
      } else {
        setState(() {
          _isLoading = false;
          _hasAccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasAccess = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkAccessAndFetchEvents() async {
    if (organizerId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _eventsSubscription = FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .snapshots()
          .listen(
            (snapshot) {
              if (mounted) {
                setState(() {
                  organizerEvents = snapshot.docs
                      .map((doc) => Event.fromFirestore(doc))
                      .toList();
                  _hasAccess = true;
                  _isLoading = false;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasAccess = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading events: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasAccess = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchOrganizerEvents() async {
    await _checkAccessAndFetchEvents();
  }

  Future<List<Booking>> _getEventBookings(String eventId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: eventId)
          .get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return [];
    }
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Event'),
          content: Text(
            'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(event.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Event Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOrganizerEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasAccess
          ? _buildNoAccessState()
          : organizerEvents.isEmpty
          ? _buildEmptyState()
          : _buildEventsList(),
      floatingActionButton: _hasAccess
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddEventScreen(onEventAdded: _fetchOrganizerEvents),
                  ),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNoAccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Access Restricted',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This section is only available to event organizers',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first event to access management features',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first event to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddEventScreen(onEventAdded: _fetchOrganizerEvents),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Events',
                  organizerEvents.length.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: _getOverallStatsStream(),
                  builder: (context, snapshot) {
                    final stats =
                        snapshot.data ?? {'revenue': 0.0, 'bookings': 0};
                    return _buildSummaryCard(
                      'Total Revenue',
                      '€${stats['revenue'].toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: organizerEvents.length,
            itemBuilder: (context, index) {
              final event = organizerEvents[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsScreen(event: event),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteEvent(event);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Event'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Booking>>(
                          stream: _getEventBookingsStream(event.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            final bookings = snapshot.data ?? [];
                            final paidBookings = bookings
                                .where((b) => b.paid)
                                .length;
                            final totalRevenue = bookings
                                .where((b) => b.paid)
                                .fold(
                                  0.0,
                                  (sum, booking) => sum + booking.total,
                                );

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        bookings.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text('Total Bookings'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        paidBookings.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const Text('Paid'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '€${totalRevenue.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const Text('Revenue'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              event.date,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 20),
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.location,
                                style: TextStyle(color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.people,
                              label: 'Attendees',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AttendeesScreen(event: event),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditEventScreen(
                                      event: event,
                                      onEventUpdated: _fetchOrganizerEvents,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.analytics,
                              label: 'Analytics',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EventAnalyticsScreen(event: event),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Stream<Map<String, dynamic>> _getOverallStatsStream() async* {
    while (true) {
      double totalRevenue = 0.0;
      int totalBookings = 0;

      try {
        for (Event event in organizerEvents) {
          final bookings = await _getEventBookings(event.id);
          totalBookings += bookings.length;
          totalRevenue += bookings
              .where((b) => b.paid)
              .fold(0.0, (sum, booking) => sum + booking.total);
        }
      } catch (e) {
        // Handle error silently to avoid breaking the stream
      }

      yield {'revenue': totalRevenue, 'bookings': totalBookings};
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Stream<List<Booking>> _getEventBookingsStream(String eventId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
