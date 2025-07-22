import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('User Profile'),
        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
        toolbarHeight: 60,
       title: Row(
    mainAxisAlignment: MainAxisAlignment.start, // Aligns to the left
    children: const [
      Icon(Icons.person, color: Colors.orange), // Profile icon
      SizedBox(width: 30), // Space between icon and text
      Text(
        'User Profile',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
      
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 25, 25, 95),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color.fromARGB(255, 25, 25, 95),
                        child: Text(
                          user?.name.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Profile Options
                _buildProfileOption(
                  context,
                  icon: Icons.edit,
                  title: 'Edit Profile',
                  onTap: () {
                    // TODO: Navigate to edit profile screen
                  },
                ),
                _buildProfileOption(
                  context,
                  icon: Icons.notifications,
                  title: 'Notifications',
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                _buildProfileOption(
                  context,
                  icon: Icons.help,
                  title: 'Help & Support',
                  onTap: () {
                    // TODO: Navigate to help screen
                  },
                ),
                _buildProfileOption(
                  context,
                  icon: Icons.info,
                  title: 'About',
                  onTap: () {
                    // TODO: Navigate to about screen
                  },
                ),
                const SizedBox(height: 20),
                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            await authProvider.signOut();
                            // Show toast message
                        Fluttertoast.showToast(
                          msg: "Successfully logged out! Sign in again to continue.",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          fontSize: 16.0,);

                          // Navigate to login and clear navigation stack
                        Navigator.of(context).pushNamedAndRemoveUntil('_handleLogin', (route) => false);

                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color:Colors.orange,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: Colors.grey[100],
      ),
    );
  }
}