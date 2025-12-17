import 'dart:convert'; // Wajib untuk Base64 Decode
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Wajib untuk StreamBuilder
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notif_service.dart';
import '../auth/login_screen.dart';
import '../user/security_settings_screen.dart';
import 'edit_profile_screen.dart'; 
import 'voucher_screen.dart';     

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openWhatsApp(String username) async {
    final msg = "Halo Admin ArchelStore, saya $username butuh bantuan...";
    final url = "https://wa.me/62895617352225?text=${Uri.encodeComponent(msg)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      NotifService.showError("Tidak dapat membuka WhatsApp.");
    }
  }

  // Helper untuk menampilkan gambar (Support Base64 & Network)
  ImageProvider? _getProfileImage(String? photoData) {
    if (photoData == null || photoData.isEmpty) return null;
    try {
      if (photoData.startsWith("http")) {
        // Support URL lama (jika ada)
        return NetworkImage(photoData);
      } else {
        // Decode Base64 dari RTDB (Format Baru)
        return MemoryImage(base64Decode(photoData));
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil UID user yang sedang login
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Reference langsung ke data user di database
    final userRef = FirebaseDatabase.instance.ref('users/$uid');
    const primaryColor = Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      // [PERBAIKAN UTAMA] Menggunakan StreamBuilder agar update DETIK ITU JUGA
      body: StreamBuilder<DatabaseEvent>(
        stream: userRef.onValue,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error/Empty State
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Data profil tidak ditemukan"));
          }

          // 3. Konversi Data ke UserModel
          final data = snapshot.data!.snapshot.value as Map;
          final user = UserModel.fromMap(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ===========================================
                // 1. HEADER PROFIL (FOTO & NAMA)
                // ===========================================
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isVip ? Colors.amber : primaryColor.withOpacity(0.5), 
                          width: 3
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        // Gunakan helper image provider
                        backgroundImage: _getProfileImage(user.photoUrl),
                        // Jika tidak ada gambar, tampilkan Icon Person
                        child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.nama,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // ===========================================
                // 2. KARTU STATUS VIP (Estetik)
                // ===========================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: user.isVip
                        ? const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFFFD700)])
                        : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade100]),
                    boxShadow: [
                      BoxShadow(
                        color: user.isVip ? Colors.amber.withOpacity(0.4) : Colors.black12, 
                        blurRadius: 10, 
                        offset: const Offset(0, 5)
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                        child: Icon(Icons.workspace_premium, size: 36, color: user.isVip ? Colors.white : Colors.grey[600]),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.isVip ? "VIP MEMBER AKTIF" : "MEMBER REGULER",
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 1, 
                                color: user.isVip ? Colors.white : Colors.grey[800]
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (user.isVip && user.vipExpiryDate != null)
                              Text(
                                "Berlaku s/d: ${DateFormat('dd MMM yyyy').format(DateTime.parse(user.vipExpiryDate!))}",
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              )
                            else if (!user.isVip)
                              Text(
                                "Upgrade sekarang untuk diskon & voucher!",
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ===========================================
                // 3. MENU PENGATURAN
                // ===========================================
                const Align(
                  alignment: Alignment.centerLeft, 
                  child: Text("Pengaturan Akun", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: 15),
                
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      // EDIT PROFIL
                      _buildSettingsTile(
                        icon: Icons.edit, color: Colors.orange, title: "Edit Profil",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      ),
                      const Divider(height: 1),
                      
                      // VOUCHER
                      _buildSettingsTile(
                        icon: Icons.confirmation_number_outlined, color: Colors.blueAccent, title: "ARC VIP",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherScreen())),
                      ),
                      const Divider(height: 1),
                      
                      // KEAMANAN
                      _buildSettingsTile(
                        icon: Icons.security, color: primaryColor, title: "Keamanan (PIN & Biometrik)",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
                      ),
                      const Divider(height: 1),
                      
                      // BANTUAN
                      _buildSettingsTile(
                        icon: Icons.help_outline, color: Colors.green, title: "Pusat Bantuan (WhatsApp)",
                        onTap: () => _openWhatsApp(user.username),
                      ),
                      const Divider(height: 1),
                      
                      // LOGOUT
                      _buildSettingsTile(
                        icon: Icons.logout, color: Colors.red, title: "Keluar Akun", isDestructive: true,
                        onTap: () async {
                          await authService.logout();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (Route<dynamic> route) => false
                          );
                          NotifService.showSuccess("Berhasil Keluar");
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  // Widget Helper untuk Item Menu
  Widget _buildSettingsTile({
    required IconData icon, 
    required Color color, 
    required String title, 
    required VoidCallback onTap, 
    bool isDestructive = false
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w600, 
          color: isDestructive ? Colors.red : Colors.black87
        )
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}