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
  bool _showPass = false; // Variabel untuk fitur Show/Hide Password
  final EmailService _emailService = EmailService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _processRegister() async {
    // 1. Validasi Input
    if (_nameCtrl.text.isEmpty || 
        _userCtrl.text.isEmpty || 
        _emailCtrl.text.isEmpty || 
        _phoneCtrl.text.isEmpty || 
        _passCtrl.text.isEmpty) {
      NotifService.showError("Semua kolom wajib diisi");
      return;
    }
    
    if (_passCtrl.text != _confPassCtrl.text) {
      NotifService.showError("Konfirmasi password tidak cocok");
      return;
    }

    // Cek panjang password minimal (opsional, tapi disarankan)
    if (_passCtrl.text.length < 6) {
      NotifService.showError("Password minimal 6 karakter");
      return;
    }

    setState(() => _isLoading = true);

    // 2. Generate OTP Menggunakan Random.secure()
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
      // Gunakan pushNamedAndRemoveUntil untuk membersihkan history dan memastikan masuk Dashboard
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.person_add, size: 60, color: Color(0xFFE91E63)),
                const SizedBox(height: 20),
                _buildInput(_nameCtrl, "Nama Lengkap", Icons.person),
                const SizedBox(height: 15),
                _buildInput(_userCtrl, "Username", Icons.alternate_email),
                const SizedBox(height: 15),
                _buildInput(_emailCtrl, "Email", Icons.email, type: TextInputType.emailAddress),
                const SizedBox(height: 15),
                _buildInput(_phoneCtrl, "Nomor Telepon", Icons.phone, type: TextInputType.phone),
                const SizedBox(height: 15),
                // Input Password dengan Mata
                _buildInput(_passCtrl, "Password", Icons.lock, isObscure: true),
                const SizedBox(height: 15),
                // Input Konfirmasi Password dengan Mata
                _buildInput(_confPassCtrl, "Konfirmasi Password", Icons.lock_outline, isObscure: true),
                const SizedBox(height: 30),
                CustomButton(
                  text: "KIRIM KODE OTP",
                  isLoading: _isLoading,
                  onPressed: _processRegister,
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Sudah punya akun? "),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Kembali ke Login
                    child: const Text("Masuk", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                  )
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget Input yang Dimodifikasi untuk Support Show/Hide Password
  Widget _buildInput(TextEditingController c, String label, IconData icon, {bool isObscure = false, TextInputType? type}) {
    // Deteksi apakah field ini adalah password berdasarkan labelnya
    bool isPasswordField = label.toLowerCase().contains("password");

    return TextField(
      controller: c,
      // Jika password, gunakan state _showPass. Jika bukan, ikuti parameter isObscure.
      obscureText: isPasswordField ? !_showPass : isObscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        // Logika ikon mata (Show/Hide)
        suffixIcon: isPasswordField 
            ? IconButton(
                icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _showPass = !_showPass),
              ) 
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}