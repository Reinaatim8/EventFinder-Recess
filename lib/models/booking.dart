import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String userId;
  final String eventId;
  final String firstName;
  final String lastName;
  final String email;
  final double total;
  final bool paid;
  final DateTime bookingDate;
  final String ticketId;
  final DateTime timestamp;

  Booking({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.total,
    required this.paid,
    required this.bookingDate,
    required this.ticketId,
    required this.timestamp,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      eventId: data['eventId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      paid: data['paid'] ?? false,
      bookingDate: (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ticketId: data['ticketId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventId': eventId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'total': total,
      'paid': paid,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'ticketId': ticketId,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}