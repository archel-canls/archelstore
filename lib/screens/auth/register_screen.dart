// screens/auth/register_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../services/notif_service.dart';
import '../../widgets/custom_button.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();
  
  bool _isLoading = false;
  final EmailService _emailService = EmailService();

  Future<void> _processRegister() async {
    // 1. Validasi Input
    if (_nameCtrl.text.isEmpty || _userCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      NotifService.showError("Semua kolom wajib diisi");
      return;
    }
    if (_passCtrl.text != _confPassCtrl.text) {
      NotifService.showError("Konfirmasi password tidak cocok");
      return;
    }

    setState(() => _isLoading = true);

    // 2. Generate OTP Menggunakan Random.secure() (Cryptographically Strong)
    var rng = Random.secure();
    String otp = (100000 + rng.nextInt(900000)).toString();
    
    // Kirim Email
    bool sent = await _emailService.sendOtp(_emailCtrl.text.trim(), otp);

    setState(() => _isLoading = false);

    if (sent) {
      // 3. Pindah ke Layar OTP
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(
        email: _emailCtrl.text.trim(),
        correctOtp: otp,
        onSuccess: _createFirebaseAccount, // Callback jika OTP benar
      )));
    } else {
      NotifService.showError("Gagal mengirim email OTP. Periksa koneksi internet.");
    }
  }

  Future<void> _createFirebaseAccount() async {
    // 4. Buat Akun di Firebase setelah OTP Valid
    NotifService.showToast("Membuat akun...");
    bool success = await Provider.of<AuthService>(context, listen: false).registerUser(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      nama: _nameCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );

    if (success && mounted) {
      NotifService.showSuccess("Pendaftaran Berhasil!");
      Navigator.popUntil(context, (route) => route.isFirst); // Kembali ke Login/Home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildInput(_nameCtrl, "Nama Lengkap", Icons.person),
              const SizedBox(height: 15),
              _buildInput(_userCtrl, "Username", Icons.alternate_email),
              const SizedBox(height: 15),
              _buildInput(_emailCtrl, "Email", Icons.email, type: TextInputType.emailAddress),
              const SizedBox(height: 15),
              _buildInput(_phoneCtrl, "Nomor Telepon", Icons.phone, type: TextInputType.phone),
              const SizedBox(height: 15),
              _buildInput(_passCtrl, "Password", Icons.lock, isObscure: true),
              const SizedBox(height: 15),
              _buildInput(_confPassCtrl, "Konfirmasi Password", Icons.lock_outline, isObscure: true),
              const SizedBox(height: 30),
              CustomButton(
                text: "KIRIM KODE OTP",
                isLoading: _isLoading,
                onPressed: _processRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String label, IconData icon, {bool isObscure = false, TextInputType? type}) {
    return TextField(
      controller: c,
      obscureText: isObscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}