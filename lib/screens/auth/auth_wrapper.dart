import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/home/home_screen.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'Event Finder',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print('AuthWrapper - Status: ${authProvider.status}, Loading: ${authProvider.isLoading}');
        
        // Show loading screen while checking authentication or during operations
        if (authProvider.isLoading || authProvider.status == AuthStatus.uninitialized) {
          return const LoadingScreen();
        }

        // Show home screen if user is authenticated
        if (authProvider.status == AuthStatus.authenticated && authProvider.user != null) {
          return const HomeScreen();
        }

        // Show login screen if user is not authenticated
        return const LoginScreen();
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 25, 25, 95),
              Color.fromARGB(255, 50, 50, 120),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo or Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: Colors.orange,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.event,
                size: 60,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 30),
            
            // App Name
            const Text(
              'Event Finder',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            
            // Tagline
            const Text(
              'Discover Amazing Events',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 50),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            
            // Loading Text
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                String loadingText = 'Loading...';
                
                switch (authProvider.status) {
                  case AuthStatus.uninitialized:
                    loadingText = 'Initializing...';
                    break;
                  case AuthStatus.loading:
                    loadingText = 'Processing...';
                    break;
                  default:
                    loadingText = 'Loading...';
                }
                
                return Text(
                  loadingText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}