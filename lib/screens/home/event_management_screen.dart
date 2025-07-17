import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

// Helper class to share common methods
class EventUtils {
  static IconData getCategoryIcon(String category) {
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

// View Record Model (consistent with home_screen.dart)
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

// Attendees Screen
class AttendeesScreen extends StatefulWidget {
  final Event event;

  const AttendeesScreen({Key? key, required this.event}) : super(key: key);

  @override
  _AttendeesScreenState createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  List<Booking> _attendees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendees();
  }

  Future<void> _fetchAttendees() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: widget.event.id)
          .get();
      setState(() {
        _attendees = snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching attendees: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} Attendees'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Attendees Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Attendees will appear here once they book',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _attendees.length,
              itemBuilder: (context, index) {
                final attendee = _attendees[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Text(
                        attendee.firstName.isNotEmpty
                            ? attendee.firstName[0]
                            : 'A',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    title: Text('${attendee.firstName} ${attendee.lastName}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attendee.email),
                        const SizedBox(height: 4),
                        Text(
                          'Booked: ${DateFormat.yMMMd().format(attendee.bookingDate)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Status: ${attendee.paid ? 'Paid' : 'Pending'}',
                          style: TextStyle(
                            color: attendee.paid ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text('€${attendee.total.toStringAsFixed(2)}'),
                  ),
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
  _EventAnalyticsScreenState createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  List<ViewRecord> _views = [];
  bool _isLoading = true;
  Map<String, int> _hourlyViews = {};
  Map<String, int> _geoDistribution = {};

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('views')
          .get();

      final views = snapshot.docs
          .map((doc) => ViewRecord.fromFirestore(doc))
          .toList();

      // Aggregate hourly views
      final hourlyViews = <String, int>{};
      final now = DateTime.now();
      for (var view in views) {
        if (now.difference(view.timestamp).inHours <= 24) {
          final hour = DateFormat('HH').format(view.timestamp);
          hourlyViews[hour] = (hourlyViews[hour] ?? 0) + 1;
        }
      }

      // Aggregate geographic distribution
      final geoDistribution = <String, int>{};
      for (var view in views) {
        final location = view.city != null && view.country != null
            ? '${view.city}, ${view.country}'
            : view.country ?? 'Unknown';
        geoDistribution[location] = (geoDistribution[location] ?? 0) + 1;
      }

      setState(() {
        _views = views;
        _hourlyViews = hourlyViews;
        _geoDistribution = geoDistribution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<FlSpot> _getHourlyViewSpots() {
    final spots = <FlSpot>[];
    final now = DateTime.now();
    for (int i = 0; i < 24; i++) {
      final hour = ((now.hour - 23 + i) % 24).toString().padLeft(2, '0');
      final count = _hourlyViews[hour] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} Analytics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Analytics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Total Views: ${_views.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        final hour =
                                            ((DateTime.now().hour -
                                                23 +
                                                value.toInt()) %
                                            24);
                                        return Text(
                                          hour.toString().padLeft(2, '0'),
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                      interval: 4,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _getHourlyViewSpots(),
                                    isCurved: true,
                                    color: Theme.of(context).primaryColor,
                                    barWidth: 3,
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                ],
                                minY: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Views in the last 24 hours',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Geographic Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: _geoDistribution.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${entry.value} views',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Platform Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children:
                            {
                              'Android': _views
                                  .where((v) => v.platform == 'Android')
                                  .length,
                              'iOS': _views
                                  .where((v) => v.platform == 'iOS')
                                  .length,
                              'Unknown': _views
                                  .where((v) => v.platform == 'Unknown')
                                  .length,
                            }.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      '${entry.value} views',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Event Details Screen
class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                        EventUtils.getCategoryIcon(event.category),
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(event.date, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              event.description,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'Category: ${event.category}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ${event.price is num ? '€${event.price.toStringAsFixed(2)}' : event.price}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendeesScreen(event: event),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('View Attendees'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EventAnalyticsScreen(event: event),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Analytics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
                                EventUtils.getCategoryIcon(event.category),
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
        print('Error fetching stats: $e');
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
