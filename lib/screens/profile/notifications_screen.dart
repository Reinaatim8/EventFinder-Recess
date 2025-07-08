import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;
  bool _eventReminders = true;
  bool _newEvents = true;
  bool _eventUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Notifications
          _buildSectionTitle('General Notifications'),
          _buildNotificationCard(
            title: 'Push Notifications',
            subtitle: 'Receive notifications on your device',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),
          _buildNotificationCard(
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),
          _buildNotificationCard(
            title: 'SMS Notifications',
            subtitle: 'Receive notifications via SMS',
            value: _smsNotifications,
            onChanged: (value) {
              setState(() {
                _smsNotifications = value;
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          // Event Notifications
          _buildSectionTitle('Event Notifications'),
          _buildNotificationCard(
            title: 'Event Reminders',
            subtitle: 'Get reminded about upcoming events',
            value: _eventReminders,
            onChanged: (value) {
              setState(() {
                _eventReminders = value;
              });
            },
          ),
          _buildNotificationCard(
            title: 'New Events',
            subtitle: 'Notifications about new events in your area',
            value: _newEvents,
            onChanged: (value) {
              setState(() {
                _newEvents = value;
              });
            },
          ),
          _buildNotificationCard(
            title: 'Event Updates',
            subtitle: 'Get notified when events are updated',
            value: _eventUpdates,
            onChanged: (value) {
              setState(() {
                _eventUpdates = value;
              });
            },
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveNotificationSettings,
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

  Widget _buildNotificationCard({
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

  void _saveNotificationSettings() {
    // Here you would typically save the settings to your backend or local storage
    // For now, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}