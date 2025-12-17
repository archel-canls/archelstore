import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../services/db_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/notif_service.dart';

class PinInputScreen extends StatefulWidget {
  final String userId;
  final bool isVerifying; // True = Cek PIN, False = Buat PIN Baru
  final bool allowBiometric; // [BARU] False jika sedang proses aktivasi sidik jari

  const PinInputScreen({
    super.key, 
    required this.userId, 
    this.isVerifying = true,
    this.allowBiometric = true, // Default boleh pakai sidik jari (kecuali diset false)
  });

  @override
  State<PinInputScreen> createState() => _PinInputScreenState();
}

class _PinInputScreenState extends State<PinInputScreen> {
  final LocalAuthService _localAuth = LocalAuthService();
  final DbService _dbService = DbService();
  final TextEditingController _pinController = TextEditingController();
  
  bool _isLoading = false;
  bool _canUseBiometric = false;
  
  // Variabel untuk Mode Buat PIN
  String? _firstPinInput; 
  String _titleText = "";
  String _subTitleText = "";

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _updateTexts();
  }

  void _updateTexts() {
    setState(() {
      if (widget.isVerifying) {
        _titleText = "Verifikasi PIN";
        _subTitleText = "Masukkan PIN keamanan Anda";
      } else {
        if (_firstPinInput == null) {
          _titleText = "Buat PIN Baru";
          _subTitleText = "Lindungi akun dengan 6 digit angka";
        } else {
          _titleText = "Konfirmasi PIN";
          _subTitleText = "Masukkan ulang PIN sekali lagi";
        }
      }
    });
  }

  void _checkBiometricAvailability() async {
    // Hanya cek hardware jika allowBiometric TRUE
    if (widget.allowBiometric) {
      bool available = await _localAuth.canCheckBiometrics;
      if (mounted) setState(() => _canUseBiometric = available);
    }
  }

  Future<void> _triggerBiometric() async {
    bool authenticated = await _localAuth.authenticateBiometric(reason: "Verifikasi Cepat");
    if (authenticated) {
      if(!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _onSubmit(String pin) async {
    _pinController.clear(); 

    if (widget.isVerifying) {
      // --- MODE VERIFIKASI ---
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 800)); // Animasi loading

      bool valid = await _localAuth.verifyAppPin(widget.userId, pin);
      
      setState(() => _isLoading = false);

      if (valid) {
        if (!mounted) return;
        Navigator.pop(context, true); 
      } else {
        NotifService.showError("PIN Salah! Silakan coba lagi.");
      }
    } else {
      // --- MODE BUAT PIN BARU ---
      if (_firstPinInput == null) {
        setState(() {
          _firstPinInput = pin;
          _updateTexts();
        });
      } else {
        if (pin == _firstPinInput) {
          setState(() => _isLoading = true);
          await Future.delayed(const Duration(seconds: 1)); 

          try {
            await _dbService.setUserPin(widget.userId, pin);
            setState(() => _isLoading = false);
            
            if (!mounted) return;
            NotifService.showSuccess("PIN Berhasil Dibuat!");
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.pop(context, true); 
          } catch (e) {
            setState(() {
              _isLoading = false;
              _firstPinInput = null;
              _updateTexts();
            });
            NotifService.showError("Gagal menyimpan: $e");
          }
        } else {
          NotifService.showError("PIN tidak cocok! Ulangi.");
          setState(() {
            _firstPinInput = null;
            _updateTexts();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56, height: 56,
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
      decoration: BoxDecoration(
        color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Keamanan"),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.white, foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isLoading 
              ? const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE91E63)),
                    SizedBox(height: 20),
                    Text("Memproses...", style: TextStyle(color: Colors.grey)),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFFE91E63).withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(
                        widget.isVerifying ? Icons.lock_outline : Icons.security,
                        size: 50, color: const Color(0xFFE91E63)
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(_titleText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_subTitleText, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    
                    Pinput(
                      length: 6,
                      controller: _pinController,
                      obscureText: true,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: defaultPinTheme.copyDecorationWith(
                        border: Border.all(color: const Color(0xFFE91E63), width: 2), color: Colors.white,
                      ),
                      onCompleted: _onSubmit,
                      enabled: !_isLoading,
                      autofocus: true,
                    ),
                  ],
                ),

              const SizedBox(height: 40),

              // [LOGIKA TOMBOL]
              // Tombol hanya muncul jika:
              // 1. Sedang Verifikasi (Bukan buat baru)
              // 2. Tidak sedang loading
              // 3. allowBiometric == TRUE (Artinya bukan lagi proses aktivasi)
              // 4. HP Support Biometrik
              if (!_isLoading && widget.isVerifying && widget.allowBiometric && _canUseBiometric)
                TextButton.icon(
                  onPressed: _triggerBiometric,
                  icon: const Icon(Icons.fingerprint, size: 28, color: Color(0xFFE91E63)),
                  label: const Text("Gunakan Sidik Jari", style: TextStyle(fontSize: 16, color: Color(0xFFE91E63))),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}