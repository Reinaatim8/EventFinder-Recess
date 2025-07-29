
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() async {
    print('Initializing AuthProvider');
    User? firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      await _updateUserState(firebaseUser);
    } else {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _isLoading = false;
      print('No current user, setting unauthenticated');
      notifyListeners();
    }

    _authService.authStateChanges.listen(
      (User? firebaseUser) async {
        print('Auth state changed: ${firebaseUser?.uid ?? 'null'}');
        await _updateUserState(firebaseUser);
        notifyListeners();
      },
      onError: (error, stackTrace) {
        print('Stream error in authStateChanges: $error\n$stackTrace');
        _status = AuthStatus.unauthenticated;
        _user = null;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _updateUserState(User? firebaseUser) async {
    if (firebaseUser != null) {
      try {
        _status = AuthStatus.authenticated;
        _user = await _databaseService.getUserData(firebaseUser.uid);
        if (_user == null) {
          print(
            'No user data found, creating default UserModel for UID: ${firebaseUser.uid}',
          );
          _user = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ?? 'User',
            emailVerified: firebaseUser.emailVerified,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            phoneNumber: null,
            twoFactorEnabled: false,
          );
          await _databaseService.updateUserData(
            firebaseUser.uid,
            _user!.toMap(),
          );
        }
        print('User authenticated: ${_user?.uid}');
      } catch (e, stackTrace) {
        print('Error updating user state: $e\n$stackTrace');
        _status = AuthStatus.unauthenticated;
        _user = null;
      }
    } else {
      _status = AuthStatus.unauthenticated;
      _user = null;
      print('User unauthenticated');
    }
    _isLoading = false;
    notifyListeners();
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

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (!email.contains('@')) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters long';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Password must contain at least one uppercase letter';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Password must contain at least one lowercase letter';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Password must contain at least one number';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      return 'Password must contain at least one special character';
    List<String> commonPasswords = [
      'password',
      '12345678',
      'qwerty123',
      'abc123456',
      'password123',
      '123456789',
      'welcome123',
      'admin123',
    ];
    if (commonPasswords.contains(password.toLowerCase()))
      return 'Password is too common';
    if (_hasSequentialChars(password))
      return 'Password should not contain sequential characters';
    return null;
  }

  bool _hasSequentialChars(String password) {
    String lowerPassword = password.toLowerCase();
    for (int i = 0; i < lowerPassword.length - 2; i++) {
      String substr = lowerPassword.substring(i, i + 3);
      if (substr == '123' ||
          substr == '234' ||
          substr == '345' ||
          substr == '456' ||
          substr == '567' ||
          substr == '678' ||
          substr == '789' ||
          substr == '890') {
        return true;
      }
      if (substr == 'abc' ||
          substr == 'bcd' ||
          substr == 'cde' ||
          substr == 'def' ||
          substr == 'efg' ||
          substr == 'fgh' ||
          substr == 'ghi' ||
          substr == 'hij' ||
          substr == 'ijk' ||
          substr == 'jkl' ||
          substr == 'klm' ||
          substr == 'lmn' ||
          substr == 'mno' ||
          substr == 'nop' ||
          substr == 'opq' ||
          substr == 'pqr' ||
          substr == 'qrs' ||
          substr == 'rst' ||
          substr == 'stu' ||
          substr == 'tuv' ||
          substr == 'uvw' ||
          substr == 'vwx' ||
          substr == 'wxy' ||
          substr == 'xyz') {
        return true;
      }
    }
    return false;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    print('Starting signUp for email: $email');
    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address with @ symbol');
      return false;
    }
    String? passwordError = _validatePassword(password);
    if (passwordError != null) {
      _setError(passwordError);
      return false;
    }
    if (name.trim().isEmpty) {
      _setError('Please enter your full name');
      return false;
    }
    if (name.trim().length < 2) {
      _setError('Name must be at least 2 characters long');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      UserModel? user = await _authService.signUpWithEmailAndPassword(
        email: email.trim(),
        password: password,
        name: name.trim(),
      );
      print('AuthService.signUp returned: ${user != null ? 'UserModel (UID: ${user.uid})' : 'null'}');
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        Fluttertoast.showToast(
          msg: "Account created successfully! Please verify your email.",
          toastLength: Toast.LENGTH_LONG,
        );
        _setLoading(false);
        return true;
      }
      _setError("Account creation failed. Please try again.");
      _setLoading(false);
      return false;
    } catch (e, stackTrace) {
      print('Error during signUp: $e\n$stackTrace');
      _setError("Registration failed: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    print('Starting signIn for email: $email');
    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address with @ symbol');
      return false;
    }
    if (password.isEmpty) {
      _setError('Please enter a password');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      UserModel? user = await _authService.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('AuthService.signIn returned: ${user != null ? 'UserModel (UID: ${user.uid})' : 'null'}');
      if (user != null && user.uid.isNotEmpty) {
        _user = user;
        _status = AuthStatus.authenticated;
        User? firebaseUser = _authService.currentUser;
        if (firebaseUser != null && user.uid != firebaseUser.uid) {
          print('Mismatch in UIDs, updating from Firebase: ${firebaseUser.uid}');
          _user = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? email,
            name: firebaseUser.displayName ?? 'User',
            emailVerified: firebaseUser.emailVerified,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            phoneNumber: null,
            twoFactorEnabled: false,
          );
          await _databaseService.updateUserData(firebaseUser.uid, _user!.toMap());
        }
        Fluttertoast.showToast(
          msg: "Welcome back!",
          toastLength: Toast.LENGTH_SHORT,
        );
        _setLoading(false);
        return true;
      }
      print('Sign in failed: Invalid UserModel or empty UID');
      _setError("Failed to sign in. Check your credentials.");
      _setLoading(false);
      return false;
    } catch (e, stackTrace) {
      print('Error during signIn: $e\n$stackTrace');
      _setError("Sign in failed: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    print('Starting sign out');
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      Fluttertoast.showToast(
        msg: "Signed out.",
        toastLength: Toast.LENGTH_SHORT,
      );
      print('Sign out successful');
    } catch (e, stackTrace) {
      print('Error during sign out: $e\n$stackTrace');
      _setError("Failed to sign out: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword({required String email}) async {
    print('Starting password reset for email: $email');
    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address with @ symbol');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      bool success = await _authService.resetPassword(email: email.trim());
      _setLoading(false);
      if (success) {
        Fluttertoast.showToast(
          msg: "Reset email sent. Check your inbox.",
          toastLength: Toast.LENGTH_LONG,
        );
        return true;
      }
      _setError("Failed to send reset email.");
      return false;
    } catch (e, stackTrace) {
      print('Error during password reset: $e\n$stackTrace');
      _setError("Password reset failed: ${e.toString()}");
      _setLoading(false);
      return false;
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
    } catch (e, stackTrace) {
      print('Error sending verification email: $e\n$stackTrace');
      _setError("Failed to send verification email: ${e.toString()}");
    }
  }

  Future<void> checkEmailVerification() async {
    print('Checking email verification');
    try {
      await _authService.reloadUser();
      print('User reloaded successfully');
      if (_authService.currentUser != null) {
        _user = await _databaseService.getUserData(_authService.currentUser!.uid);
        notifyListeners();
      }
    } catch (e, stackTrace) {
      print('Error reloading user: $e\n$stackTrace');
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
      if (additionalData != null) {
        _user = _user!.copyWith(
          phoneNumber: additionalData['phoneNumber'],
          twoFactorEnabled: additionalData['twoFactorEnabled'],
        );
      }
      notifyListeners();
      _setLoading(false);
      Fluttertoast.showToast(msg: "Profile updated successfully.");
      print('Profile updated successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error updating profile: $e\n$stackTrace');
      _setError("Failed to update profile: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<bool> toggleTwoFactorAuth(bool enable) async {
    if (_user == null) {
      print('Cannot toggle 2FA - no user logged in');
      _setError('No user is signed in');
      return false;
    }
    print('Toggling 2FA for user: ${_user!.uid}, enable: $enable');
    _setLoading(true);
    _setError(null);
    try {
      await _databaseService.updateUserData(_user!.uid, {
        'twoFactorEnabled': enable,
      });
      _user = _user!.copyWith(twoFactorEnabled: enable);
      notifyListeners();
      _setLoading(false);
      Fluttertoast.showToast(
        msg: 'Two-factor authentication ${enable ? 'enabled' : 'disabled'}',
        toastLength: Toast.LENGTH_SHORT,
      );
      return true;
    } catch (e, stackTrace) {
      print('Error toggling 2FA: $e\n$stackTrace');
      _setError('Failed to toggle 2FA: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    print('Starting password change');
    _setLoading(true);
    _setError(null);
    try {
      String? passwordError = _validatePassword(newPassword);
      if (passwordError != null) {
        _setError(passwordError);
        _setLoading(false);
        return false;
      }
      bool success = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      if (success) {
        Fluttertoast.showToast(
          msg: 'Password changed successfully',
          toastLength: Toast.LENGTH_SHORT,
        );
        return true;
      } else {
        _setError('Failed to change password');
        return false;
      }
    } catch (e, stackTrace) {
      print('Error during password change: $e\n$stackTrace');
      _setError('Failed to change password: ${e.toString()}');
      _setLoading(false);
      return false;
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
        print('User data refreshed successfully: ${_user!.toMap()}');
      } else {
        print('Failed to get updated user data');
      }
    } catch (e, stackTrace) {
      print('Error refreshing user data: $e\n$stackTrace');
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
      await _databaseService.deleteUserDocument(_user!.uid);
      print('User document deleted from database');
      if (_authService.currentUser != null) {
        await _authService.currentUser!.delete();
        print('Firebase Auth user deleted');
      }
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      Fluttertoast.showToast(msg: "Account deleted successfully.");
      print('Account deleted successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error during account deletion: $e\n$stackTrace');
      _setError("Failed to delete account: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<void> refreshAuthState() async {
    print('Manually refreshing auth state');
    try {
      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        await _updateUserState(currentUser);
        print('Auth state refreshed successfully: ${currentUser.uid}');
      } else {
        _status = AuthStatus.unauthenticated;
        _user = null;
        print('No current user during refresh');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      print('Error refreshing auth state: $e\n$stackTrace');
      _setError("Failed to refresh auth state: ${e.toString()}");
    }
  }

  bool get isEmailVerified => _authService.currentUser?.emailVerified ?? false;

  User? get currentFirebaseUser => _authService.currentUser;
}
