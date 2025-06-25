import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  void _initializeAuth() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      print('Auth state changed: ${firebaseUser?.uid ?? 'null'}');
      
      if (firebaseUser != null) {
        try {
          _user = await _databaseService.getUserData(firebaseUser.uid);
          _status = AuthStatus.authenticated;
          print('User authenticated successfully');
          
          // Stop loading if we were in a loading state
          if (_isLoading) {
            _isLoading = false;
          }
        } catch (e) {
          print('Error getting user data: $e');
          _status = AuthStatus.unauthenticated;
          _user = null;
          
          // Stop loading if we were in a loading state
          if (_isLoading) {
            _isLoading = false;
          }
        }
      } else {
        _status = AuthStatus.unauthenticated;
        _user = null;
        print('User unauthenticated');
        
        // Stop loading if we were in a loading state
        if (_isLoading) {
          _isLoading = false;
        }
      }
      notifyListeners();
    });
  }

  void _setLoading(bool loading) {
    print('Setting loading: $loading');
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    print('Setting error: $error');
    _errorMessage = error;
    if (error != null) {
      Fluttertoast.showToast(msg: error, toastLength: Toast.LENGTH_LONG);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // IMPROVED SIGN UP METHOD
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    print('Starting signUp for email: $email');
    _setLoading(true);
    _setError(null);

    try {
      print('Calling AuthService.signUpWithEmailAndPassword...');
      
      UserModel? user = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      print('AuthService returned: ${user != null ? 'User object' : 'null'}');

      if (user != null) {
        // Don't set the user and status here - let the auth state listener handle it
        print('Sign up successful, showing toast');
        Fluttertoast.showToast(
          msg: "Account created successfully! Please verify your email.",
          toastLength: Toast.LENGTH_LONG,
        );

        // The auth state listener will handle setting _isLoading to false
        return true;
      } else {
        print('Sign up failed - AuthService returned null');
        _setError("Account creation failed. Please try again.");
        _setLoading(false);
        return false;
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during signUp: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'The account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message ?? 'Unknown error'}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      print('Unexpected error during signUp: $e');
      _setError("An unexpected error occurred during sign up: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  // IMPROVED SIGN IN METHOD
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    print('Starting signIn for email: $email');
    _setLoading(true);
    _setError(null);

    try {
      print('Calling AuthService.signInWithEmailAndPassword...');
      
      UserModel? user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('AuthService returned: ${user != null ? 'User object' : 'null'}');

      if (user != null) {
        // Don't set the user and status here - let the auth state listener handle it
        Fluttertoast.showToast(
          msg: "Welcome back!",
          toastLength: Toast.LENGTH_SHORT,
        );

        // The auth state listener will handle setting _isLoading to false
        return true;
      } else {
        _setError("Failed to sign in. Check your credentials.");
        _setLoading(false);
        return false;
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during signIn: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = 'Sign in failed: ${e.message ?? 'Unknown error'}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      print('Unexpected error during signIn: $e');
      _setError("An unexpected error occurred during sign in: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    print('Starting password reset for email: $email');
    _setLoading(true);
    _setError(null);

    try {
      bool success = await _authService.resetPassword(email: email);
      _setLoading(false);

      if (success) {
        Fluttertoast.showToast(
          msg: "Reset email sent. Check your inbox.",
          toastLength: Toast.LENGTH_LONG,
        );
        return true;
      } else {
        _setError("Failed to send reset email.");
        return false;
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during password reset: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Password reset failed: ${e.message ?? 'Unknown error'}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      print('Unexpected error during password reset: $e');
      _setError("Unexpected error during password reset: ${e.toString()}");
      _setLoading(false);
      return false;
    } finally {
      if (_isLoading) {
        _setLoading(false);
      }
    }
  }

  Future<void> signOut() async {
    print('Starting sign out');
    _setLoading(true);
    
    try {
      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;

      Fluttertoast.showToast(msg: "Signed out.", toastLength: Toast.LENGTH_SHORT);
      print('Sign out successful');
    } catch (e) {
      print('Error during sign out: $e');
      _setError("Failed to sign out: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendEmailVerification() async {
    print('Sending email verification');
    
    try {
      await _authService.sendEmailVerification();
      Fluttertoast.showToast(
        msg: "Verification email sent.",
        toastLength: Toast.LENGTH_SHORT,
      );
      print('Email verification sent successfully');
    } catch (e) {
      print('Error sending email verification: $e');
      _setError("Failed to send verification email: ${e.toString()}");
    }
  }

  Future<void> checkEmailVerification() async {
    print('Checking email verification');
    
    try {
      await _authService.reloadUser();
      print('User reloaded successfully');
    } catch (e) {
      print('Error reloading user: $e');
      _setError("Failed to refresh email verification: ${e.toString()}");
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_user == null) {
      print('Cannot update profile - no user logged in');
      return false;
    }

    print('Updating user profile for: ${_user!.uid}');
    _setLoading(true);
    _setError(null);

    try {
      Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (additionalData != null) updateData.addAll(additionalData);

      print('Update data: $updateData');

      await _databaseService.updateUserData(_user!.uid, updateData);

      if (name != null) _user = _user!.copyWith(name: name);

      notifyListeners();
      _setLoading(false);

      Fluttertoast.showToast(msg: "Profile updated successfully.");
      print('Profile updated successfully');
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      _setError("Failed to update profile: ${e.toString()}");
      _setLoading(false);
      return false;
    } finally {
      if (_isLoading) {
        _setLoading(false);
      }
    }
  }

  Future<void> refreshUserData() async {
    if (_user == null) {
      print('Cannot refresh user data - no user logged in');
      return;
    }

    print('Refreshing user data for: ${_user!.uid}');

    try {
      UserModel? updatedUser = await _databaseService.getUserData(_user!.uid);
      if (updatedUser != null) {
        _user = updatedUser;
        notifyListeners();
        print('User data refreshed successfully');
      } else {
        print('Failed to get updated user data');
      }
    } catch (e) {
      print('Error refreshing user data: $e');
      _setError("Failed to refresh user data: ${e.toString()}");
    }
  }

  Future<bool> deleteAccount() async {
    if (_user == null) {
      print('Cannot delete account - no user logged in');
      return false;
    }

    print('Deleting account for: ${_user!.uid}');
    _setLoading(true);
    _setError(null);

    try {
      // First delete user document from database
      await _databaseService.deleteUserDocument(_user!.uid);
      print('User document deleted from database');

      // Then delete the Firebase Auth user
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        print('Firebase Auth user deleted');
      }

      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);

      Fluttertoast.showToast(msg: "Account deleted successfully.");
      print('Account deleted successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during account deletion: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage = 'Please sign in again before deleting your account.';
          break;
        default:
          errorMessage = 'Failed to delete account: ${e.message ?? 'Unknown error'}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      print('Unexpected error during account deletion: $e');
      _setError("Failed to delete account: ${e.toString()}");
      _setLoading(false);
      return false;
    } finally {
      if (_isLoading) {
        _setLoading(false);
      }
    }
  }

  // Additional helper method to manually refresh auth state
  Future<void> refreshAuthState() async {
    print('Manually refreshing auth state');
    
    try {
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        // The auth state listener will handle the rest
      }
    } catch (e) {
      print('Error refreshing auth state: $e');
    }
  }

  // Method to check if user email is verified
  bool get isEmailVerified {
    User? currentUser = _authService.currentUser;
    return currentUser?.emailVerified ?? false;
  }

  // Method to get current Firebase user
  User? get currentFirebaseUser => _authService.currentUser;
}