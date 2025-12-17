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
import '../../models/order_model.dart'; // Import OrderItem dari sini
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
  double _totalPrice = 0;
  List<OrderItem> _cartItems = []; 
  
  String? get _userId => Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  bool get _isBioEnabled => Provider.of<AuthService>(context, listen: false).currentUser?.isBiometricEnabled ?? false;
  double get _userBalance => Provider.of<AuthService>(context, listen: false).currentUser?.arcCoin ?? 0;

  @override
  void initState() {
    super.initState();
    // Panggil perhitungan awal
    _calculateTotal();
  }

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

  // --- LOGIKA VERIFIKASI KEAMANAN (PIN/BIO) ---
  Future<bool> _performVerification() async {
    if (_userId == null) return false;

    // Cek PIN wajib ada
    String? storedPin = await _dbService.getUserPin(_userId!);
    if (storedPin == null) {
      NotifService.showWarning("PIN keamanan belum diatur. Silakan atur di Pengaturan.");
      return false;
    }

    bool verified = false;

    // Prioritas 1: Biometrik (Jika Aktif)
    if (_isBioEnabled) {
      verified = await _localAuth.authenticateBiometric(reason: "Konfirmasi pembayaran keranjang");
    }

    // Fallback ke PIN jika Biometrik mati/gagal
    if (!verified) {
      if (!mounted) return false;
      // allowBiometric=true jika bio enabled, false jika tidak. 
      // Tombol Sidik Jari akan muncul jika _isBioEnabled=true
      verified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinInputScreen(userId: _userId!, isVerifying: true, allowBiometric: _isBioEnabled)),
      ) ?? false;
    }

    return verified;
  }

  // --- EKSEKUSI FINAL ORDER ---
  Future<void> _executeOrder() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Loading estetik

    try {
      // 1. Buat Order
      await _dbService.createOrder(
        userId: _userId!, 
        items: _cartItems, 
        total: _totalPrice,
        paymentMethod: 'saldo', 
        voucherCode: null, 
      );
      
      // 2. Potong Saldo
      await _dbService.updateUserSaldo(_userId!, _userBalance - _totalPrice);

      // 3. Kosongkan Keranjang
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

  // --- LOGIKA PERHITUNGAN TOTAL (Dipanggil setiap data berubah) ---
  Future<void> _calculateTotal() async {
    if (_userId == null) return;
    
    double tempTotal = 0;
    List<OrderItem> tempItems = [];
    
    DataSnapshot snap = await FirebaseDatabase.instance.ref('users/${_userId!}/cart').get();
    if(!snap.exists) {
      if(mounted) setState(() {
        _totalPrice = 0;
        _cartItems = [];
      });
      return;
    }

    Map map = snap.value as Map;
    
    for(var key in map.keys) {
      int q = int.parse(map[key].toString());
      DataSnapshot pSnap = await FirebaseDatabase.instance.ref('products/$key').get();
      if(pSnap.exists) {
        ProductModel p = ProductModel.fromMap(key, pSnap.value as Map);
        tempTotal += p.harga * q;
        tempItems.add(OrderItem(productId: p.id, nama: p.nama, qty: q, price: p.harga, imageUrl: p.coverUrl));
      }
    }

    if(mounted) {
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
                // Panggil perhitungan setiap kali data keranjang berubah
                WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTotal());

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("Keranjang Kosong. Yuk, belanja dulu!"));
                }

                Map cartMap = snapshot.data!.snapshot.value as Map;
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartMap.length,
                  itemBuilder: (ctx, i) {
                    String pid = cartMap.keys.elementAt(i);
                    int qty = int.parse(cartMap.values.elementAt(i).toString());

                    return FutureBuilder<DataSnapshot>(
                      future: FirebaseDatabase.instance.ref('products/$pid').get(),
                      builder: (context, prodSnap) {
                        if (!prodSnap.hasData || !prodSnap.data!.exists) return const SizedBox(); 

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