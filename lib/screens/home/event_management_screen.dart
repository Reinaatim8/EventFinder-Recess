import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'dart:async';

// View Record Model
class ViewRecord {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final String? city;
  final String? country;

  ViewRecord({
    required this.id,
    required this.eventId,
    required this.timestamp,
    this.city,
    this.country,
  });

  factory ViewRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ViewRecord(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      city: data['city'],
      country: data['country'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'timestamp': Timestamp.fromDate(timestamp),
      'city': city,
      'country': country,
    };
  }
}

// Existing Event and Booking models (unchanged)
class Event {
  final String id;
  final String title;
  final String category;
  final String date;
  final String location;
  final String description;
  final String? imageUrl;
  final String organizerId;

  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.location,
    required this.description,
    this.imageUrl,
    required this.organizerId,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      date: data['date'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      organizerId: data['organizerId'] ?? '',
    );
  }
}

class Booking {
  final String eventId;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime bookingDate;
  final double total;
  final bool paid;

  Booking({
    required this.eventId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.bookingDate,
    required this.total,
    required this.paid,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      eventId: data['eventId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      bookingDate: (data['bookingDate'] as Timestamp).toDate(),
      total: (data['total'] as num).toDouble(),
      paid: data['paid'] ?? false,
    );
  }
}

class AddEventScreen extends StatelessWidget {
  final VoidCallback onEventAdded;

  const AddEventScreen({Key? key, required this.onEventAdded})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Event')),
      body: const Center(child: Text('Add Event Screen - Implement Me')),
    );
  }
}

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
      appBar: AppBar(title: const Text('Edit Event')),
      body: const Center(child: Text('Edit Event Screen - Implement Me')),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _initializeOrganizer();
  }

  Future<void> _initializeOrganizer() async {
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
  }

  Future<void> _checkAccessAndFetchEvents() async {
    if (organizerId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .get();

      setState(() {
        organizerEvents = snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList();
        _hasAccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasAccess = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _hasUserEvents() async {
    if (organizerId == null) return false;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchOrganizerEvents() async {
    await _checkAccessAndFetchEvents();
  }

  Future<List<Booking>> _getEventBookings(String eventId) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: eventId)
          .get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      bool? confirmed = await showDialog<bool>(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchOrganizerEvents();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
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
                            PopupMenuButton(
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

      for (Event event in organizerEvents) {
        List<Booking> bookings = await _getEventBookings(event.id);
        totalBookings += bookings.length;
        totalRevenue += bookings
            .where((b) => b.paid)
            .fold(0.0, (sum, booking) => sum + booking.total);
      }

      yield {'revenue': totalRevenue, 'bookings': totalBookings};
      await Future.delayed(const Duration(seconds: 5)); // Pull every 5 seconds
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
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
                ),
              ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(event.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, 'Date', event.date),
            _buildInfoRow(Icons.location_on, 'Location', event.location),
            _buildInfoRow(Icons.category, 'Category', event.category),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class AttendeesScreen extends StatefulWidget {
  final Event event;

  const AttendeesScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  List<Booking> allBookings = [];
  List<Booking> filteredBookings = [];
  String _filterStatus = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: widget.event.id)
          .orderBy('bookingDate', descending: true)
          .get();

      setState(() {
        allBookings = snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();
        _filterBookings();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterBookings() {
    setState(() {
      switch (_filterStatus) {
        case 'paid':
          filteredBookings = allBookings
              .where((booking) => booking.paid)
              .toList();
          break;
        case 'pending':
          filteredBookings = allBookings
              .where((booking) => !booking.paid)
              .toList();
          break;
        default:
          filteredBookings = allBookings;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} - Attendees'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          'All',
                          'all',
                          allBookings.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          'Paid',
                          'paid',
                          allBookings.where((b) => b.paid).length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          'Pending',
                          'pending',
                          allBookings.where((b) => !b.paid).length,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredBookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_filterStatus == 'all' ? '' : _filterStatus} bookings',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredBookings.length,
                          itemBuilder: (context, index) {
                            final booking = filteredBookings[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: booking.paid
                                      ? Colors.green
                                      : Colors.orange,
                                  child: Icon(
                                    booking.paid ? Icons.check : Icons.pending,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  '${booking.firstName} ${booking.lastName}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(booking.email),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Booked: ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '€${booking.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: booking.paid
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        booking.paid ? 'Paid' : 'Pending',
                                        style: TextStyle(
                                          color: booking.paid
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
          _filterBookings();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventAnalyticsScreen extends StatefulWidget {
  final Event event;

  const EventAnalyticsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventAnalyticsScreen> createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  Timer? _debounceTimer;
  int _currentViewers = 0;
  List<Map<String, dynamic>> _activityFeed = [];
  Map<String, int> _hourlyViews = {};
  Map<String, int> _geoViews = {};

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event.id)
        .collection('views')
        .snapshots()
        .listen((snapshot) {
          if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            setState(() {
              final now = DateTime.now();
              final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
              _currentViewers = snapshot.docs
                  .where(
                    (doc) => (doc['timestamp'] as Timestamp).toDate().isAfter(
                      tenMinutesAgo,
                    ),
                  )
                  .length;
              _activityFeed =
                  snapshot.docs
                      .map(
                        (doc) => {
                          'message':
                              'New view from ${doc['city'] ?? 'Unknown'}',
                          'timestamp': (doc['timestamp'] as Timestamp).toDate(),
                        },
                      )
                      .toList()
                    //..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
                    //_activityFeed = _activityFeed.take(10).toList();
                    ..sort((a, b) {
                      final aTime = a['timestamp'] as Timestamp?;
                      final bTime = b['timestamp'] as Timestamp?;

                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;

                      return bTime.compareTo(
                        aTime,
                      ); // Descending order (newest first)
                    });
              _hourlyViews = {};
              _geoViews = {};
              for (var doc in snapshot.docs) {
                final view = ViewRecord.fromFirestore(doc);
                final hour = DateFormat('HH:00').format(view.timestamp);
                _hourlyViews[hour] = (_hourlyViews[hour] ?? 0) + 1;
                final geoKey =
                    '${view.city ?? 'Unknown'}, ${view.country ?? 'Unknown'}';

                _geoViews[geoKey] = (_geoViews[geoKey] ?? 0) + 1;
              }
            });
          });
        });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Stream<List<Booking>> _getEventBookingsStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('eventId', isEqualTo: widget.event.id)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} - Analytics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Booking>>(
        stream: _getEventBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data ?? [];
          final totalBookings = bookings.length;
          final paidBookings = bookings.where((b) => b.paid).length;
          final pendingBookings = totalBookings - paidBookings;
          final totalRevenue = bookings
              .where((b) => b.paid)
              .fold(0.0, (sum, booking) => sum + booking.total);
          final averageBookingValue = paidBookings > 0
              ? totalRevenue / paidBookings
              : 0.0;
          final conversionRate = totalBookings > 0
              ? (paidBookings / totalBookings * 100).toStringAsFixed(1)
              : '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Current Viewers',
                        _currentViewers.toString(),
                        Icons.visibility,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Bookings',
                        totalBookings.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Paid Bookings',
                        paidBookings.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Conversion Rate',
                        '$conversionRate%',
                        Icons.trending_up,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Revenue',
                        '€${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Avg. Booking',
                        '€${averageBookingValue.toStringAsFixed(2)}',
                        Icons.calculate,
                        Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Activity Feed
                Text(
                  'Activity Feed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
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
                  child: _activityFeed.isEmpty
                      ? const Center(child: Text('No recent activity'))
                      : Column(
                          children: _activityFeed
                              .map(
                                (activity) => ListTile(
                                  leading: const Icon(Icons.visibility),
                                  title: Text(activity['message']),
                                  subtitle: Text(
                                    DateFormat(
                                      'MMM dd, HH:mm',
                                    ).format(activity['timestamp']),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 24),

                // Temporal Analytics
                Text(
                  'Hourly View Trends',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
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
                  child: _hourlyViews.isEmpty
                      ? const Center(child: Text('No view data available'))
                      : Column(
                          children: _hourlyViews.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value:
                                          entry.value /
                                          (_hourlyViews.values.reduce(
                                                (a, b) => a > b ? a : b,
                                              ) +
                                              0.1),
                                      backgroundColor: Colors.grey[200],
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('${entry.value} views'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 24),

                // Geographic Analytics
                Text(
                  'Geographic Distribution',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
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
                  child: _geoViews.isEmpty
                      ? const Center(
                          child: Text('No geographic data available'),
                        )
                      : Column(
                          children: _geoViews.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value:
                                          entry.value /
                                          (_geoViews.values.reduce(
                                                (a, b) => a > b ? a : b,
                                              ) +
                                              0.1),
                                      backgroundColor: Colors.grey[200],
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('${entry.value} views'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
