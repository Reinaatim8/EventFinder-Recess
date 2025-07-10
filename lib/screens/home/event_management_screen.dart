import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'package:animate_do/animate_do.dart';

// View Event model for activity feed
class ViewEvent {
  final String eventId;
  final String location;
  final DateTime timestamp;

  ViewEvent({
    required this.eventId,
    required this.location,
    required this.timestamp,
  });

  factory ViewEvent.fromJson(Map<String, dynamic> json) {
    return ViewEvent(
      eventId: json['eventId'],
      location: json['location'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class Event {
  final String id;
  final String title;
  final String category;
  final String date;
  final String location;
  final String description;
  final String? imageUrl;
  final String organizerId;
  final int viewCount;

  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.location,
    required this.description,
    this.imageUrl,
    required this.organizerId,
    this.viewCount = 0,
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
      viewCount: (data['viewCount'] ?? 0).toInt(),
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

  const AddEventScreen({Key? key, required this.onEventAdded}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
      ),
      body: const Center(
        child: Text('Add Event Screen - Implement Me'),
      ),
    );
  }
}

class EditEventScreen extends StatelessWidget {
  final Event event;
  final VoidCallback onEventUpdated;

  const EditEventScreen({Key? key, required this.event, required this.onEventUpdated}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
      ),
      body: const Center(
        child: Text('Edit Event Screen - Implement Me'),
      ),
    );
  }
}

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({Key? key}) : super(key: key);

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> with SingleTickerProviderStateMixin {
  List<Event> organizerEvents = [];
  List<ViewEvent> recentViews = [];
  bool _isLoading = true;
  String? organizerId;
  bool _hasAccess = false;
  WebSocketChannel? _channel;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _initializeOrganizer();
    _connectWebSocket();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  Future<void> _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://your-websocket-server-url'), // Replace with your WebSocket server URL
      );
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == 'view_event') {
          setState(() {
            recentViews.insert(0, ViewEvent.fromJson(data['data']));
            if (recentViews.length > 10) recentViews.removeLast();
            final eventIndex = organizerEvents.indexWhere(
                (event) => event.id == data['data']['eventId']);
            if (eventIndex != -1) {
              organizerEvents[eventIndex] = Event(
                id: organizerEvents[eventIndex].id,
                title: organizerEvents[eventIndex].title,
                category: organizerEvents[eventIndex].category,
                date: organizerEvents[eventIndex].date,
                location: organizerEvents[eventIndex].location,
                description: organizerEvents[eventIndex].description,
                imageUrl: organizerEvents[eventIndex].imageUrl,
                organizerId: organizerEvents[eventIndex].organizerId,
                viewCount: organizerEvents[eventIndex].viewCount + 1,
              );
              _animationController?.forward(from: 0);
            }
          });
        }
      }, onError: (error) {
        print('WebSocket error: $error');
      });
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  Future<void> _initializeOrganizer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    organizerId = authProvider.user?.uid;
    
    if (organizerId != null) {
      print('Initializing organizer with ID: $organizerId');
      await _checkAccessAndFetchEvents();
    } else {
      print('No organizer ID found, denying access');
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
        organizerEvents = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        _hasAccess = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
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
      print('Error checking user events: $e');
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
      print('Error fetching bookings: $e');
      return [];
    }
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
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
  void dispose() {
    _channel?.sink.close();
    _animationController?.dispose();
    super.dispose();
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
                    builder: (context) => AddEventScreen(
                      onEventAdded: _fetchOrganizerEvents,
                    ),
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
          Icon(
            Icons.lock_outline,
            size: 100,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first event to access management features',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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
          Icon(
            Icons.event_note,
            size: 100,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEventScreen(
                    onEventAdded: _fetchOrganizerEvents,
                  ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _getOverallStats(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? {'revenue': 0.0, 'bookings': 0};
                        return _buildSummaryCard(
                          'Total Revenue',
                          '€${stats['revenue'].toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Views',
                      organizerEvents.fold(0, (sum, event) => sum + event.viewCount).toString(),
                      Icons.visibility,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                child: ListView.builder(
                  itemCount: recentViews.length,
                  itemBuilder: (context, index) {
                    final view = recentViews[index];
                    final event = organizerEvents.firstWhere(
                        (e) => e.id == view.eventId,
                        orElse: () => Event(
                              id: '',
                              title: 'Unknown Event',
                              category: '',
                              date: '',
                              location: '',
                              description: '',
                              organizerId: '',
                            ));
                    return FadeIn(
                      duration: Duration(milliseconds: 300),
                      child: ListTile(
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          'Someone viewed ${event.title}',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          'From ${view.location} • ${DateTime.now().difference(view.timestamp).inSeconds} seconds ago',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
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
              return FadeIn(
                duration: Duration(milliseconds: 300),
                child: Card(
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
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                          FutureBuilder<List<Booking>>(
                            future: _getEventBookings(event.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const LinearProgressIndicator();
                              }
                              final bookings = snapshot.data ?? [];
                              final paidBookings = bookings.where((b) => b.paid).length;
                              final totalRevenue = bookings.where((b) => b.paid)
                                  .fold(0.0, (sum, booking) => sum + booking.total);
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                        AnimatedBuilder(
                                          animation: _animationController!,
                                          builder: (context, child) {
                                            return Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Text(
                                                  event.viewCount.toString(),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                                if (_animationController!.isAnimating)
                                                  Container(
                                                    width: 30,
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.green.withOpacity(
                                                          _animationController!.value * 0.2),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        const Text('Views'),
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
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                event.date,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 20),
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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
                                      builder: (context) => AttendeesScreen(event: event),
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
                                      builder: (context) => EventAnalyticsScreen(event: event),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _animationController!,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_animationController!.isAnimating && title == 'Total Views')
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(_animationController!.value * 0.2),
                        ),
                      ),
                  ],
                );
              },
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getOverallStats() async {
    double totalRevenue = 0.0;
    int totalBookings = 0;
    
    for (Event event in organizerEvents) {
      List<Booking> bookings = await _getEventBookings(event.id);
      totalBookings += bookings.length;
      totalRevenue += bookings.where((b) => b.paid).fold(0.0, (sum, booking) => sum + booking.total);
    }
    
    return {
      'revenue': totalRevenue,
      'bookings': totalBookings,
    };
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: on