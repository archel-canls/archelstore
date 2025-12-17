import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart'; // Tetap pakai QuickAlert untuk popup besar

// Global Key untuk mengakses ScaffoldMessenger tanpa Context
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class NotifService {
  // Fungsi helper untuk menampilkan SnackBar
  static void _showSnackBar(String msg, Color color, IconData icon) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Pengganti Toast Biasa
  static void showToast(String msg) {
    _showSnackBar(msg, Colors.black87, Icons.info_outline);
  }

  // Menampilkan Error (Merah)
  static void showError(String msg) {
    _showSnackBar(msg, Colors.red, Icons.error_outline);
  }

  // Menampilkan Peringatan (Kuning/Oranye)
  static void showWarning(String msg) {
    _showSnackBar(msg, Colors.orange, Icons.warning_amber_rounded);
  }

  // Menampilkan Sukses (Hijau)
  static void showSuccess(String msg, {String? title}) {
    _showSnackBar(msg, Colors.green, Icons.check_circle_outline);
  }

  // Popup Besar (Alert) - QuickAlert
  static void showPopup(BuildContext context, String title, String text, QuickAlertType type) {
    QuickAlert.show(
      context: context,
      type: type,
      title: title,
      text: text,
      confirmBtnColor: const Color(0xFFE91E63),
      backgroundColor: Colors.white,
    );
  }
}