import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveBookingToFirestore(Map<String, dynamic> bookingData) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final bookingId = _firestore.collection('bookings').doc().id;
      
      final completeBookingData = {
        'eventId': bookingData['eventId'] ?? '',
        'firstName': bookingData['firstName'] ?? '',
        'lastName': bookingData['lastName'] ?? '',
        'email': bookingData['email'] ?? '',
        'bookingDate': bookingData['bookingDate'] ?? Timestamp.now(),
        'total': (bookingData['total'] as num?)?.toDouble() ?? 0.0,
        'paid': bookingData['paid'] ?? false,
        'userId': currentUser.uid,
        'ticketId': bookingData['ticketId'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      };

      print('Saving booking: $completeBookingData');
      await _firestore.collection('bookings').doc(bookingId).set(completeBookingData);
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookings')
          .doc(bookingId)
          .set(completeBookingData);

      await saveBookingLocally(completeBookingData);
      print('Booking saved successfully: $bookingId');
    } catch (e) {
      print('Error saving booking to Firestore: $e');
      await saveBookingLocally(bookingData);
      throw e;
    }
  }

  Future<void> saveBookingLocally(Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> bookings = prefs.getStringList('bookings') ?? [];
      
      final localBookingData = Map<String, dynamic>.from(bookingData);
      if (localBookingData['bookingDate'] is Timestamp) {
        localBookingData['bookingDate'] = (localBookingData['bookingDate'] as Timestamp).millisecondsSinceEpoch;
      }
      
      bookings.add(jsonEncode(localBookingData));
      await prefs.setStringList('bookings', bookings);
      print('Booking saved locally');
    } catch (e) {
      print('Error saving booking locally: $e');
    }
  }

  Future<List<Booking>> getEventBookings(String eventId) async {
    try {
      print('Fetching bookings for eventId: $eventId');
      
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('eventId', isEqualTo: eventId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${snapshot.docs.length} bookings for event $eventId');
      snapshot.docs.forEach((doc) => print('Booking data: ${doc.id} - ${doc.data()}'));

      List<Booking> bookings = [];
      for (var doc in snapshot.docs) {
        try {
          final booking = Booking.fromFirestore(doc);
          bookings.add(booking);
        } catch (e) {
          print('Error parsing booking document ${doc.id}: $e');
        }
      }

      if (bookings.isEmpty) {
        print('No valid bookings parsed for event $eventId');
      }
      return bookings;
    } catch (e) {
      print('Error fetching bookings for event $eventId: $e');
      
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('bookings')
            .where('eventId', isEqualTo: eventId)
            .get();
            
        print('Fallback query found ${snapshot.docs.length} bookings');
        snapshot.docs.forEach((doc) => print('Fallback booking data: ${doc.id} - ${doc.data()}'));

        return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      } catch (fallbackError) {
        print('Fallback query also failed: $fallbackError');
        return [];
      }
    }
  }

  Future<Map<String, dynamic>> getOverallStats(List<dynamic> events) async {
    double totalRevenue = 0.0;
    int totalBookings = 0;
    int paidBookings = 0;

    try {
      for (var event in events) {
        List<Booking> eventBookings = await getEventBookings(event.id);
        totalBookings += eventBookings.length;
        
        final paidEventBookings = eventBookings.where((b) => b.paid).toList();
        paidBookings += paidEventBookings.length;
        
        final eventRevenue = paidEventBookings.fold(0.0, (sum, booking) => sum + booking.total);
        totalRevenue += eventRevenue;
      }
    } catch (e) {
      print('Error calculating overall stats: $e');
    }

    return {
      'revenue': totalRevenue,
      'bookings': totalBookings,
      'paidBookings': paidBookings,
    };
  }

  Future getPaidBookingsForEvent(String id) async {}
}