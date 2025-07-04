import 'package:flutter/material.dart';

class CheckoutScreen extends StatefulWidget {
  final double total;
  final VoidCallback? onPaymentSuccess;  // <-- Added callback

  const CheckoutScreen({
    super.key,
    required this.total,
    this.onPaymentSuccess,               // <-- Accept callback here
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum PaymentMethod { paypal, card, mobileMoney }

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  bool subscribeOrganizer = true;
  bool subscribeUpdates = true;
  PaymentMethod? _selectedPayment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Checkout Your Ticket",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Billing Info Section
              Card(
                elevation: 3,
                color: const Color.fromARGB(255, 212, 228, 245),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Billing information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    color: Colors.white,
                                    elevation: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: "First name *",
                                          border: InputBorder.none,
                                        ),
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
                                    elevation: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: TextFormField(
                                        decoration: const InputDecoration(
                                          labelText: "Surname *",
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (val) => lastName = val,
                                        validator: (val) => val!.isEmpty ? "Required" : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Card(
                              color: Colors.white,
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: "Email address *",
                                    border: InputBorder.none,
                                  ),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text("Payment Methods", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              /// Payment Option Cards
              _buildStyledPaymentCard(
                value: PaymentMethod.paypal,
                logo: 'assets/images/paid.jpg',
                title: "PayPal",
                bgColor: Colors.white,
                borderColor: const Color.fromARGB(255, 2, 92, 26),
              ),
              _buildStyledPaymentCard(
                value: PaymentMethod.card,
                logo: 'assets/images/card.jpeg',
                title: "Credit / Debit Card",
                bgColor: const Color.fromARGB(255, 252, 253, 254),
                borderColor: const Color.fromARGB(255, 0, 97, 13),
              ),
              _buildStyledPaymentCard(
                value: PaymentMethod.mobileMoney,
                logo: 'assets/images/mobile.jpg',
                title: "Mobile Money",
                bgColor: Colors.white,
                borderColor: const Color.fromARGB(255, 1, 103, 4),
              ),

              const SizedBox(height: 40),

              /// Book Ticket Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_selectedPayment == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a payment method")),
                      );
                      return;
                    }
                    _openPaymentDialog(_selectedPayment!);
                  }
                },
                child: const Text("Book Ticket", style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Payment Card Builder
  Widget _buildStyledPaymentCard({
    required PaymentMethod value,
    required String logo,
    required String title,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Card(
        color: bgColor,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isSelected ? borderColor : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  logo,
                  height: 30,
                  width: 50,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Payment Dialog Selector
  void _openPaymentDialog(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.paypal:
        String paypalEmail = '';
        _showInputDialog(
          title: "Pay with PayPal",
          content: TextFormField(
            decoration: const InputDecoration(labelText: "PayPal Email"),
            onChanged: (val) => paypalEmail = val,
          ),
          onConfirm: () {
            // ✅ Integrate PayPal API here
            _showSuccessDialog();
          },
        );
        break;

      case PaymentMethod.card:
        String cardNumber = '';
        String expiry = '';
        String cvv = '';
        _showInputDialog(
          title: "Pay with Card",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Card Number"),
                onChanged: (val) => cardNumber = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Expiry Date (MM/YY)"),
                onChanged: (val) => expiry = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "CVV"),
                onChanged: (val) => cvv = val,
              ),
            ],
          ),
          onConfirm: () {
            // ✅ Integrate card payment API here
            _showSuccessDialog();
          },
        );
        break;

      case PaymentMethod.mobileMoney:
        String phone = '';
        String provider = 'MTN';
        _showInputDialog(
          title: "Pay with Mobile Money",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Phone Number"),
                onChanged: (val) => phone = val,
              ),
              DropdownButtonFormField<String>(
                value: provider,
                decoration: const InputDecoration(labelText: "Network"),
                items: const [
                  DropdownMenuItem(value: "MTN", child: Text("MTN")),
                  DropdownMenuItem(value: "Airtel", child: Text("Airtel")),
                ],
                onChanged: (val) => provider = val!,
              ),
            ],
          ),
          onConfirm: () {
            // ✅ Integrate mobile money API here
            _showSuccessDialog();
          },
        );
        break;
    }
  }

  /// Input Dialog Template
  void _showInputDialog({
    required String title,
    required Widget content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Pay Now"),
          ),
        ],
      ),
    );
  }

  /// Success Dialog with callback call
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Booking Successful"),
        content: Text("You booked your ticket for €${widget.total.toStringAsFixed(2)}."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
              if (widget.onPaymentSuccess != null) {
                widget.onPaymentSuccess!();
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}






