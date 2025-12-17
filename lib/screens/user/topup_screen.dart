import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Storage
import 'package:image_picker/image_picker.dart'; // Picker
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notif_service.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  File? _imageFile; // Menyimpan file gambar yang dipilih
  
  // GANTI URL INI DENGAN LINK GAMBAR QRIS GOPAY MERCHANT ANDA
  final String qrisUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png"; 

  // Fungsi Ambil Gambar dari Galeri
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _submitRequest() async {
    if (_amountCtrl.text.isEmpty) {
      NotifService.showError("Masukkan nominal!");
      return;
    }
    if (_imageFile == null) {
      NotifService.showError("Wajib upload bukti transfer!");
      return;
    }

    double amount = double.parse(_amountCtrl.text);
    if (amount < 10000) {
      NotifService.showError("Minimal Top Up Rp 10.000");
      return;
    }

    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    try {
      // 1. Upload Gambar ke Firebase Storage
      String fileName = "proof_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference storageRef = FirebaseStorage.instance.ref().child('topup_proofs/$fileName');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Simpan Data ke Database (Termasuk Link Bukti)
      DatabaseReference ref = FirebaseDatabase.instance.ref('topup_requests');
      String id = ref.push().key!;
      
      await ref.child(id).set({
        'uid': user!.uid,
        'username': user.username,
        'amount': amount,
        'proofUrl': downloadUrl, // <--- Link Gambar Disimpan
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if(!mounted) return;
      NotifService.showSuccess("Bukti terkirim! Tunggu konfirmasi admin.");
      Navigator.pop(context);

    } catch (e) {
      NotifService.showError("Gagal: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Isi Saldo (QRIS)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("1. Masukkan Nominal", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Nominal (Rp)",
                border: OutlineInputBorder(),
                prefixText: "Rp ",
              ),
            ),
            const SizedBox(height: 20),
            const Text("2. Scan & Transfer", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200, width: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
              child: Image.network(qrisUrl, fit: BoxFit.cover),
            ),
            
            const SizedBox(height: 20),
            const Text("3. Upload Bukti Transfer", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Area Upload Gambar
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _imageFile != null 
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                        Text("Tap untuk upload Screenshot", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("KIRIM BUKTI PEMBAYARAN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}