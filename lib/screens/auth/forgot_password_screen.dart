// screens/auth/forgot_password_screen.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/email_service.dart';
import '../../services/notif_service.dart';
import '../../widgets/custom_button.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final EmailService _emailService = EmailService();
  bool _isLoading = false;

  Future<void> _processForgot() async {
    if (_emailCtrl.text.isEmpty) {
      NotifService.showError("Masukkan email Anda");
      return;
    }

    setState(() => _isLoading = true);
    
    // Generate OTP Menggunakan Random.secure() (Cryptographically Strong)
    var rng = Random.secure();
    String otp = (100000 + rng.nextInt(900000)).toString();
    
    bool sent = await _emailService.sendOtp(_emailCtrl.text.trim(), otp, isReset: true);
    setState(() => _isLoading = false);

    if (sent) {
      if(!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(
        email: _emailCtrl.text.trim(),
        correctOtp: otp,
        onSuccess: _sendFirebaseResetLink,
      )));
    } else {
      NotifService.showError("Gagal kirim OTP. Email tidak valid atau koneksi error.");
    }
  }

  Future<void> _sendFirebaseResetLink() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      
      if(!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Verifikasi Berhasil"),
          content: const Text("Kami telah mengirimkan LINK untuk membuat password baru ke email Anda. Silakan cek inbox/spam email Anda sekarang."),
          actions: [
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text("KEMBALI KE LOGIN"),
            )
          ],
        ),
      );
    } catch (e) {
      NotifService.showError("Gagal memproses reset: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lupa Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Masukkan email yang terdaftar. Kami akan mengirimkan kode OTP untuk verifikasi.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: "KIRIM KODE OTP",
              isLoading: _isLoading,
              onPressed: _processForgot,
            ),
          ],
        ),
      ),
    );
  }
}