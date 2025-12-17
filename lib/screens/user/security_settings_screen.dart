import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; 

// Imports Services
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/notif_service.dart';

// Import Layar PIN
import '../security/pin_input_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final DbService _dbService = DbService();
  final LocalAuthService _localAuth = LocalAuthService();
  
  bool _isBioEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      setState(() {
        _isBioEnabled = user.isBiometricEnabled;
      });
    }
  }

  // --- LOGIKA 1: GANTI PIN (Password -> Buat PIN Baru) ---
  void _changePinFlow() {
    final passCtrl = TextEditingController();
    bool isVerifyingPass = false;

    // 1. Dialog Minta Password Akun (Gerbang Masuk)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Verifikasi Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Masukkan password akun untuk mengubah/membuat PIN baru."),
                const SizedBox(height: 15),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password", 
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
              ElevatedButton(
                onPressed: isVerifyingPass ? null : () async {
                  setStateDialog(() => isVerifyingPass = true);
                  
                  bool isPassValid = await Provider.of<AuthService>(context, listen: false).verifyPassword(passCtrl.text);
                  
                  setStateDialog(() => isVerifyingPass = false);

                  if (isPassValid) {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx); // Tutup dialog password
                    
                    final user = Provider.of<AuthService>(context, listen: false).currentUser;
                    if(user != null) {
                       // 2. Buka Layar Buat PIN BARU (isVerifying: false, allowBiometric: false)
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PinInputScreen(userId: user.uid, isVerifying: false, allowBiometric: false))
                      );
                    }
                  } else {
                    NotifService.showError("Password Salah!");
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                child: isVerifyingPass 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Lanjut"),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- LOGIKA 2: AKTIFKAN BIOMETRIK ---
  void _toggleBio(bool val) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    if (val) {
      // === MAU MENGAKTIFKAN ===
      
      setState(() => _isLoading = true);

      // 1. Cek PIN Aplikasi sudah diatur? (Wajib)
      String? storedPin = await _dbService.getUserPin(user.uid);
      if (storedPin == null) {
        setState(() => _isBioEnabled = false);
        NotifService.showWarning("Atur PIN terlebih dahulu sebelum mengaktifkan biometrik!");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Verifikasi PIN (Keamanan Ganda sebelum aktivasi)
      if (!mounted) return;
      // PENTING: allowBiometric = false agar tombol sidik jari tidak muncul
      bool pinVerified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinInputScreen(userId: user.uid, isVerifying: true, allowBiometric: false)),
      ) ?? false;

      if (!pinVerified) {
        setState(() => _isBioEnabled = false);
        NotifService.showError("PIN Salah. Gagal mengaktifkan.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      // 3. Test Scan Jari (Inilah proses "Daftar/Aktifasi" ke aplikasi)
      bool bioSuccess = await _localAuth.authenticateBiometric(reason: "Scan sidik jari yang terdaftar di HP untuk aktivasi");
      
      if (bioSuccess) {
        try {
          await FirebaseDatabase.instance.ref('users/${user.uid}').update({'isBiometricEnabled': true});
          
          if (!mounted) return;
          setState(() {
            _isBioEnabled = true;
            _isLoading = false;
          });
          NotifService.showSuccess("Sidik Jari Berhasil Diaktifkan!", title: "Sukses");
        } catch (e) {
          setState(() {
            _isBioEnabled = false;
            _isLoading = false;
          });
          NotifService.showError("Gagal menyimpan pengaturan: $e");
        }
      } else {
        setState(() {
          _isBioEnabled = false;
          _isLoading = false;
        });
        NotifService.showError("Verifikasi sidik jari gagal/dibatalkan.");
      }

    } else {
      // === MAU MENONAKTIFKAN ===
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        await FirebaseDatabase.instance.ref('users/${user.uid}').update({'isBiometricEnabled': false});
        setState(() {
          _isBioEnabled = false;
          _isLoading = false;
        });
        NotifService.showSuccess("Biometrik Dinonaktifkan");
      } catch (e) {
        setState(() => _isLoading = false);
        NotifService.showError("Gagal menonaktifkan.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Keamanan Akun", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("PIN Keamanan"),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.blue),
                    ),
                    title: const Text("Ubah / Atur PIN", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Memerlukan Password Akun untuk mengubah PIN", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _changePinFlow,
                  ),
                ),

                const SizedBox(height: 30),

                _buildSectionHeader("Biometrik"),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        activeColor: const Color(0xFFE91E63),
                        title: const Text("Sidik Jari / Wajah", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Login & Bayar lebih cepat", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.fingerprint, color: Colors.green),
                        ),
                        value: _isBioEnabled,
                        onChanged: _isLoading ? null : _toggleBio,
                      ),
                      
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _isBioEnabled 
                                    ? "Sidik jari Anda sudah terhubung ke aplikasi."
                                    : "Fitur ini memerlukan PIN dan Sidik Jari terdaftar di Pengaturan HP Anda.",
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE91E63)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(), 
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1)
    );
  }
}