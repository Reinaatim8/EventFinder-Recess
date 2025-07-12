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
  final String? imageUrl;
  final String organizerId;
  final double price;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.imageUrl,
    required this.organizerId,
    required this.price,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: data['date'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'Other',
      imageUrl: data['imageUrl'],
      organizerId: data['organizerId'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }

  get rejectionReason => null;

  get status => null;

  get approvedAt => null;

  get timestamp => null;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
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