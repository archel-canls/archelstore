import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    if (user == null) return const SizedBox();

    // Referensi ke node notifikasi user ini
    final ref = FirebaseDatabase.instance.ref('notifications/${user.uid}');

    return Scaffold(
      appBar: AppBar(title: const Text("Notifikasi")),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Belum ada notifikasi", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Konversi Data Map ke List
          Map data = snapshot.data!.snapshot.value as Map;
          List<NotificationModel> notifs = [];
          data.forEach((key, value) {
            notifs.add(NotificationModel.fromMap(key, value));
          });

          // Urutkan dari yang terbaru (timestamp descending)
          notifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: notifs.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final n = notifs[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.type == 'saldo' 
                      ? (n.title.contains("Berkurang") ? Colors.red[100] : Colors.green[100])
                      : Colors.blue[100],
                  child: Icon(
                    n.type == 'saldo' ? Icons.account_balance_wallet : Icons.shopping_bag,
                    color: n.type == 'saldo' 
                      ? (n.title.contains("Berkurang") ? Colors.red : Colors.green)
                      : Colors.blue,
                  ),
                ),
                title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: col(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(n.body, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM HH:mm').format(n.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
  
  // Helper widget column simple
  Widget col({required CrossAxisAlignment crossAxisAlignment, required List<Widget> children}) {
    return Column(crossAxisAlignment: crossAxisAlignment, children: children);
  }
}