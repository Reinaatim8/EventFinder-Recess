import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String date;
  final String location;
  final double latitude;
  final double longitude;
  final String category;
  final String organizerId;
  final String? status;             
  final DateTime? timestamp;        
  final String? rejectionReason;   
  final DateTime? approvedAt;      
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final int? maxslots;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.organizerId,
    this.maxslots,
    this.status,
    this.timestamp,
    this.rejectionReason,
    this.approvedAt,
    this.latitude, 
    this.longitude,
    this.imageUrl,
  });

  // Deserialize from Firestore
  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: data['date'] ?? '',
      location: data['location'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      maxslots: data['maxslots'],
      category: data['category'] ?? '',
      organizerId: data['organizerId'] ?? '',
      status: data['status'],
      timestamp: data['timestamp']?.toDate(),
      rejectionReason: data['rejectionReason'],
      approvedAt: data['approvedAt']?.toDate(), 
      // latitude: null,
      //  longitude: null,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
      'price': price,
      'maxslots': maxslots,
      'category': category,
      'organizerId': organizerId,
      'status': status,
      'timestamp': timestamp,
      'rejectionReason': rejectionReason,
      'approvedAt': approvedAt,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'imageUrl': imageUrl,
      'organizerId': organizerId,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}