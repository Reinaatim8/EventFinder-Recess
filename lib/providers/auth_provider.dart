// providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize authentication state
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // User is signed in
        try {
          _user = await _databaseService.getUserData(firebaseUser.uid);
          _status = AuthStatus.authenticated;
        } catch (e) {
          _status = AuthStatus.unauthenticated;
          _user = null;
        }
      } else {
        // User is signed out
        _status = AuthStatus.unauthenticated;
        _user = null;
      }
      notifyListeners();
    });
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      UserModel? user = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to create account. Please try again.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred during sign up.');
      _setLoading(false);
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      UserModel? user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to sign in. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred during sign in.');
      _setLoading(false);
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword({required String email}) async {
    _setLoading(true);
    _setError(null);

    try {
      bool success = await _authService.resetPassword(email: email);
      _setLoading(false);
      
      if (!success) {
        _setError('Failed to send password reset email.');
      }
      
      return success;
    } catch (e) {
      _setError('An unexpected error occurred while resetting password.');
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _setError('Error signing out. Please try again.');
    }
    
    _setLoading(false);
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      _setError('Failed to send verification email.');
    }
  }

  // Check email verification status
  Future<void> checkEmailVerification() async {
    try {
      await _authService.reloadUser();
      // The auth state listener will handle the update
    } catch (e) {
      _setError('Failed to check email verification status.');
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      Map<String, dynamic> updateData = {};
      
      if (name != null) {
        updateData['name'] = name;
      }
      
      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _databaseService.updateUserData(_user!.uid, updateData);
      
      // Update local user model
      if (name != null) {
        _user = _user!.copyWith(name: name);
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_user == null) return;

    try {
      UserModel? updatedUser = await _databaseService.getUserData(_user!.uid);
      if (updatedUser != null) {
        _user = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to refresh user data.');
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    if (_user == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      // Delete user document from Firestore
      await _databaseService.deleteUserDocument(_user!.uid);
      
      // Delete Firebase Auth user
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }

      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete account. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}