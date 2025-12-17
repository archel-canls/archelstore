import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Imports Wajib
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/notif_service.dart';
import '../../services/local_auth_service.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart'; 
import '../../widgets/custom_button.dart';
import '../security/pin_input_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DbService _dbService = DbService();
  final LocalAuthService _localAuth = LocalAuthService();
  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  bool _isLoading = false;
  
  // Variabel untuk menyimpan hasil perhitungan total
  double _totalPrice = 0;
  List<OrderItem> _cartItems = []; 
  
  String? get _userId => Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  bool get _isBioEnabled => Provider.of<AuthService>(context, listen: false).currentUser?.isBiometricEnabled ?? false;
  double get _userBalance => Provider.of<AuthService>(context, listen: false).currentUser?.arcCoin ?? 0;

  // --- LOGIKA UTAMA CHECKOUT ---
  Future<void> _processCheckout() async {
    if (_cartItems.isEmpty) {
      NotifService.showWarning("Keranjang Anda kosong!");
      return;
    }

    if (_userId == null) return;
    
    // 1. Cek Saldo
    if (_userBalance < _totalPrice) {
      NotifService.showError("Saldo Arc Coin tidak cukup!");
      return;
    }

    // 2. Verifikasi PIN/Biometrik
    bool isVerified = await _performVerification();
    if (!isVerified) return;

    // 3. Eksekusi Order
    await _executeOrder();
  }

  Future<bool> _performVerification() async {
    if (_userId == null) return false;

    String? storedPin = await _dbService.getUserPin(_userId!);
    if (storedPin == null) {
      NotifService.showWarning("PIN keamanan belum diatur. Silakan atur di Pengaturan.");
      return false;
    }

    bool verified = false;

    if (_isBioEnabled) {
      verified = await _localAuth.authenticateBiometric(reason: "Konfirmasi pembayaran keranjang");
    }

    if (!verified) {
      if (!mounted) return false;
      verified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinInputScreen(userId: _userId!, isVerifying: true, allowBiometric: _isBioEnabled)),
      ) ?? false;
    }

    return verified;
  }

  Future<void> _executeOrder() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500)); 

    try {
      await _dbService.createOrder(
        userId: _userId!, 
        items: _cartItems, 
        total: _totalPrice,
        paymentMethod: 'saldo', 
        voucherCode: null, 
      );
      
      await _dbService.updateUserSaldo(_userId!, _userBalance - _totalPrice);

      await FirebaseDatabase.instance.ref('users/${_userId!}/cart').remove();

      if (!mounted) return;
      NotifService.showSuccess("Checkout Berhasil!");
      Navigator.pop(context); 
    } catch (e) {
      NotifService.showError("Gagal Checkout: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA PERHITUNGAN TOTAL (STABIL) ---
  // Fungsi ini sekarang dipanggil ASYNCHRONOUSLY saat stream berubah, dan
  // hanya memanggil setState sekali di akhir, mencegah loop.
  Future<void> _calculateTotal(Map cartMap) async {
    if (_userId == null) return;
    
    double tempTotal = 0;
    List<OrderItem> tempItems = [];
    
    for(var key in cartMap.keys) {
      int q = int.parse(cartMap[key].toString());
      DataSnapshot pSnap = await FirebaseDatabase.instance.ref('products/$key').get();
      if(pSnap.exists) {
        ProductModel p = ProductModel.fromMap(key, pSnap.value as Map);
        tempTotal += p.harga * q;
        tempItems.add(OrderItem(productId: p.id, nama: p.nama, qty: q, price: p.harga, imageUrl: p.coverUrl));
      }
    }

    // Hanya panggil setState jika nilainya berubah atau ini adalah perhitungan pertama
    if(mounted && (_totalPrice != tempTotal || _cartItems.length != tempItems.length)) {
      setState(() {
        _totalPrice = tempTotal;
        _cartItems = tempItems;
      });
    }
  }

  // --- UI BUILDER (AESTHETICS) ---
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    if (user == null) return const SizedBox();

    final cartRef = FirebaseDatabase.instance.ref('users/${user.uid}/cart');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Keranjang Belanja", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: cartRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Pastikan _calculateTotal dipanggil saat data baru diterima
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    Map cartMap = snapshot.data!.snapshot.value as Map;
                    // Panggil fungsi perhitungan tanpa menunggu hasilnya, biarkan ia update state sendiri
                    // Ini jauh lebih stabil daripada memanggilnya di addPostFrameCallback
                    _calculateTotal(cartMap);

                    // Tampilkan List
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cartMap.length,
                      itemBuilder: (ctx, i) {
                        String pid = cartMap.keys.elementAt(i);
                        int qty = int.parse(cartMap.values.elementAt(i).toString());

                        // Menggunakan FutureBuilder untuk setiap item untuk fetch detail produk
                        return FutureBuilder<DataSnapshot>(
                          future: FirebaseDatabase.instance.ref('products/$pid').get(),
                          builder: (context, prodSnap) {
                            if (!prodSnap.hasData || !prodSnap.data!.exists) {
                              // Item Hilang/Loading, tampilkan loading kecil atau biarkan SizedBox
                              return const SizedBox(height: 10); 
                            }

                            ProductModel p = ProductModel.fromMap(pid, prodSnap.data!.value as Map);
                            
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(p.coverUrl, width: 70, height: 70, fit: BoxFit.cover),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.nama, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text(fmt.format(p.harga), style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                                          Text("Stok Tersisa: ${p.stock}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    // Tombol Kuantitas
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            if (qty > 1) {
                                              cartRef.child(pid).set(qty - 1);
                                            } else {
                                              cartRef.child(pid).remove();
                                            }
                                          },
                                        ),
                                        Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        IconButton(
                                          icon: Icon(Icons.add_circle_outline, color: qty < p.stock ? const Color(0xFFE91E63) : Colors.grey),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            if (qty < p.stock) {
                                              cartRef.child(pid).set(qty + 1);
                                            } else {
                                              NotifService.showWarning("Stok maksimal tercapai!");
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                }
                
                // Jika snapshot tidak ada data/kosong
                return const Center(child: Text("Keranjang Kosong. Yuk, belanja dulu!"));
              },
            ),
          ),
          
          // Footer Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Belanja", style: TextStyle(fontSize: 16, color: Colors.black87)),
                    Text(fmt.format(_totalPrice), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                  ],
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: "CHECKOUT DENGAN SALDO ARC COIN",
                  isLoading: _isLoading,
                  onPressed: _processCheckout,
                ),
              ],
            )
          )
        ],
      ),
    );
  }
}