import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'checkout_screen.dart';
import '../../models/event.dart';

class VerificationScreen extends StatefulWidget {
  final Event event;
  final Function(Map<String, dynamic>) onBookingAdded;
  final Function(String) onStatusUpdate;
  final bool isVerified;
  final String? verificationDocumentUrl;
  final String? verificationStatus;
  final String? rejectionReason;

  const VerificationScreen({
    Key? key,
    required this.event,
    required this.onBookingAdded,
    required this.onStatusUpdate,
    required this.isVerified,
    this.verificationDocumentUrl,
    this.verificationStatus,
    this.rejectionReason,
  }) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late String ticketId;
  late bool currentVerificationStatus;

  @override
  void initState() {
    super.initState();
    ticketId = const Uuid().v4();
    currentVerificationStatus = _checkVerificationStatus();

    print('VerificationScreen initialized:');
    print('  - eventTitle: ${widget.event.title}');
    print('  - isVerified: ${widget.isVerified}');
    print('  - verificationDocumentUrl: ${widget.verificationDocumentUrl}');
    print('  - verificationStatus: ${widget.verificationStatus}');
    print('  - currentVerificationStatus: $currentVerificationStatus');
  }

  bool _checkVerificationStatus() {
    final hasDocument = widget.verificationDocumentUrl != null && widget.verificationDocumentUrl!.isNotEmpty;
    final isNotRejected = widget.verificationStatus != 'rejected';
    return widget.isVerified || (hasDocument && isNotRejected);
  }

  @override
  Widget build(BuildContext context) {
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
              color: currentVerificationStatus ? Colors.green : (widget.verificationStatus == 'pending' ? Colors.orange : Colors.red),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentVerificationStatus ? Icons.verified : (widget.verificationStatus == 'pending' ? Icons.hourglass_empty : Icons.warning),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  currentVerificationStatus ? 'Verified' : (widget.verificationStatus == 'pending' ? 'Pending' : 'Unverified'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    widget.verificationDocumentUrl != null ? 'Verification based on provided document.' : 'Verification approved by admin.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (widget.verificationStatus == 'pending') ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verification Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This event is awaiting admin verification.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
              widget.onBookingAdded({
                'id': DateTime.now().millisecondsSinceEpoch,
                'event': widget.event.title,
                'total': 0.0,
                'paid': true,
                'ticketId': ticketId,
                'isVerified': currentVerificationStatus,
                'verificationStatus': widget.verificationStatus,
              });
              widget.onStatusUpdate('Paid');
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(
                    event: widget.event,
                    ticketId: ticketId,
                    total: widget.event.price,
                    onPaymentSuccess: () {
                      widget.onBookingAdded({
                        'id': DateTime.now().millisecondsSinceEpoch,
                        'event': widget.event.title,
                        'total': widget.event.price,
                        'paid': true,
                        'ticketId': ticketId,
                        'isVerified': currentVerificationStatus,
                        'verificationStatus': widget.verificationStatus,
                      });
                      widget.onStatusUpdate('Paid');
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
            },
            child: const Text('Proceed to Checkout'),
          ),
      ],
    );
  }
}