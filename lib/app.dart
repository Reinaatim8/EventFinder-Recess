import 'package:flutter/material.dart';
import 'package:event_locator_app/screens/auth/auth_wrapper.dart';
import 'package:event_locator_app/core/theme/app_theme.dart';

class LocalEventFinderApp extends StatelessWidget {
  const LocalEventFinderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Event Finder',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}