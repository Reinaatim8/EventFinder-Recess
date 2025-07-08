import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../models/user_model.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image to Firebase Storage
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      // Create a unique filename
      String fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      // Reference to the file location in Firebase Storage
      Reference ref = _storage.ref().child('profile_images').child(fileName);
      
      // Upload the file
      UploadTask uploadTask = ref.putFile(imageFile);
      
      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;
      
      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Update user profile in Firestore
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Get user profile from Firestore
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Create user profile in Firestore
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Delete profile image from Firebase Storage
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete profile image: $e');
    }
  }

  // Stream user profile changes
  Stream<UserModel?> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}