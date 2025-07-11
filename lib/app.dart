import 'package:flutter/material.dart';
import 'package:event_locator_app/screens/auth/auth_wrapper.dart';
import 'package:event_locator_app/core/theme/app_theme.dart';
import 'package:event_locator_app/screens/home/home_screen.dart';
import 'package:event_locator_app/screens/auth/login_screen.dart';
import 'package:event_locator_app/screens/profile/profile_screen.dart'; // Adjust path
import 'package:event_locator_app/screens/profile/edit_profile_screen.dart'; // Placeholder
import 'package:event_locator_app/screens/profile/notifications_screen.dart'; // Placeholder
import 'package:event_locator_app/screens/profile/privacy_security_screen.dart'; // Placeholder
import 'package:event_locator_app/screens/home/event_management_screen.dart'; // Adjust path
import 'package:event_locator_app/screens/auth/splash_screen.dart'; // Direct import (placeholder or actual)
import 'package:event_locator_app/screens/home/addingevent.dart'; // Direct import (placeholder or actual)
import 'package:event_locator_app/screens/home/home_screen.dart' as home_screen;
import 'package:event_locator_app/screens/home/event_details_screen.dart';

class LocalEventFinderApp extends StatelessWidget {
  const LocalEventFinderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Event Finder',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      //home: const AuthWrapper(),
     // home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit-profile': (context) => EditProfileScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/privacy-security': (context) => PrivacySecurityScreen(),
        '/help': (context) => HelpScreen(),
        '/about': (context) => AboutScreen(),
        '/bookevent': (context) => BookEventScreen(),
        '/event-management': (context) => EventManagementScreen(),
        '/addingevent': (context) => AddingEvent(),
        '/search': (context) => SearchScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Route not found: ${settings.name}'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Placeholder screens with debug prints
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Edit Profile Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: const Center(child: Text('Edit Profile Screen')),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Notifications Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Notifications Screen')),
    );
  }
}

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Privacy & Security Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: const Center(child: Text('Privacy & Security Screen')),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Help & Support Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: const Center(child: Text('Help & Support Screen')),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('About Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(child: Text('About Screen')),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final events = args?['events'] as List<home_screen.Event>? ?? [];
    final category = args?['category'] as String? ?? 'All';
    print('Search Screen built with ${events.length} events, category: $category');
    return Scaffold(
      appBar: AppBar(title: const Text('Search Events')),
      body: Center(child: Text('Search Screen with ${events.length} events, category: $category')),
    );
  }
}

class BookEventScreen extends StatelessWidget {
  const BookEventScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Book Event Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Book Event')),
      body: const Center(child: Text('Book Event Screen')),
    );
  }
}

class AddingEvent extends StatelessWidget {
  const AddingEvent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Add Event Screen built');
    return Scaffold(
      appBar: AppBar(title: const Text('Add Event')),
      body: const Center(child: Text('Add Event Screen')),
    );
  }
}