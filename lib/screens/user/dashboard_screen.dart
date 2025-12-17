import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Imports Services & Models
import '../../services/auth_service.dart';
import '../../models/product_model.dart';

// Imports Screens
import 'cart_screen.dart'; 
import 'notification_screen.dart';
import 'topup_screen.dart';
import 'product_detail_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _searchCtrl = TextEditingController();
  
  String _cat = "Semua"; 
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Menggunakan Consumer agar data User (Saldo/VIP) selalu update
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        
        const primaryColor = Color(0xFFE91E63);
        const secondaryColor = Color(0xFFC2185B);
        
        if (user == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            child: Column(
              children: [
                // =========================================
                // 1. HEADER (SEARCH & ICONS)
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
                              hintText: "Cari produk...",
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      
                      // Cart Icon
                      _buildIconButton(
                        icon: Icons.shopping_cart_outlined,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                      ),
                      const SizedBox(width: 10),
                      
                      // Notif Icon
                      _buildIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                      ),
                    ],
                  ),
                ),

                // =========================================
                // 2. SALDO CARD & VIP STATUS
                // =========================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
                      ]
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                                const SizedBox(width: 5),
                                const Text("Saldo Arc Coin", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fmt.format(user.arcCoin), 
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white54)
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text("Isi Saldo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),

                        // VIP Badge
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: user.isVip 
                                ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFDAA520)]) 
                                : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600]), 
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)]
                            ),
                            child: Row(
                              children: [
                                Icon(user.isVip ? Icons.workspace_premium : Icons.lock, size: 14, color: user.isVip ? Colors.black87 : Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  user.isVip ? "VIP MEMBER" : "REGULER",
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w900, 
                                    color: user.isVip ? Colors.black87 : Colors.white
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // =========================================
                // 3. KATEGORI FILTER
                // =========================================
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    children: ["Semua", "Elektronik", "Pakaian", "Makanan", "Hobi"].map((c) {
                      final bool isSelected = _cat == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => setState(() => _cat = c),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                              boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 5)] : []
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
                // 4. LIST PRODUK (GRID + REALTIME RATING)
                // =========================================
                Expanded(
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance.ref('products').onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                        return _buildEmptyState();
                      }

                      Map map = snapshot.data!.snapshot.value as Map;
                      List<Map<String, dynamic>> displayedProducts = [];
                      
                      map.forEach((k, v) {
                        ProductModel p = ProductModel.fromMap(k, v);
                        
                        // -- FILTER LOGIC --
                        bool matchCat = _cat == "Semua" || p.category == _cat;
                        bool matchSearch = p.nama.toLowerCase().contains(_searchQuery);

                        if (matchCat && matchSearch) {
                          // -- HITUNG RATING REALTIME --
                          // Ambil data rating langsung dari map raw JSON
                          double ratingTotal = double.tryParse((v['ratingTotal'] ?? 0).toString()) ?? 0.0;
                          int ratingCount = int.tryParse((v['ratingCount'] ?? 0).toString()) ?? 0;
                          
                          // Rumus Rata-rata
                          double avgRating = ratingCount > 0 ? (ratingTotal / ratingCount) : 0.0;

                          displayedProducts.add({
                            'product': p,
                            'rating': avgRating
                          });
                        }
                      });

                      if (displayedProducts.isEmpty) {
                        return _buildEmptyState();
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          childAspectRatio: 0.70, 
                          mainAxisSpacing: 15, 
                          crossAxisSpacing: 15
                        ),
                        itemCount: displayedProducts.length,
                        itemBuilder: (ctx, i) {
                          return _buildProductItem(
                            context, 
                            displayedProducts[i]['product'] as ProductModel,
                            displayedProducts[i]['rating'] as double
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET BUILDER: PRODUCT CARD ---
  Widget _buildProductItem(BuildContext context, ProductModel product, double rating) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Produk
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  children: [
                    Image.network(
                      product.coverUrl, 
                      width: double.infinity, 
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                    if(product.stock < 5)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                        child: const Text("Stok Menipis!", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            // Info Produk
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.nama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  
                  Text(
                    fmt.format(product.harga),
                    style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Rating & Terjual
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      // Tampilkan Rating (1 angka di belakang koma) atau "Baru" jika 0
                      Text(
                        " ${rating > 0 ? rating.toStringAsFixed(1) : 'Baru'}", 
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(width: 5),
                      Container(width: 1, height: 10, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        "${product.terjual} Terjual", 
                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text("Produk tidak ditemukan", style: TextStyle(color: Colors.grey)),
        ],
      )
    );
  }
}