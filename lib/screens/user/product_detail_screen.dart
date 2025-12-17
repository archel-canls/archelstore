// screens/user/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Wajib untuk Keranjang

import '../../models/product_model.dart';
import '../../services/auth_service.dart';
import '../../services/notif_service.dart';
import 'checkout_sidebar.dart'; 

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  // Logika Menambahkan/Mengupdate Item ke Keranjang
  Future<void> _addToCart(String uid, ProductModel product, BuildContext context) async {
    final cartRef = FirebaseDatabase.instance.ref('users/$uid/cart/${product.id}');
    
    // Ambil kuantitas saat ini
    DataSnapshot snapshot = await cartRef.get();
    int currentQty = snapshot.exists ? int.parse(snapshot.value.toString()) : 0;
    
    // Pengecekan Stok sebelum menambah
    if (currentQty + 1 > product.stock) {
      NotifService.showWarning("Stok maksimal (${product.stock}) telah tercapai!");
      return;
    }
    
    await cartRef.set(currentQty + 1);
    NotifService.showSuccess("${product.nama} ditambahkan ke keranjang!");
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final user = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(product.coverUrl, fit: BoxFit.cover),
            ),
            leading: const BackButton(color: Colors.black),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmt.format(product.harga), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                      Text("Stok: ${product.stock}", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(product.nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),
                  const Text("Deskripsi", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.deskripsi, style: const TextStyle(height: 1.5, color: Colors.black87)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: user != null ? () => _addToCart(user.uid, product, context) : null,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Color(0xFFE91E63))),
                child: const Text("KERANJANG", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (user != null) {
                    CheckoutSidebar.show(context, product, user.uid);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text("BELI SEKARANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}