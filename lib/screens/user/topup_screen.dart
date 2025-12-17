import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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
  String? _proofPlaceholderUrl; 
  
  // URL untuk QRIS dan Placeholder Bukti Transfer
  final String qrisUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png"; 
  final String dummyProofUrl = "https://placehold.co/400x300/CCCCCC/000000/png?text=Bukti+Transfer+Simulasi"; 

  // Fungsi Simulasi Ambil Bukti (RTDB Only)
  Future<void> _pickImage() async {
    // Simulasi sukses "upload" dengan mendapatkan URL placeholder
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800)); // Animasi Loading
    
    setState(() {
      _proofPlaceholderUrl = dummyProofUrl;
      _isLoading = false;
    });
    NotifService.showToast("Simulasi: Bukti berhasil diambil.");
  }

  void _submitRequest() async {
    if (_amountCtrl.text.isEmpty) {
      NotifService.showError("Masukkan nominal!");
      return;
    }
    if (_proofPlaceholderUrl == null) {
      NotifService.showError("Wajib upload bukti transfer (Simulasi)!");
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
      DatabaseReference ref = FirebaseDatabase.instance.ref('topup_requests');
      String id = ref.push().key!;
      
      await ref.child(id).set({
        'uid': user!.uid,
        'username': user.username,
        'amount': amount,
        'proofUrl': _proofPlaceholderUrl, 
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if(!mounted) return;
      NotifService.showSuccess("Permintaan terkirim! Tunggu konfirmasi admin.");
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
            const Text("3. Upload Bukti Transfer (Simulasi)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Area Upload Gambar (Sekarang hanya menampilkan Placeholder)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                    : _proofPlaceholderUrl != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_proofPlaceholderUrl!, fit: BoxFit.cover))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                        Text("Tap untuk upload Screenshot (Simulasi)", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || _proofPlaceholderUrl == null) ? null : _submitRequest,
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