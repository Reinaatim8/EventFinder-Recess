import 'package:event_locator_app/models/event.dart' as home_screen;
import 'package:event_locator_app/screens/home/event_management_screen.dart' as home_screen;
import 'package:flutter/material.dart';
import 'package:event_locator_app/screens/auth/auth_wrapper.dart';
import 'package:event_locator_app/core/theme/app_theme.dart';
import 'package:event_locator_app/screens/auth/splash_screen.dart';
import 'package:event_locator_app/screens/auth/login_screen.dart';
import 'package:event_locator_app/screens/home/event_details_screen.dart';

class LocalEventFinderApp extends StatelessWidget {
  const LocalEventFinderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Event Finder',
      theme: AppTheme.lightTheme,
      //darkTheme: AppTheme.darkTheme,
      
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      //home: const AuthWrapper(),
      // routes: {
      //   '/login': (context) => const LoginScreen(), // Register the login route
      //   // Add other named routes if needed
      // },
    );
  }
}
