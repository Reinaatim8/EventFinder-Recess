import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as custom_auth;
import '../../models/event.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = true;
  List<Event> events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      print('Fetching events for AdminScreen...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('title', isNotEqualTo: '')
          .get();
      print('Retrieved ${snapshot.docs.length} documents');
      List<Event> fetchedEvents = snapshot.docs.map((doc) {
        print('Event ID: ${doc.id}, Data: ${doc.data()}');
        return Event.fromFirestore(doc);
      }).toList();
      setState(() {
        events = fetchedEvents;
        _isLoading = false;
      });
      print('Fetched ${events.length} events');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching events: $e');
      Fluttertoast.showToast(
        msg: "Error loading events",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  bool _isAdmin() {
    final authProvider = Provider.of<custom_auth.AuthProvider>(
      context,
      listen: false,
    );
    final isAdmin =
        authProvider.user?.email == 'kennedymutebi7@gmail.com' ?? false;
    print(
      'Checking admin status: user=${authProvider.user?.email}, isAdmin=$isAdmin',
    );
    return isAdmin;
  }

  Future<void> _approveEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .update({
            'isVerified': true,
            'verificationStatus': 'approved',
            'status': 'approved', // For backward compatibility
            'approvedAt': FieldValue.serverTimestamp(),
            'rejectionReason': null,
          });
      print('Approved event: ${event.id}, title: ${event.title}');
      Fluttertoast.showToast(
        msg: "Event Approved!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      _fetchEvents(); // Refresh event list
    } catch (e) {
      print('Error approving event: ${event.id}, error: $e');
      Fluttertoast.showToast(
        msg: "Error approving event",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _rejectEvent(Event event, String reason) async {
    if (reason.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please provide a rejection reason",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .update({
            'isVerified': false,
            'verificationStatus': 'rejected',
            'status': null, // Clear status for consistency
            'rejectionReason': reason,
            'rejectedAt': FieldValue.serverTimestamp(),
          });
      print(
        'Rejected event: ${event.id}, title: ${event.title}, reason: $reason',
      );
      Fluttertoast.showToast(
        msg: "Event Rejected!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      _fetchEvents(); // Refresh event list
    } catch (e) {
      print('Error rejecting event: ${event.id}, error: $e');
      Fluttertoast.showToast(
        msg: "Error rejecting event",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin()) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Admin Only',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Event Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
          ? const Center(
              child: Text(
                'No events found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Event Title')),
                  DataColumn(label: Text('Verification Status')),
                  DataColumn(label: Text('Document')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: events.map((event) {
                  final isVerified =
                      event.isVerified ||
                      event.verificationStatus == 'approved';
                  return DataRow(
                    cells: [
                      DataCell(Text(event.title)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? Colors.green
                                : (event.verificationStatus == 'pending'
                                      ? Colors.orange
                                      : Colors.red),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified
                                ? 'Verified'
                                : (event.verificationStatus == 'pending'
                                      ? 'Pending'
                                      : 'Unverified'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      DataCell(
                        event.verificationDocumentUrl != null &&
                                event.verificationDocumentUrl!.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  // Implement URL opening logic (e.g., launch URL in browser)
                                  print(
                                    'Opening document: ${event.verificationDocumentUrl}',
                                  );
                                  Fluttertoast.showToast(
                                    msg:
                                        "Document URL: ${event.verificationDocumentUrl}",
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.CENTER,
                                  );
                                },
                                child: const Text(
                                  'View Document',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              )
                            : const Text('No Document'),
                      ),
                      DataCell(
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _approveEvent(event),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'Approve',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final controller = TextEditingController();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Reject Event'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        labelText: 'Rejection Reason',
                                        hintText: 'Enter reason for rejection',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _rejectEvent(
                                            event,
                                            controller.text.trim(),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
