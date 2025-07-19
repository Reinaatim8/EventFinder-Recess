import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart'; 

// Placeholder Event model (replace with your actual Event model)
// class Event {
//   final String id;
//   final String title;
//   final String category;
//   final String date;
//   final String location;
//   final String description;
//   final String? imageUrl;
//   final String organizerId;
//   final double price;

//    Event({
//     required this.id,
//     required this.title,
//     required this.category,
//     required this.date,
//     required this.location,
//     required this.description,
//     this.imageUrl,
//     required this.organizerId, 
//     required this.price,
//   });

//   factory Event.fromFirestore(DocumentSnapshot doc) {
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//     return Event(
//       id: doc.id,
//       title: data['title'] ?? '',
//       category: data['category'] ?? '',
//       date: data['date'] ?? '',
//       location: data['location'] ?? '',
//       description: data['description'] ?? '',
//       imageUrl: data['imageUrl'],
//       organizerId: data['organizerId'] ?? '',
//       price: (data['price'] as num).toDouble(),
//     );
//   }

  get status => null;

  get timestamp => null;

  get rejectionReason => null;

  get approvedAt => null;

//   Map<String, dynamic> toFirestore() {
//     return {
//       'title': title,
//       'category': category,
//       'date': date,
//       'location': location,
//       'description': description,
//       'imageUrl': imageUrl,
//       'organizerId': organizerId,
//       'price': price,
//     };
//   }
// }

// Booking model
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

// Placeholder AddEventScreen (replace with actual implementation)
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

// Placeholder EditEventScreen (replace with actual implementation)
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

  // Checks if the user has any events in Firestore and fetches them
  Future<void> _checkAccessAndFetchEvents() async {
    if (organizerId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('Fetching events for organizerId: $organizerId');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .get();
      
      print('Found ${snapshot.docs.length} events');
      snapshot.docs.forEach((doc) => print('Event data: ${doc.data()}'));

      setState(() {
        organizerEvents = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        _hasAccess = true; // Allow access for authenticated users to create events
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
        _hasAccess = true; // Still allow access to try creating events
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // New method to explicitly check if the user has any events
  Future<bool> _hasUserEvents() async {
    if (organizerId == null) return false;
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: organizerId)
          .limit(1) // Optimize by limiting to one document
          .get();
      
      print('Has user events: ${snapshot.docs.isNotEmpty}');
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
      // Show confirmation dialog
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Event Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
              backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
              Navigator.pop(context); // Go back to previous screen
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
              backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
        // Summary cards at the top
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
            ],
          ),
        ),
        // Events list
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
                                color: Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getCategoryIcon(event.category),
                                color: Color.fromARGB(255, 25, 25, 95),
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
                        
                        // Booking status
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
                                final bookedCount = bookings.length;
                            final maxslots = event.maxslots ?? 0;
                            final slotsRemaining = maxslots - bookedCount;
                            
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
                                  if (maxslots > 0) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      slotsRemaining > 0
                                        ? 'Slots remaining: $slotsRemaining'
                                        : 'Slots full',
                                      style: TextStyle(
                                        color: slotsRemaining > 0 ? Colors.orange : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],

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
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Color.fromARGB(255, 25, 25, 95)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Color.fromARGB(255, 25, 25, 95),
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
mixin maxSlots {
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
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              style: const TextStyle(fontSize: 16),
            ),
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
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Enhanced Attendees Screen
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
        allBookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
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
          filteredBookings = allBookings.where((booking) => booking.paid).toList();
          break;
        case 'pending':
          filteredBookings = allBookings.where((booking) => !booking.paid).toList();
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
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
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
                // Filter tabs
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip('All', 'all', allBookings.length),
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
                
                // Bookings list
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
                                title: Text('${booking.firstName} ${booking.lastName}'),
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
                                          color: booking.paid ? Colors.green : Colors.orange,
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
          color: isSelected 
              ? Color.fromARGB(255, 25, 25, 95)
              : Colors.grey[200],
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

// Enhanced Event Analytics Screen
class EventAnalyticsScreen extends StatelessWidget {
  final Event event;

  const EventAnalyticsScreen({Key? key, required this.event}) : super(key: key);

  Future<List<Booking>> _getEventBookings() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('eventId', isEqualTo: event.id)
          .get();
      
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching bookings: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${event.title} - Analytics'),
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Booking>>(
        future: _getEventBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final bookings = snapshot.data ?? [];
          final totalBookings = bookings.length;
          final paidBookings = bookings.where((b) => b.paid).length;
          final pendingBookings = totalBookings - paidBookings;
          final totalRevenue = bookings.where((b) => b.paid).fold(0.0, (sum, booking) => sum + booking.total);
          final averageBookingValue = paidBookings > 0 ? totalRevenue / paidBookings : 0.0;

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
                        'Total Bookings',
                        totalBookings.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Paid Bookings',
                        paidBookings.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending Bookings',
                        pendingBookings.toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Revenue',
                        '€${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(
                  'Average Booking Value',
                  '€${averageBookingValue.toStringAsFixed(2)}',
                  Icons.calculate,
                  Colors.teal,
                ),
                const SizedBox(height: 24),

                // Detailed Analytics
                Text(
                  'Booking Trends',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Status Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusIndicator(
                            'Paid',
                            paidBookings,
                            Colors.green,
                          ),
                          _buildStatusIndicator(
                            'Pending',
                            pendingBookings,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}