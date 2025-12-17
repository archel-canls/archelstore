import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../services/db_service.dart';
import '../../services/notif_service.dart';

class ManageTopUpScreen extends StatelessWidget {
  const ManageTopUpScreen({super.key});

  // Fungsi Setujui
  Future<void> _approveTopUp(String reqId, String uid, double amount) async {
    final DbService db = DbService();
    await FirebaseDatabase.instance.ref('topup_requests/$reqId').update({'status': 'success'});
    
    // Ambil saldo lama
    final userSnap = await FirebaseDatabase.instance.ref('users/$uid/arcCoin').get();
    double oldBalance = userSnap.exists ? double.parse(userSnap.value.toString()) : 0;
    
    // Tambah saldo
    await db.updateUserSaldo(uid, oldBalance + amount, reason: "Top Up QRIS Disetujui");
    NotifService.showSuccess("Top Up Disetujui");
  }

  // Fungsi Tolak
  Future<void> _rejectTopUp(String reqId) async {
    await FirebaseDatabase.instance.ref('topup_requests/$reqId').update({'status': 'rejected'});
    NotifService.showWarning("Permintaan Ditolak");
  }

  // Popup Lihat Gambar Bukti
  void _showProofDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text("Bukti Transfer"), 
              leading: const CloseButton(),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            InteractiveViewer( // Agar bisa di-zoom
              child: Image.network(
                imageUrl, 
                loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (c, o, s) => const SizedBox(height: 200, child: Center(child: Text("Gagal memuat gambar"))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('topup_requests');
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi Top Up")),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.orderByChild('status').equalTo('pending').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("Tidak ada permintaan baru"));
          }

          Map map = snapshot.data!.snapshot.value as Map;
          List<MapEntry> list = map.entries.toList();

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              String reqId = list[i].key;
              Map data = list[i].value;
              String proofUrl = data['proofUrl'] ?? ''; // URL Bukti
              
              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.attach_money, color: Colors.green, size: 40),
                      title: Text(data['username'] ?? 'User'),
                      subtitle: Text("${fmt.format(data['amount'])}\n${data['timestamp'].toString().substring(0,16)}"),
                    ),
                    
                    // Tombol Lihat Bukti
                    if (proofUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showProofDialog(context, proofUrl),
                            icon: const Icon(Icons.image),
                            label: const Text("LIHAT BUKTI TRANSFER"),
                          ),
                        ),
                      ),

                    // Tombol Aksi
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _rejectTopUp(reqId),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text("Tolak"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _approveTopUp(reqId, data['uid'], double.parse(data['amount'].toString())),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text("Terima"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}