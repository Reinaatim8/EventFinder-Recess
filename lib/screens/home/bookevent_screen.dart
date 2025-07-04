import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CheckoutScreen extends StatefulWidget {
  final double total;
  const CheckoutScreen({super.key, required this.total});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum PaymentNetwork { mtn, airtel }

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  bool subscribeOrganizer = true;
  bool subscribeUpdates = true;
  PaymentNetwork? _selectedNetwork;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout Your Ticket",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Billing Card
          Card(
            elevation: 3,
            color: const Color.fromARGB(255, 212, 228, 245),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Billing Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Form(
                  key: _formKey,
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "First Name *", border: InputBorder.none),
                              onChanged: (val) => firstName = val,
                              validator: (val) => val!.isEmpty ? "Required" : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "Surname *", border: InputBorder.none),
                              onChanged: (val) => lastName = val,
                              validator: (val) => val!.isEmpty ? "Required" : null,
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: "Email Address *", border: InputBorder.none),
                          onChanged: (val) => email = val,
                          validator: (val) => val!.isEmpty ? "Required" : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text("Keep me updated on more events and news from this organiser."),
                      value: subscribeOrganizer,
                      onChanged: (val) => setState(() => subscribeOrganizer = val!),
                    ),
                    CheckboxListTile(
                      title: const Text("Send me emails about the best events happening nearby or online."),
                      value: subscribeUpdates,
                      onChanged: (val) => setState(() => subscribeUpdates = val!),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),
          const Text("Mobile Money Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // MTN
          _buildNetworkCard(
            value: PaymentNetwork.mtn,
            title: "MTN Mobile Money",
            image: "assets/images/mtn.jpg",
            bgColor: Colors.yellow.shade100,
            borderColor: Colors.orange,
          ),

          // Airtel
          _buildNetworkCard(
            value: PaymentNetwork.airtel,
            title: "Airtel Money",
            image: "assets/images/airtel.png",
            bgColor: Colors.red.shade50,
            borderColor: Colors.redAccent,
          ),

          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (_selectedNetwork == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select a payment network")));
                  return;
                }
                _openMobileMoneyDialog(_selectedNetwork!);
              }
            },
            child: const Text("Book Ticket", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ]),
      ),
    );
  }

  Widget _buildNetworkCard({
    required PaymentNetwork value,
    required String title,
    required String image,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isSelected = _selectedNetwork == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedNetwork = value),
      child: Card(
        color: bgColor,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isSelected ? borderColor : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(image, height: 30, width: 50, fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              if (isSelected) Icon(Icons.check_circle, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }

  void _openMobileMoneyDialog(PaymentNetwork network) {
    String phone = '';
    String provider = network == PaymentNetwork.mtn ? 'MTN' : 'Airtel';
    String qrData = _generateQRData();
    print("QR Data: $qrData");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Pay with $provider Money"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Phone Number"),
                    onChanged: (val) => phone = val,
                  ),
                  const SizedBox(height: 20),
                  if(qrData.isNotEmpty)
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 150.0,
                    gapless: true, 
                  )
                  else
                    const Text("Generating QR code..."),
                  const SizedBox(height: 10),
                  const Text("Scan this QR code to complete your payment."),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Regenerate the QR code
                  setState(() {
                    qrData = _generateQRData();
                  });
                },
                child: const Text("Cancel & Regenerate"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessDialog();
                },
                child: const Text("Confirm Payment"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _generateQRData() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return "${firstName}_${lastName}_${email}_${widget.total}_$now";
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Booking Successful"),
        content: Text("You booked your ticket for €${widget.total.toStringAsFixed(2)}."),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}







