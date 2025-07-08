import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _profileVisibility = true;
  bool _locationSharing = false;
  bool _activityTracking = true;
  bool _twoFactorAuth = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Settings
          _buildSectionTitle('Privacy Settings'),
          _buildPrivacyCard(
            icon: Icons.visibility,
            title: 'Profile Visibility',
            subtitle: 'Make your profile visible to other users',
            value: _profileVisibility,
            onChanged: (value) {
              setState(() {
                _profileVisibility = value;
              });
            },
          ),
          _buildPrivacyCard(
            icon: Icons.location_on,
            title: 'Location Sharing',
            subtitle: 'Share your location for event recommendations',
            value: _locationSharing,
            onChanged: (value) {
              setState(() {
                _locationSharing = value;
              });
            },
          ),
          _buildPrivacyCard(
            icon: Icons.analytics,
            title: 'Activity Tracking',
            subtitle: 'Help us improve the app with usage analytics',
            value: _activityTracking,
            onChanged: (value) {
              setState(() {
                _activityTracking = value;
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          // Security Settings
          _buildSectionTitle('Security Settings'),
          _buildSecurityOption(
            icon: Icons.lock,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          _buildPrivacyCard(
            icon: Icons.security,
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security',
            value: _twoFactorAuth,
            onChanged: (value) {
              setState(() {
                _twoFactorAuth = value;
              });
            },
          ),
          _buildSecurityOption(
            icon: Icons.devices,
            title: 'Active Sessions',
            subtitle: 'Manage your active login sessions',
            onTap: _showActiveSessionsDialog,
          ),
          
          const SizedBox(height: 20),
          
          // Data & Account
          _buildSectionTitle('Data & Account'),
          _buildSecurityOption(
            icon: Icons.download,
            title: 'Download My Data',
            subtitle: 'Download a copy of your data',
            onTap: _downloadData,
          ),
          _buildSecurityOption(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: _showDeleteAccountDialog,
            isDestructive: true,
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savePrivacySettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Settings',
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
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: SwitchListTile(
          secondary: Icon(icon, color: Theme.of(context).primaryColor),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.red : null,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('This feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showActiveSessionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Sessions'),
        content: const Text('This feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _downloadData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data download feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    // Here you would implement account deletion logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deletion feature coming soon'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _savePrivacySettings() {
    // Here you would typically save the settings to your backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}