import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String date;
  final String location;
  final double price;
  final String category;
  final String organizerId;
  final String? status;
  final DateTime? timestamp;
  final String? rejectionReason;
  final DateTime? approvedAt;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final bool isVerified;
  final String? verificationDocumentUrl;
  final String? verificationDocumentType;
  final String? verificationStatus;
  final bool? requiresVerification;
  final String? verificationSubmittedAt;
  
  final int? maxslots;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.price,
    required this.category,
    required this.organizerId,
    this.maxslots,
    this.status = 'unverified',
    this.timestamp,
    this.rejectionReason,
    this.approvedAt,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.verificationDocumentUrl,
    this.verificationDocumentType,
    this.verificationStatus,
    this.requiresVerification,
    this.isVerified = false,
    this.verificationSubmittedAt,
  });

  // Deserialize from Firestore
  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      print('Error: DocumentSnapshot data is null for doc ID: ${doc.id}');
      return Event(
        id: doc.id,
        title: '',
        description: '',
        date: '',
        location: '',
        price: 0.0,
        category: '',
        organizerId: '',
        isVerified: false,
      );
    }

    try {
      // Validate required fields
      final title = data['title']?.toString() ?? '';
      final description = data['description']?.toString() ?? '';
      final date = data['date']?.toString() ?? '';
      final location = data['location']?.toString() ?? '';
      final category = data['category']?.toString() ?? '';
      final organizerId = data['organizerId']?.toString() ?? '';

      if (title.isEmpty || date.isEmpty || location.isEmpty || category.isEmpty || organizerId.isEmpty) {
        print('Error: Missing required fields in doc ID: ${doc.id}, data: $data');
        return Event(
          id: doc.id,
          title: '',
          description: '',
          date: '',
          location: '',
          price: 0.0,
          category: '',
          organizerId: '',
          isVerified: false,
        );
      }

      return Event(
        id: doc.id,
        title: title,
        description: description,
        date: date,
        location: location,
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        maxslots: data['maxslots'],
      category: category,
        organizerId: organizerId,
        status: data['status']?.toString() ?? 'unverified',
        timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
        rejectionReason: data['rejectionReason']?.toString(),
        approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        imageUrl: data['imageUrl']?.toString(),
        verificationDocumentUrl: data['verificationDocumentUrl']?.toString(),
        verificationDocumentType: data['verificationDocumentType']?.toString(),
        verificationStatus: data['verificationStatus']?.toString(),
        requiresVerification: data['requiresVerification'] as bool?,
        isVerified: data['isVerified'] as bool? ?? false,
        verificationSubmittedAt: data['verificationSubmittedAt']?.toString(),
      );
    } catch (e) {
      print('Error parsing Firestore document ${doc.id}: $e');
      return Event(
        id: doc.id,
        title: '',
        description: '',
        date: '',
        location: '',
        price: 0.0,
        category: '',
        organizerId: '',
        isVerified: false,
      );
    }
  }

  // Serialize to Firestore
  Map<String, dynamic> toFirestore() {
    return {
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
      'imageUrl': imageUrl,
      'verificationDocumentUrl': verificationDocumentUrl,
      'verificationDocumentType': verificationDocumentType,
      'verificationStatus': verificationStatus,
      'requiresVerification': requiresVerification,
      'isVerified': isVerified,
      'verificationSubmittedAt': verificationSubmittedAt,
    };
  }
}