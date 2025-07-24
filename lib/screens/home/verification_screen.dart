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
        'status': null,
      });
      setState(() {
        currentVerificationStatus = approve;
      });
      widget.onStatusUpdate(approve ? 'Approved' : 'Rejected');
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
      // Show caution dialog for unverified events
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Caution: Unverified Event'),
          content: const Text(
            'This event is not yet verified. Paying for an unverified event may carry risks, as the event details have not been confirmed by an administrator. Do you wish to proceed with payment?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        print('User cancelled payment for unverified event: ${widget.event.title}');
        return;
      }
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
                'eventId': widget.event.id,
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

  Future<void> _handleBooking() async {
    try {
      final booking = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'event': widget.event.title,
        'total': widget.event.price,
        'paid': widget.event.price == '0' || widget.event.price == '0.0' || widget.event.price == '0.00' ? true : false,
        'ticketId': ticketId,
        'isVerified': currentVerificationStatus,
        'verificationStatus': widget.verificationStatus,
        'eventId': widget.event.id,
      };
      widget.onBookingAdded(booking);
      widget.onStatusUpdate('Reserved');
      print('Booking successful for event: ${widget.event.title}, isVerified: ${currentVerificationStatus}');
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Event Reservation Successful!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 19.0,
      );
    } catch (e) {
      print('Error booking event: $e');
      Fluttertoast.showToast(
        msg: 'Error booking event: $e',
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
    // final isPast = widget.event.date.isNotEmpty
    //     ? DateTime.parse(widget.event.date).isBefore(DateTime.now())
    //     : false;
    final isPast = widget.event.date.isNotEmpty
      ? () {
          try {
            final parts = widget.event.date.split('/');
            final parsedDate = DateTime(
              int.parse(parts[2]), // year
              int.parse(parts[1]), // month
              int.parse(parts[0])  // day
            );
            return parsedDate.isBefore(DateTime.now());
          } catch (e) {
            return false; // fallback in case of format error
          }
        }()
      : false;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: currentVerificationStatus ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentVerificationStatus ? 'Verified' : 'Unverified',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Date: ${widget.event.date}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${widget.event.location}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ${widget.event.price == '0' || widget.event.price == '0.0' || widget.event.price == '0.00' ? 'Free' : 'UGX ${widget.event.price}'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (widget.verificationStatus != null)
              Text(
                'Verification Status: ${widget.verificationStatus}',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.verificationStatus == 'approved' ? Colors.green : Colors.red,
                ),
              ),
            if (widget.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Rejection Reason: ${widget.rejectionReason}',
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            _buildDocumentPreview(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (isPast)
              const Text(
                'This event has already passed.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else ...[
              if (isAdmin)
                ElevatedButton(
                  onPressed: _showVerificationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Verify/Reject Event'),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _handleBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Book Event'),
              ),
              const SizedBox(height: 8),
              if (widget.event.price != '0' && widget.event.price != '0.0' && widget.event.price != '0.00')
                ElevatedButton(
                  onPressed: _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pay for Event'),
                ),
            ],
            const SizedBox(height: 16),
            if (!isPast)
              Column(
                children: [
                  const Text(
                    'Event Ticket QR Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  PrettyQr(
                    data: ticketId,
                    size: 150,
                    roundEdges: true,
                    errorCorrectLevel: QrErrorCorrectLevel.M,
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}