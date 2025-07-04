
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('Signing up with email: $email');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        print('Firebase user created: ${user.uid}');
        await user.updateDisplayName(name);

        UserModel userModel = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          emailVerified: user.emailVerified,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        print('Creating user document with UID: ${userModel.uid}');
        await _databaseService.createUserDocument(userModel);
        await user.sendEmailVerification();

        Fluttertoast.showToast(
          msg: "Account created successfully! Please check your email for verification.",
          toastLength: Toast.LENGTH_LONG,
        );

        return userModel;
      }
      print('Sign up failed: No Firebase user created');
      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      _handleAuthException(e);
      return null;
    } catch (e, stackTrace) {
      print('Unexpected error during sign up: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "An unexpected error occurred: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
      return null;
    }
  }

  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('Signing in with email: $email');
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        print('Firebase user signed in: ${user.uid}');
        UserModel? userModel;
        try {
          await _databaseService.updateLastLoginTime(user.uid);
          userModel = await _databaseService.getUserData(user.uid);
        } catch (e, stackTrace) {
          print('Error fetching user data: $e\n$stackTrace');
          userModel = null;
        }

        if (userModel == null) {
          print('No user document found, creating default UserModel for UID: ${user.uid}');
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? email,
            name: user.displayName ?? 'User',
            emailVerified: user.emailVerified,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          await _databaseService.createUserDocument(userModel);
        }

        print('Sign in successful, UserModel UID: ${userModel.uid}');
        Fluttertoast.showToast(
          msg: "Welcome back!",
          toastLength: Toast.LENGTH_SHORT,
        );
        return userModel;
      }
      print('Sign in failed: No Firebase user');
      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during sign in: ${e.code} - ${e.message}');
      _handleAuthException(e);
      return null;
    } catch (e, stackTrace) {
      print('Unexpected error during sign in: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "An unexpected error occurred: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
      return null;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      print('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      Fluttertoast.showToast(
        msg: "Password reset email sent. Please check your inbox.",
        toastLength: Toast.LENGTH_LONG,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during password reset: ${e.code} - ${e.message}');
      _handleAuthException(e);
      return false;
    } catch (e, stackTrace) {
      print('Unexpected error during password reset: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "An unexpected error occurred: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      print('Signing out');
      await _auth.signOut();
      Fluttertoast.showToast(
        msg: "Signed out successfully",
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e, stackTrace) {
      print('Error signing out: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "Error signing out: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        print('Sending email verification to: ${user.email}');
        await user.sendEmailVerification();
        Fluttertoast.showToast(
          msg: "Verification email sent",
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        print('No user or email already verified');
      }
    } catch (e, stackTrace) {
      print('Error sending verification email: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "Error sending verification email: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> reloadUser() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('Reloading user: ${user.uid}');
        await user.reload();
        print('User reloaded successfully');
      }
    } catch (e, stackTrace) {
      print('Error reloading user: $e\n$stackTrace');
      Fluttertoast.showToast(
        msg: "Error reloading user: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  void _handleAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled.';
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'user-not-found':
        message = 'No user found with this email address.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'invalid-credential':
        message = 'Invalid credentials. Please try again.';
        break;
      case 'too-many-requests':
        message = 'Too many failed attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
    );
  }
}
