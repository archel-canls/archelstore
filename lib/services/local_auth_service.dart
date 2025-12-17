import 'dart:convert'; // Tambahan
import 'package:crypto/crypto.dart'; // Tambahan
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'notif_service.dart';
import 'db_service.dart';

class LocalAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DbService _dbService = DbService();

  // --- HELPER HASHING (Harus sama persis dengan DbService) ---
  String _hashPin(String pin, String uid) {
    const String staticSalt = "PinSaltArchel"; 
    String dynamicSalt = uid.length > 5 ? uid.substring(0, 5) : uid;
    
    String rawData = "$pin$staticSalt$dynamicSalt";
    return sha256.convert(utf8.encode(rawData)).toString();
  }

  // Cek ketersediaan hardware biometrik
  Future<bool> get canCheckBiometrics async {
    try {
      return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      NotifService.showError('Error Biometrik: ${e.message}');
      return false;
    }
  }

  // Proses Scan Sidik Jari ASLI (Enkripsi Hardware ditangani OS)
  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Auth Error: $e');
      if (e.code == auth_error.notAvailable || e.code == auth_error.notEnrolled) {
         NotifService.showError("Sidik jari tidak tersedia atau belum didaftarkan di HP ini.");
      }
      return false;
    }
  }
  
  // Verifikasi PIN Aplikasi (Hash Input vs Hash Database)
  Future<bool> verifyAppPin(String userId, String enteredPin) async {
    // Ambil Hash yang tersimpan di DB
    String? storedHash = await _dbService.getUserPin(userId);
    
    if (storedHash == null) {
       NotifService.showWarning("PIN keamanan belum diatur.");
       return false;
    }

    // Hash input user saat ini dengan rumus yang sama
    String enteredHash = _hashPin(enteredPin, userId);

    // Bandingkan Hash
    return storedHash == enteredHash;
  }
}