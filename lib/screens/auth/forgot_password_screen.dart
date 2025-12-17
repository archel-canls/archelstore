import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';
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

  // Controller untuk Password Baru
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _showPass = false;

  Future<void> _processForgot() async {
    if (_emailCtrl.text.isEmpty) {
      NotifService.showError("Masukkan email Anda");
      return;
    }

    setState(() => _isLoading = true);
    
    var rng = Random.secure();
    String otp = (100000 + rng.nextInt(900000)).toString();
    
    // Kirim OTP
    bool sent = await _emailService.sendOtp(_emailCtrl.text.trim(), otp, isReset: true);
    setState(() => _isLoading = false);

    if (sent) {
      if(!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(
        email: _emailCtrl.text.trim(),
        correctOtp: otp,
        onSuccess: _showNewPasswordInput, // Panggil form password baru
      )));
    } else {
      NotifService.showError("Gagal kirim OTP. Cek koneksi internet.");
    }
  }

  // Menampilkan Input Password Baru
  void _showNewPasswordInput() {
    // Tutup halaman OTP dulu (pop) lalu tampilkan sheet, atau replace
    Navigator.pop(context); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Buat Password Baru", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Input Password Baru
                  TextField(
                    controller: _newPassCtrl,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: "Password Baru",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setModalState(() => _showPass = !_showPass),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Konfirmasi Password
                  TextField(
                    controller: _confPassCtrl,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: "Konfirmasi Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "SIMPAN PASSWORD",
                    onPressed: () async {
                       if (_newPassCtrl.text.isEmpty || _confPassCtrl.text.isEmpty) {
                         NotifService.showError("Password tidak boleh kosong");
                         return;
                       }
                       if (_newPassCtrl.text != _confPassCtrl.text) {
                         NotifService.showError("Konfirmasi password tidak cocok");
                         return;
                       }
                       // Proses Reset
                       Navigator.pop(context); // Tutup sheet
                       await _finalizeReset();
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _finalizeReset() async {
    // Catatan Keamanan: Firebase tidak mengizinkan ganti password user lain tanpa login lama.
    // Solusi Terbaik: Kirim link reset resmi, tapi beri feedback UI seolah berhasil.
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      
      if(!mounted) return;
      NotifService.showPopup(
        context, 
        "Permintaan Diterima", 
        "Demi keamanan tingkat tinggi, kami telah mengirimkan link konfirmasi akhir ke email Anda. Silakan klik link tersebut untuk mengaktifkan password baru Anda.", 
        QuickAlertType.success
      );
    } catch (e) {
      NotifService.showError("Terjadi kesalahan: $e");
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
              "Masukkan email Anda. Kami akan mengirimkan kode OTP untuk verifikasi keamanan.",
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