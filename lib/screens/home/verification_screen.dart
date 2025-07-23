import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'checkout_screen.dart';
import '../../models/event.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as custom_auth;

class VerificationScreen extends StatefulWidget {
  final Event event;
  final Function(Map<String, dynamic>) onBookingAdded;
  final Function(String) onStatusUpdate;
  final bool isVerified;
  final String? verificationDocumentUrl;
  final String? verificationStatus;
  final String? rejectionReason;
  final String? verificationDocumentType;

  const VerificationScreen({
    Key? key,
    required this.event,
    required this.onBookingAdded,
    required this.onStatusUpdate,
    required this.isVerified,
    this.verificationDocumentUrl,
    this.verificationStatus,
    this.rejectionReason,
    this.verificationDocumentType,
  }) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late String ticketId;
  late bool currentVerificationStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    ticketId = const Uuid().v4();
    currentVerificationStatus = widget.isVerified;

    print('VerificationScreen initialized:');
    print('  - eventTitle: ${widget.event.title}');
    print('  - isVerified: ${widget.isVerified}');
    print('  - verificationDocumentUrl: ${widget.verificationDocumentUrl}');
    print('  - verificationStatus: ${widget.verificationStatus}');
    print('  - verificationDocumentType: ${widget.verificationDocumentType}');
    print('  - currentVerificationStatus: $currentVerificationStatus');
  }

  bool _isAdmin(BuildContext context) {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context, listen: false);
    final isAdmin = authProvider.user?.email == 'kennedymutebi7@gmail.com' ?? false;
    print('Checking admin status: user=${authProvider.user?.email}, isAdmin=$isAdmin');
    return isAdmin;
  }

  Future<void> _handleVerification(bool approve, [String? rejectionReason]) async {
    if (!_isAdmin(context)) {
      Fluttertoast.showToast(
        msg: 'Only admins can verify events',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.event.id).update({
        'isVerified': approve,
        'verificationStatus': approve ? 'approved' : 'rejected',
        'approvedAt': approve ? FieldValue.serverTimestamp() : null,
        'rejectionReason': approve ? null : rejectionReason,
        'status': null, // Remove redundant 'status' field
      });
      setState(() {
        currentVerificationStatus = approve;
      });
      widget.onStatusUpdate(approve ? 'Approved' : 'Rejected'); // Notify HomeScreen
      print('Event ${widget.event.title} ${approve ? 'approved' : 'rejected'} in Firestore${approve ? '' : ' with reason: $rejectionReason'}');
      Fluttertoast.showToast(
        msg: approve ? 'Event Approved!' : 'Event Rejected!',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: approve ? Colors.green : Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating verification status: $e');
      Fluttertoast.showToast(
        msg: 'Error updating verification status: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showVerificationDialog() {
    String? rejectionReason;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Do you want to approve or reject this event?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (required for rejection)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {
                rejectionReason = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              _handleVerification(true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rejectionReason == null || rejectionReason?.isEmpty == true) {
                Fluttertoast.showToast(
                  msg: 'Please provide a rejection reason',
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.CENTER,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                return;
              }
              _handleVerification(false, rejectionReason);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument() async {
    if (widget.verificationDocumentUrl != null) {
      final url = widget.verificationDocumentUrl!;
      print('Attempting to open document: $url');
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          print('Could not launch URL: $url');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the document.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error launching URL: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verification document available.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildDocumentPreview() {
    if (widget.verificationDocumentUrl != null) {
      final isImage = widget.verificationDocumentType?.toLowerCase().contains('jpg') == true ||
          widget.verificationDocumentType?.toLowerCase().contains('jpeg') == true ||
          widget.verificationDocumentType?.toLowerCase().contains('png') == true;

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(widget.verificationDocumentType ?? ''),
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verification Document: ${widget.verificationDocumentType ?? 'Document'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isImage)
                GestureDetector(
                  onTap: _viewDocument,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.verificationDocumentUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _viewDocument,
                  icon: const Icon(Icons.description),
                  label: const Text('View Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  IconData _getDocumentIcon(String documentType) {
    final extension = documentType.toLowerCase();
    if (extension.contains('pdf')) return Icons.picture_as_pdf;
    if (extension.contains('doc') || extension.contains('docx')) return Icons.description;
    if (extension.contains('jpg') || extension.contains('jpeg') || extension.contains('png')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Future<void> _handlePayment() async {
    if (!currentVerificationStatus) {
      Fluttertoast.showToast(
        msg: "Event must be verified before payment",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    try {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            event: widget.event,
            ticketId: ticketId,
            total: widget.event.price,
            onPaymentSuccess: () {
              final booking = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'event': widget.event.title,
                'total': widget.event.price,
                'paid': true,
                'ticketId': ticketId,
                'isVerified': currentVerificationStatus,
                'verificationStatus': widget.verificationStatus,
              };
              widget.onBookingAdded(booking);
              widget.onStatusUpdate('Paid');
              print('Payment successful for event: ${widget.event.title}');
              Fluttertoast.showToast(
                msg: "Payment Successful!",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 19.0,
              );
            },
          ),
        ),
      );
    } catch (e) {
      print('Error initiating payment: $e');
      Fluttertoast.showToast(
        msg: 'Error initiating payment: $e',
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
    final isAdmin = _isAdmin(context);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.event.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentVerificationStatus ? Colors.green : (widget.verificationStatus == 'unverified' ? Colors.red : Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentVerificationStatus ? Icons.verified : Icons.warning,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentVerificationStatus ? 'Verified' : 'Unverified',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 24),
                  tooltip: 'Verify Event',
                  onPressed: _isLoading ? null : _showVerificationDialog,
                ),
            ],
          ),
        ],
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin && widget.verificationDocumentUrl != null) ...[
                    _buildDocumentPreview(),
                    const SizedBox(height: 16),
                  ],
                  if (currentVerificationStatus) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Event Verified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verification approved by admin.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Unverified Event',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.rejectionReason != null
                                ? 'Verification rejected: ${widget.rejectionReason}'
                                : 'This event has not been verified. Proceed with caution.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.event.price <= 0.0) ...[
                    const Text("Here's your QR code ticket:"),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: PrettyQrView.data(
                          data: ticketId,
                          errorCorrectLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        "Ticket ID: ${ticketId.substring(0, 8)}...",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Please present this QR code at the event."),
                  ] else ...[
                    Text(
                      "This event requires a payment of €${widget.event.price.toStringAsFixed(2)}. Please proceed to checkout.",
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.red),
          ),
        ),
        if (widget.event.price <= 0.0)
          TextButton(
            onPressed: () {
              final booking = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'event': widget.event.title,
                'total': 0.0,
                'paid': true,
                'ticketId': ticketId,
                'isVerified': currentVerificationStatus,
                'verificationStatus': widget.verificationStatus,
              };
              widget.onBookingAdded(booking);
              widget.onStatusUpdate('Paid');
              print('Free ticket generated for event: ${widget.event.title}');
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: "Free Event Ticket Generated!",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 19.0,
              );
            },
            child: const Text("Done"),
          )
        else
          ElevatedButton(
            onPressed: _isLoading ? null : _handlePayment,
            child: const Text('Proceed to Checkout'),
          ),
      ],
    );
  }
}