// lib/screens/user/voucher_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/notif_service.dart';


class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final DbService _dbService = DbService();
  bool _isLoading = false;

  // Fungsi Beli VIP
  Future<void> _purchaseVip(String uid, double currentCoin) async {
    setState(() => _isLoading = true);
    try {
      await _dbService.buyVip(uid, currentCoin);
      NotifService.showSuccess("Berhasil Upgrade ke VIP!");
    } catch (e) {
      NotifService.showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    if (user == null) return const SizedBox();

    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Voucher & Keanggotaan")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Banner Status VIP
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: user.isVip 
                  ? const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFFFD700)])
                  : LinearGradient(colors: [Colors.grey.shade800, Colors.black87]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(user.isVip ? "VIP MEMBER" : "REGULER MEMBER", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Icon(user.isVip ? Icons.workspace_premium : Icons.lock, color: Colors.white, size: 30),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!user.isVip) ...[
                    const Text(
                      "Upgrade ke VIP seharga Rp 10.000 (Arc Coin) untuk mendapatkan voucher eksklusif otomatis!",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _purchaseVip(user.uid, user.arcCoin),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text("BELI VIP SEKARANG"),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text("Saldo Anda: ${fmt.format(user.arcCoin)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ] else 
                    const Text("Nikmati voucher eksklusif Anda di bawah ini.", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // 2. Daftar Voucher (Hanya muncul jika VIP)
            const Align(alignment: Alignment.centerLeft, child: Text("Voucher Saya", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            Expanded(
              child: !user.isVip 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_outline, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Voucher terkunci. Silakan upgrade VIP.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : StreamBuilder<DatabaseEvent>(
                    stream: _dbService.getUserVouchers(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                        return const Center(child: Text("Belum ada voucher tersedia."));
                      }

                      Map data = snapshot.data!.snapshot.value as Map;
                      List<Map> vouchers = [];
                      data.forEach((key, value) {
                        vouchers.add({...value, 'key': key});
                      });

                      return ListView.builder(
                        itemCount: vouchers.length,
                        itemBuilder: (ctx, i) {
                          final v = vouchers[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 100,
                            child: Stack(
                              children: [
                                // Background Voucher
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                                  ),
                                  child: Row(
                                    children: [
                                      // Bagian Kiri (Potongan)
                                      Container(
                                        width: 100,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE91E63),
                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.confirmation_number, color: Colors.white, size: 40),
                                        ),
                                      ),
                                      // Bagian Kanan (Info)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(v['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text(v['subtitle'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                              const Spacer(),
                                              Text("Gunakan saat Checkout", style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}