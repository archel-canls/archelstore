// screens/admin/manage_users_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/user_model.dart';
import '../../services/notif_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('users');
  String _searchQuery = "";

  // Fungsi Hapus User
  void _deleteUser(String uid, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Pengguna"),
        content: Text("Yakin ingin menghapus akun '$username'? Data tidak bisa dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _ref.child(uid).remove().then((_) {
                Navigator.pop(ctx);
                NotifService.showSuccess("User berhasil dihapus");
              });
            },
            child: const Text("Hapus"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen User")),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Cari username...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          // User List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _ref.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("Belum ada user terdaftar"));
                }

                Map<dynamic, dynamic> map = snapshot.data!.snapshot.value as Map;
                List<UserModel> users = [];

                // Konversi Map ke List Model & Filter
                map.forEach((key, value) {
                  UserModel user = UserModel.fromMap(value);
                  // Jangan tampilkan Admin di list hapus & filter search
                  if (user.role != 'admin' && user.username.toLowerCase().contains(_searchQuery)) {
                    users.add(user);
                  }
                });

                if (users.isEmpty) {
                  return const Center(child: Text("User tidak ditemukan"));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (ctx, i) {
                    final user = users[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: Text(user.nama[0].toUpperCase()),
                        ),
                        title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(user.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteUser(user.uid, user.username),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}