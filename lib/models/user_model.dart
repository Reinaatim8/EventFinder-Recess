
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String? phoneNumber;
  final bool twoFactorEnabled;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.emailVerified,
    required this.createdAt,
    required this.lastLoginAt,
    this.phoneNumber,
    this.twoFactorEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'emailVerified': emailVerified,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt.millisecondsSinceEpoch,
      'phoneNumber': phoneNumber,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? 'User',
      emailVerified: map['emailVerified'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      lastLoginAt: _parseDate(map['lastLoginAt']) ?? DateTime.now(),
      phoneNumber: map['phoneNumber']?.toString(),
      twoFactorEnabled: map['twoFactorEnabled'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Failed to parse date string: $value');
        return null;
      }
    }
    return null;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? phoneNumber,
    bool? twoFactorEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    );
  }
}
