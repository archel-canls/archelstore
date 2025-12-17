import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
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
  
  // Timer Setup
  int _secondsRemaining = 300; // 5 Menit (300 detik)
  Timer? _timer;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _isExpired = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String get _timerText {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _verify() {
    if (_isExpired) {
      NotifService.showError("Kode OTP telah kadaluarsa. Silakan minta ulang.");
      return;
    }
    
    if (_pinController.text == widget.correctOtp) {
      _timer?.cancel();
      widget.onSuccess();
    } else {
      NotifService.showError("Kode OTP Salah! Cek kembali email Anda.");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tema Pin
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 50,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi OTP")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_clock, size: 60, color: Color(0xFFE91E63)),
            const SizedBox(height: 20),
            const Text(
              "Kode verifikasi dikirim ke:",
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              widget.email,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              "Sisa Waktu: $_timerText",
              style: TextStyle(
                color: _secondsRemaining < 60 ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 30),
            Pinput(
              length: 6,
              controller: _pinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(color: const Color(0xFFE91E63)),
                ),
              ),
              onCompleted: (pin) => _verify(),
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: _isExpired ? "WAKTU HABIS" : "VERIFIKASI",
              onPressed: _isExpired ? () => NotifService.showError("Waktu habis, silakan ulangi proses.") : _verify,
              isLoading: false, // Tambahkan properti ini di CustomButton jika belum ada, atau hapus baris ini
            ),
          ],
        ),
      ),
    );
  }
}