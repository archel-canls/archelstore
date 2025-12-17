import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Imports
import '../../models/product_model.dart';
import '../../services/notif_service.dart';
import 'manage_topup_screen.dart'; // Import halaman TopUp

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('products');
  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  String _cat = "Semua";

  // Warna Tema
  final Color primaryColor = const Color(0xFFE91E63);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- DIALOG: TAMBAH / EDIT BARANG ---
  void _showProductDialog({ProductModel? product}) {
    final bool isEdit = product != null;
    final nameCtrl = TextEditingController(text: isEdit ? product.nama : "");
    final priceCtrl = TextEditingController(text: isEdit ? product.harga.toInt().toString() : "");
    final stockCtrl = TextEditingController(text: isEdit ? product.stock.toString() : "");
    final descCtrl = TextEditingController(text: isEdit ? product.deskripsi : "");
    final imgCtrl = TextEditingController(text: isEdit ? product.coverUrl : "");
    String cat = isEdit ? product.category : "Elektronik";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEdit ? "Edit Barang" : "Tambah Barang Baru", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(nameCtrl, "Nama Barang", Icons.shopping_bag),
                  const SizedBox(height: 10),
                  _buildTextField(priceCtrl, "Harga (Angka)", Icons.attach_money, isNumber: true),
                  const SizedBox(height: 10),
                  _buildTextField(stockCtrl, "Stok", Icons.inventory, isNumber: true),
                  const SizedBox(height: 10),
                  _buildTextField(imgCtrl, "URL Gambar", Icons.image),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    value: cat,
                    items: ["Elektronik", "Pakaian", "Makanan", "Hobi", "Umum"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => cat = v.toString()),
                    decoration: InputDecoration(
                      labelText: "Kategori",
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(descCtrl, "Deskripsi", Icons.description, maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Batal", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                onPressed: () {
                  if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                    NotifService.showError("Nama dan Harga wajib diisi!");
                    return;
                  }
                  
                  // Simpan / Update ke Firebase
                  if (isEdit) {
                    _ref.child(product.id).update({
                      'nama': nameCtrl.text,
                      'harga': int.parse(priceCtrl.text),
                      'stock': int.parse(stockCtrl.text.isEmpty ? "0" : stockCtrl.text),
                      'deskripsi': descCtrl.text,
                      'coverUrl': imgCtrl.text.isEmpty ? 'https://placehold.co/400' : imgCtrl.text,
                      'category': cat,
                    });
                    NotifService.showSuccess("Barang diperbarui");
                  } else {
                    String id = _ref.push().key!;
                    _ref.child(id).set({
                      'nama': nameCtrl.text,
                      'harga': int.parse(priceCtrl.text),
                      'stock': int.parse(stockCtrl.text.isEmpty ? "0" : stockCtrl.text),
                      'deskripsi': descCtrl.text,
                      'coverUrl': imgCtrl.text.isEmpty ? 'https://placehold.co/400' : imgCtrl.text,
                      'category': cat,
                      'terjual': 0,
                    });
                    NotifService.showSuccess("Barang ditambahkan");
                  }
                  
                  Navigator.pop(ctx);
                },
                child: Text(isEdit ? "Simpan Perubahan" : "Tambah Barang"),
              )
            ],
          );
        }
      ),
    );
  }

  TextField _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }

  // --- DIALOG: HAPUS BARANG ---
  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: Text("Barang '$name' akan dihapus permanen dari database."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: (){
              _ref.child(id).remove();
              Navigator.pop(c);
              NotifService.showSuccess("Barang dihapus");
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
            child: const Text("Hapus")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // =========================================
            // 1. HEADER (SEARCH + TOP UP BTN)
            // =========================================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              color: Colors.white,
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: "Cari nama barang...",
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  
                  // Tombol Top Up Verification (Estetik)
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTopUpScreen())),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.monetization_on_outlined, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),

            // =========================================
            // 2. KATEGORI FILTER
            // =========================================
            Container(
              color: Colors.white,
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                children: ["Semua", "Elektronik", "Pakaian", "Makanan", "Hobi"].map((c) {
                  final bool isSelected = _cat == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() => _cat = c),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black54,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // =========================================
            // 3. LIST PRODUK (GRID)
            // =========================================
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _ref.onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return _buildEmptyState();
                  }

                  Map map = snapshot.data!.snapshot.value as Map;
                  List<ProductModel> products = [];
                  
                  map.forEach((k, v) {
                    ProductModel p = ProductModel.fromMap(k, v);
                    // Filter Logic
                    bool matchCat = _cat == "Semua" || p.category == _cat;
                    bool matchSearch = p.nama.toLowerCase().contains(_searchQuery);

                    if (matchCat && matchSearch) products.add(p);
                  });

                  if (products.isEmpty) return _buildEmptyState();

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      childAspectRatio: 0.68, // Sedikit lebih panjang untuk tombol aksi
                      mainAxisSpacing: 16, 
                      crossAxisSpacing: 16
                    ),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) => _buildAdminProductCard(products[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- WIDGET: KARTU PRODUK ADMIN ---
  Widget _buildAdminProductCard(ProductModel p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.network(
                    p.coverUrl, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (c,o,s) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
                // Badge Kategori
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: Text(p.category, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          
          // Info & Aksi
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(fmt.format(p.harga), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 12)),
                Text("Stok: ${p.stock}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                
                // Tombol Aksi (Edit & Hapus)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showProductDialog(product: p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.edit, size: 18, color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _confirmDelete(p.id, p.nama),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete, size: 18, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Produk tidak ditemukan", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}