import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart'; // Pastikan package pinput ada di pubspec
import '../../widgets/custom_button.dart';
import '../../services/notif_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String correctOtp;
  final Function() onSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.correctOtp,
    required this.onSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();

  void _verify() {
    if (_pinController.text == widget.correctOtp) {
      widget.onSuccess();
    } else {
      NotifService.showError("Kode OTP Salah!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "Kode verifikasi telah dikirim ke email:",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 30),
            Pinput(
              length: 6,
              controller: _pinController,
              defaultPinTheme: PinTheme(
                width: 50,
                height: 50,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE91E63)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onCompleted: (pin) => _verify(),
            ),
            const SizedBox(height: 30),
            CustomButton(text: "VERIFIKASI", onPressed: _verify),
          ],
        ),
      ),
    );
  }
}