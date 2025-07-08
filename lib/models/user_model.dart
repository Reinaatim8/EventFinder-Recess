class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final String? bio;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.profileImageUrl,
    this.emailVerified = false,
    this.createdAt,
    this.lastLoginAt,
    this.bio,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      profileImageUrl: map['profileImageUrl'],
      emailVerified: map['emailVerified'] ?? false,
      createdAt: map['createdAt']?.toDate(),
      lastLoginAt: map['lastLoginAt']?.toDate(),
      bio: map['bio'], // Fixed: Changed 'json' to 'map'
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'emailVerified': emailVerified,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'bio': bio,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? bio, // Added bio parameter
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      bio: bio ?? this.bio, // Added bio handling
    );
  }
}