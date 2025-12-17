import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/notif_service.dart';
import '../../widgets/custom_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  File? _imageFile;
  String? _currentPhotoUrl; // Ini akan berisi String Base64 jika dari DB
  bool _isLoading = false;
  final DbService _dbService = DbService();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _nameCtrl.text = user.nama;
      _phoneCtrl.text = user.phoneNumber ?? "";
      _currentPhotoUrl = user.photoUrl;
    }
  }

  // Pilih Gambar & Kompresi
  Future<void> _pickImage() async {
    // Kurangi kualitas agar Base64 tidak terlalu panjang untuk RTDB
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 25);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? photoBase64;

      // Konversi Gambar ke Base64 (Tanpa Storage)
      if (_imageFile != null) {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        photoBase64 = base64Encode(imageBytes);
      }

      await _dbService.updateUserProfile(
        user.uid,
        nama: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        photoBase64: photoBase64, // Kirim Base64 ke DB
      );

      if (!mounted) return;
      NotifService.showSuccess("Profil berhasil diperbarui!");
      Navigator.pop(context);

    } catch (e) {
      NotifService.showError("Gagal update profil: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper untuk menampilkan gambar (Base64 atau Asset)
  ImageProvider _getImageProvider() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      try {
        // Cek apakah ini URL (Legacy) atau Base64
        if (_currentPhotoUrl!.startsWith("http")) {
          return NetworkImage(_currentPhotoUrl!);
        } else {
          return MemoryImage(base64Decode(_currentPhotoUrl!));
        }
      } catch (e) {
        return const AssetImage("assets/default_profile.png"); // Fallback
      }
    }
    return const AssetImage("assets/default_profile.png"); // Fallback jika null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                      image: DecorationImage(
                        image: _getImageProvider(),
                        fit: BoxFit.cover,
                        onError: (e, s) => const Icon(Icons.error), // Handle error rendering
                      ),
                    ),
                    // Jika tidak ada gambar, tampilkan icon person
                    child: (_imageFile == null && (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty))
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.black87),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Nama Lengkap",
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Nomor Telepon",
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 40),
            CustomButton(text: "SIMPAN PERUBAHAN", isLoading: _isLoading, onPressed: _saveProfile),
          ],
        ),
      ),
    );
  }
}