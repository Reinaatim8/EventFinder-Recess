import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:screenshot/screenshot.dart';
import 'package:permission_handler/permission_handler.dart';


class CheckoutScreen extends StatefulWidget {
  final double total;
  final VoidCallback? onPaymentSuccess;

  const CheckoutScreen({
    super.key,
    required this.total,
    this.onPaymentSuccess,
  });

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
  String? _validatedPhone;
  String? _ticketId; // QR code ticket

  //final ScreenshotController _screenshotController = ScreenshotController();
  final String subscriptionKey = "aab1d593853c454c9fcec8e4e02dde3c";
  final String apiUser = "815d497c-9cb6-477c-8e30-23c3c2b3bea6";
  final String apiKey = "5594113210ab4f3da3a7329b0ae65f40";

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
        gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF81D4FA)],
    ),
    ),
      child: Scaffold(
      appBar: AppBar(
        title: const Text("Checkout Your Ticket",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
        toolbarHeight: 80,
          //color: Theme.of(context).primaryColor
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            elevation: 3,
            color: const Color.fromARGB(255, 212, 228, 245),
            shape: RoundedRectangleBorder(
              borderRadius: 
              BorderRadius.circular(12)
              
              ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                const Text("💳 Billing Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Form(
                  key: _formKey,
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: "First Name *", filled: false, ),
                          onChanged: (val) => firstName = val,
                          validator: (val) => val!.isEmpty ? "Required" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: "Surname *"),
                          onChanged: (val) => lastName = val,
                          validator: (val) => val!.isEmpty ? "Required" : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Email Address *"),
                      initialValue: '', // Optional: pre-fill with user's email if available
                      //autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      
                      onChanged: (val) => email = val,
                      validator: (val) => val!.isEmpty ? "Required" : null,
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
          _buildNetworkCard(
            value: PaymentNetwork.mtn,
            title: "MTN Mobile Money",
            image: "assets/images/mtn.jpg",
            bgColor: Colors.yellow.shade100,
            borderColor: Colors.orange,
          ),
          // _buildNetworkCard(
          //   value: PaymentNetwork.airtel,
          //   title: "Airtel Money",
          //   image: "assets/images/airtel.png",
          //   bgColor: Colors.red.shade50,
          //   borderColor: Colors.redAccent,
          //),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Color.fromARGB(255, 25, 25, 95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (_selectedNetwork == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a payment network")),
                  );
                  return;
                }
                _openMobileMoneyDialog(_selectedNetwork!);
              }
            },
            child: const Text("Get Your Ticket", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ]),
      ),
    )
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
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
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
    bool isLoading = false;
    bool _hasShownToast = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Pay with $provider Mobile Money" ,),
            titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            icon: const Icon(Icons.mobile_friendly, color: Colors.yellow, size: 30, ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone Number",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                          color: Colors.yellow,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (val) async {
                      phone = val;
                      if (phone.length == 10 && !_hasShownToast) {
                        setState(() {
                          isLoading = true;
                          _hasShownToast = true;
                        });
                        final token = await getAccessToken();
                        if (token != null) {
                          try {
                            await validateAccountHolder(phone, token);
                            _validatedPhone = phone;
                            Fluttertoast.showToast(
                              msg: "📲 Valid Mobile Money account. You may now proceed to Confirm Payment.",
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.TOP,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                            );
                          } catch (e) {
                            Fluttertoast.showToast(
                              msg: "❌ Invalid account or error verifying number.",
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.TOP,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                            _validatedPhone = null;
                            _hasShownToast = false;
                          }
                        }
                        setState(() => isLoading = false);
                      } else if (phone.length < 10) {
                        _hasShownToast = false;
                        _validatedPhone = null;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isLoading) const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text("Hold on as we Validate your Phone number has a MobileMoney Account For your payment."),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                  
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_validatedPhone != null) {
                    final token = await getAccessToken();
                    if (token != null) {
                      try {
                        await requestToPay(phoneNumber: _validatedPhone!, accessToken: token, amount: widget.total);
                        _showSuccessDialog();
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: "❌ Payment failed: ${e.toString()}",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      }
                    }
                  } else {
                    Fluttertoast.showToast(
                      msg: "❌ Please enter and validate a valid number first.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.TOP,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                },
                child: const Text("Confirm Payment"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    _ticketId = const Uuid().v4();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Payment Successful ✅", style: TextStyle(fontSize:20,fontWeight: FontWeight.bold,)),
        content:Column(
          mainAxisSize: MainAxisSize.min,
           children: [
            Text("Your Event ticket for EUR${widget.total.toStringAsFixed(2)}."),
            const SizedBox(height: 16),
            const Text("🎟 Your Ticket QR Code", style: TextStyle(fontWeight: FontWeight.bold,)),
             if (_ticketId != null)

               SizedBox(
                 width: 180,
                 height: 180,
                 child: PrettyQrView.data(
                   data: _ticketId!,
                   errorCorrectLevel: QrErrorCorrectLevel.M,
                 ),
               ),
            const SizedBox(height: 8),
             if (_ticketId != null)
               Text('QR Code for: $_ticketId'),

             const SizedBox(height:10),
            const Text("Save or screenshot this QR for entry.",
               style: TextStyle(fontSize:12,color:Colors.black)),
            ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (widget.onPaymentSuccess != null) {
                widget.onPaymentSuccess!();
              }
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<String?> getAccessToken() async {
    final credentials = base64Encode(utf8.encode('$apiUser:$apiKey'));
    final headers = {
      'Authorization': 'Basic $credentials',
      'Ocp-Apim-Subscription-Key': subscriptionKey,
    };

    final response = await http.post(
      Uri.parse("https://sandbox.momodeveloper.mtn.com/collection/token/"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      print("Access token obtained successfully");
      return jsonDecode(response.body)['access_token'];
    } else {
      print("Token error: ${response.body}");
      return null;
    }
  }

  Future<void> validateAccountHolder(String phone, String accessToken) async {
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'X-Target-Environment': 'sandbox',
      'Ocp-Apim-Subscription-Key': subscriptionKey,
    };

    final response = await http.get(
      Uri.parse("https://sandbox.momodeveloper.mtn.com/collection/v1_0/accountholder/msisdn/$phone/active"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      print("✅ Account is active: $phone");
    } else {
      print("❌ Account not active: ${response.body}");
      throw Exception("Account not active: ${response.body}");
    }
  }

  Future<void> requestToPay({
    required String phoneNumber,
    required String accessToken,
    required double amount,
  }) async {
    final uuid = const Uuid().v4();
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'X-Reference-Id': uuid,
      'X-Target-Environment': 'sandbox',
      'Content-Type': 'application/json',
      'Ocp-Apim-Subscription-Key': subscriptionKey,
    };

    final body = jsonEncode({
      "amount": amount.toStringAsFixed(2),
      "currency": "EUR",
      "externalId": "123456",
      "payer": {
        "partyIdType": "MSISDN",
        "partyId": phoneNumber,
      },
      "payerMessage": "Ticket Payment",
      "payeeNote": "Thank you for booking!",
    });

    final url = Uri.parse("https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay");
    print("📤 Sending request to pay to $phoneNumber...");
    print("Request Headers: $headers");
    print("Request Body: $body");

    final response = await http.post(url, headers: headers, body: body);
    print("Response Status: ${response.statusCode}");
    print("Response Body: ${response.body}");

    if (response.statusCode == 202) {
      print("✅ RequestToPay sent successfully. Awaiting user action.");
      Fluttertoast.showToast(
        msg: "✅ Payment request sent. Please approve it on your phone.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      print("❌ Failed to initiate payment: ${response.body}");
      throw Exception("Failed to initiate payment: ${response.body}");
    }
  }
}
