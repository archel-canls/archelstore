import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notif_service.dart';
import '../../widgets/custom_button.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showPass = false; // State untuk mata

  void _doLogin() async {
    String email = _emailCtrl.text.trim();
    String pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      NotifService.showError("Email dan Password wajib diisi!");
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Login process
    bool success = await Provider.of<AuthService>(context, listen: false).login(email, pass);
    
    if(mounted) setState(() => _isLoading = false);

    if (success && mounted) {
      // FIX BUG: Paksa navigasi ke root (Dashboard) agar tidak stuck di login
      // Ini mengatasi masalah delay StreamBuilder pada aplikasi ganda/dual apps
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    // Jika gagal, AuthService atau NotifService sudah menampilkan error di dalam fungsi login()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront, size: 80, color: Color(0xFFE91E63)),
                const SizedBox(height: 10),
                const Text("ArchelStore", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Masuk untuk belanja", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                // Input Email
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: "Email / Username",
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Input Password dengan Mata
                TextField(
                  controller: _passCtrl,
                  obscureText: !_showPass, // Toggle obscure
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: const Text("Lupa Password?"),
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: "MASUK",
                  isLoading: _isLoading,
                  onPressed: _doLogin,
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Belum punya akun? "),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text("Daftar Sekarang", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                  )
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}