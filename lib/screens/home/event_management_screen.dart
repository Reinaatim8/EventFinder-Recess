import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import 'dart:async';

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
  final int timeSpent;
  final List<String> interactions;

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
    this.timeSpent = 0,
    this.interactions = const [],
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
      timeSpent: data['timeSpent'] ?? 0,
      interactions: List<String>.from(data['interactions'] ?? []),
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
      'timeSpent': timeSpent,
      'interactions': interactions,
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

// Event Analytics Screen
class EventAnalyticsScreen extends StatefulWidget {
  final Event event;

  const EventAnalyticsScreen({Key? key, required this.event}) : super(key: key);

  @override
  _EventAnalyticsScreenState createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  String _selectedTimeRange = 'Today';
  final List<String> _timeRanges = [
    'Today',
    'This Week',
    'This Month',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} Analytics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey[300] ?? Colors.grey,
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTimeRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  dropdownColor: Colors.white,
                  items: _timeRanges.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTimeRange = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            // View Metrics
            StreamBuilder<List<ViewRecord>>(
              stream: _getViewRecordsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final viewRecords = snapshot.data ?? [];
                final filteredViews = _filterViewsByTimeRange(viewRecords);
                final totalViews = filteredViews.length;
                final uniqueUsers = filteredViews
                    .map((view) => view.userId)
                    .toSet()
                    .length;
                final avgTimeSpent = filteredViews.isNotEmpty
                    ? filteredViews
                              .map((view) => view.timeSpent)
                              .reduce((a, b) => a + b) /
                          filteredViews.length
                    : 0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Views',
                        totalViews.toString(),
                        Icons.remove_red_eye,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Unique Users',
                        uniqueUsers.toString(),
                        Icons.person,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Avg Time Spent',
                        '${avgTimeSpent.toStringAsFixed(1)}s',
                        Icons.timer,
                        Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Booking Metrics
            StreamBuilder<List<Booking>>(
              stream: _getBookingsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final bookings = snapshot.data ?? [];
                final filteredBookings = _filterBookingsByTimeRange(bookings);
                final totalBookings = filteredBookings.length;
                final paidBookings = filteredBookings
                    .where((b) => b.paid)
                    .length;
                final totalRevenue = filteredBookings
                    .where((b) => b.paid)
                    .fold(0.0, (sum, booking) => sum + booking.total);

                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Bookings',
                        totalBookings.toString(),
                        Icons.event_seat,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Paid Bookings',
                        paidBookings.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Revenue',
                        '€${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.blue,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // View Trends (Line Chart)
            StreamBuilder<List<ViewRecord>>(
              stream: _getViewRecordsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final viewRecords = snapshot.data ?? [];
                final filteredViews = _filterViewsByTimeRange(viewRecords);
                final viewCountsByTime = _aggregateByTime<ViewRecord>(
                  filteredViews,
                  (view) => view.timestamp,
                );

                if (viewCountsByTime.every((count) => count == 0)) {
                  return Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'No view data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'View Trends Over Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    String title = '';
                                    switch (_selectedTimeRange) {
                                      case 'Today':
                                        title = '${value.toInt()}:00';
                                        break;
                                      case 'This Week':
                                        title = _getDayOfWeek(value.toInt());
                                        break;
                                      case 'This Month':
                                        title = 'Week ${value.toInt() + 1}';
                                        break;
                                      case 'All Time':
                                        title = 'Month ${value.toInt() + 1}';
                                        break;
                                    }
                                    return Text(
                                      title,
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                  interval: _selectedTimeRange == 'Today'
                                      ? 4
                                      : 1,
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
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: viewCountsByTime
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        e.value.toDouble(),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.blue,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Booking Trends (Line Chart)
            StreamBuilder<List<Booking>>(
              stream: _getBookingsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final bookings = snapshot.data ?? [];
                final filteredBookings = _filterBookingsByTimeRange(bookings);
                final bookingCountsByTime = _aggregateByTime<Booking>(
                  filteredBookings,
                  (booking) => booking.bookingDate,
                );

                if (bookingCountsByTime.every((count) => count == 0)) {
                  return Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'No booking data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking Trends Over Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    String title = '';
                                    switch (_selectedTimeRange) {
                                      case 'Today':
                                        title = '${value.toInt()}:00';
                                        break;
                                      case 'This Week':
                                        title = _getDayOfWeek(value.toInt());
                                        break;
                                      case 'This Month':
                                        title = 'Week ${value.toInt() + 1}';
                                        break;
                                      case 'All Time':
                                        title = 'Month ${value.toInt() + 1}';
                                        break;
                                    }
                                    return Text(
                                      title,
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                  interval: _selectedTimeRange == 'Today'
                                      ? 4
                                      : 1,
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
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: bookingCountsByTime
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        e.value.toDouble(),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.purple,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.purple.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Geographic Distribution
            StreamBuilder<List<ViewRecord>>(
              stream: _getViewRecordsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final viewRecords = snapshot.data ?? [];
                final filteredViews = _filterViewsByTimeRange(viewRecords);
                final locationCounts = _aggregateViewsByLocation(filteredViews);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Geographic Distribution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (locationCounts.isEmpty)
                        const Text(
                          'No location data available',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        )
                      else
                        ...locationCounts.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${entry.key['city'] ?? 'Unknown'}, ${entry.key['country'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '${entry.value} views',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // View Activity Feed
            StreamBuilder<List<ViewRecord>>(
              stream: _getViewRecordsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final viewRecords = snapshot.data ?? [];
                final filteredViews = _filterViewsByTimeRange(viewRecords)
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent View Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filteredViews.isEmpty)
                        const Text(
                          'No view activity available',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        )
                      else
                        ...filteredViews.take(10).map((view) {
                          return ListTile(
                            leading: Icon(
                              Icons.visibility,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            title: Text(
                              'User ${view.userId.substring(0, 8)} viewed from ${view.city ?? 'Unknown'}, ${view.country ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'Platform: ${view.platform} | Time Spent: ${view.timeSpent}s | Interactions: ${view.interactions.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: Text(
                              DateFormat(
                                'MMM dd, HH:mm',
                              ).format(view.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Booking Activity Feed
            StreamBuilder<List<Booking>>(
              stream: _getBookingsStream(widget.event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final bookings = snapshot.data ?? [];
                final filteredBookings = _filterBookingsByTimeRange(bookings)
                  ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Booking Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filteredBookings.isEmpty)
                        const Text(
                          'No booking activity available',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        )
                      else
                        ...filteredBookings.take(10).map((booking) {
                          return ListTile(
                            leading: Icon(
                              Icons.event_seat,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            title: Text(
                              '${booking.firstName} ${booking.lastName} booked',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'Email: ${booking.email} | Status: ${booking.paid ? 'Paid' : 'Pending'} | Amount: €${booking.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: Text(
                              DateFormat(
                                'MMM dd, HH:mm',
                              ).format(booking.bookingDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<ViewRecord>> _getViewRecordsStream(String eventId) {
    return FirebaseFirestore.instance
        .collection('eventStats')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ViewRecord.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<Booking>> _getBookingsStream(String eventId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  List<ViewRecord> _filterViewsByTimeRange(List<ViewRecord> views) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeRange) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        final daysFromMonday = now.weekday - 1;
        startDate = now.subtract(Duration(days: daysFromMonday));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'All Time':
        return views; // No filtering
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return views.where((view) => view.timestamp.isAfter(startDate)).toList();
  }

  List<Booking> _filterBookingsByTimeRange(List<Booking> bookings) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeRange) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        final daysFromMonday = now.weekday - 1;
        startDate = now.subtract(Duration(days: daysFromMonday));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'All Time':
        return bookings; // No filtering
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return bookings
        .where((booking) => booking.bookingDate.isAfter(startDate))
        .toList();
  }

  List<int> _aggregateByTime<T>(
    List<T> items,
    DateTime Function(T) getTimestamp,
  ) {
    final now = DateTime.now();
    List<int> counts;

    switch (_selectedTimeRange) {
      case 'Today':
        counts = List.filled(24, 0); // Hourly buckets
        for (var item in items) {
          final hour = getTimestamp(item).hour;
          counts[hour]++;
        }
        break;
      case 'This Week':
        counts = List.filled(7, 0); // Daily buckets
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        for (var item in items) {
          final dayDiff = getTimestamp(
            item,
          ).difference(startOfWeek).inDays.clamp(0, 6);
          counts[dayDiff]++;
        }
        break;
      case 'This Month':
        counts = List.filled(4, 0); // Weekly buckets
        final startOfMonth = DateTime(now.year, now.month, 1);
        for (var item in items) {
          final weekDiff =
              getTimestamp(item).difference(startOfMonth).inDays ~/ 7;
          if (weekDiff < 4) counts[weekDiff]++;
        }
        break;
      case 'All Time':
        counts = List.filled(12, 0); // Monthly buckets
        final startYear = items.isNotEmpty
            ? items
                  .map((item) => getTimestamp(item).year)
                  .reduce((a, b) => a < b ? a : b)
            : now.year;
        for (var item in items) {
          final monthDiff =
              (getTimestamp(item).year - startYear) * 12 +
              getTimestamp(item).month -
              1;
          if (monthDiff < 12) counts[monthDiff]++;
        }
        break;
      default:
        counts = List.filled(24, 0);
    }

    return counts;
  }

  Map<Map<String, String?>, int> _aggregateViewsByLocation(
    List<ViewRecord> views,
  ) {
    final locationCounts = <Map<String, String?>, int>{};
    for (var view in views) {
      final key = {'city': view.city, 'country': view.country};
      locationCounts[key] = (locationCounts[key] ?? 0) + 1;
    }
    return locationCounts;
  }

  String _getDayOfWeek(int index) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index % 7];
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${event.title} Attendees'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Booking>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('eventId', isEqualTo: event.id)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => Booking.fromFirestore(doc))
                  .toList(),
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(
              child: Text(
                'No attendees yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
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
                    'Email: ${booking.email}\nStatus: ${booking.paid ? 'Paid' : 'Pending'}\nBooked: ${DateFormat('MMM dd, yyyy').format(booking.bookingDate)}',
                  ),
                  trailing: Text(
                    '€${booking.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Event Details Screen
class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailsScreenState createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  DateTime? _viewStartTime;
  String? _viewRecordId;

  @override
  void initState() {
    super.initState();
    _recordViewStart(context, widget.event);
  }

  @override
  void dispose() {
    _recordViewEnd(context);
    super.dispose();
  }

  Future<void> _recordViewStart(BuildContext context, Event event) async {
    _viewStartTime = DateTime.now();
    _viewRecordId = const Uuid().v4();
    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ??
        'anonymous';
    String? city;
    String? country;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location services are disabled. Please enable them to record location data.',
              ),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _recordViewStart(context, event),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
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
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    final viewRecord = ViewRecord(
      id: _viewRecordId!,
      eventId: event.id,
      timestamp: _viewStartTime!,
      city: city,
      country: country,
      userId: userId,
      platform: Theme.of(context).platform == TargetPlatform.android
          ? 'Android'
          : Theme.of(context).platform == TargetPlatform.iOS
          ? 'iOS'
          : 'Unknown',
      viewType: 'detail_view',
      organizerId: event.organizerId,
      timeSpent: 0,
      interactions: ['viewed_details'],
    );

    try {
      await FirebaseFirestore.instance
          .collection('eventStats')
          .doc(viewRecord.id)
          .set(viewRecord.toFirestore());
    } catch (e) {
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

  Future<void> _recordViewEnd(BuildContext context) async {
    if (_viewStartTime == null || _viewRecordId == null) return;

    final timeSpent = DateTime.now().difference(_viewStartTime!).inSeconds;
    try {
      await FirebaseFirestore.instance
          .collection('eventStats')
          .doc(_viewRecordId)
          .update({
            'timeSpent': timeSpent,
            'interactions': FieldValue.arrayUnion(['view_ended']),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating view: $e'),
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
        title: Text(widget.event.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.event.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.event.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.event.category,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  widget.event.date,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.event.location,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.event.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AttendeesScreen(event: widget.event),
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
                            EventAnalyticsScreen(event: widget.event),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Analytics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
                  organizerEvents.sort((a, b) {
                    final aDate = _parseDate(a.date);
                    final bDate = _parseDate(b.date);
                    final aPast = aDate.isBefore(DateTime.now());
                    final bPast = bDate.isBefore(DateTime.now());
                    if (aPast && !bPast) return 1;
                    if (!aPast && bPast) return -1;
                    return aDate.compareTo(bDate);
                  });
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

  DateTime _parseDate(String date) {
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
          debugPrint('Error parsing date "$date": $e');
          // Recommendation: Store dates in Firestore as Timestamp or ISO 8601 strings for consistency
          return DateTime.now();
        }
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

  Stream<Map<String, dynamic>> _getOverallStatsStream() {
    if (organizerEvents.isEmpty) {
      return Stream.value({'revenue': 0.0, 'bookings': 0});
    }
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('eventId', whereIn: organizerEvents.map((e) => e.id).toList())
        .snapshots()
        .map((snapshot) {
          double totalRevenue = 0.0;
          int totalBookings = snapshot.docs.length;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['paid'] == true) {
              totalRevenue += (data['total'] as num?)?.toDouble() ?? 0.0;
            }
          }
          return {'revenue': totalRevenue, 'bookings': totalBookings};
        });
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
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
                    if (snapshot.hasError) {
                      return _buildSummaryCard(
                        'Total Revenue',
                        'Error',
                        Icons.attach_money,
                        Colors.red,
                      );
                    }
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
                            if (snapshot.hasError) {
                              return const Text(
                                'Error loading bookings',
                                style: TextStyle(color: Colors.red),
                              );
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
}
