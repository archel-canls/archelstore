import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/notif_service.dart';
import '../../widgets/custom_button.dart';
import '../security/pin_input_screen.dart';

class CheckoutSidebar extends StatefulWidget {
  final ProductModel product;
  final String userId;

  const CheckoutSidebar({super.key, required this.product, required this.userId});

  static void show(BuildContext context, ProductModel product, String userId) {
    showMaterialModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => CheckoutSidebar(product: product, userId: userId),
    );
  }

  @override
  State<CheckoutSidebar> createState() => _CheckoutSidebarState();
}

class _CheckoutSidebarState extends State<CheckoutSidebar> {
  final DbService _dbService = DbService();
  final LocalAuthService _localAuthService = LocalAuthService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  int _quantity = 1;
  String _paymentMethod = 'cash'; 
  Map? _selectedVoucher; 
  
  double _userSaldo = 0;
  bool _isLoading = false;
  bool _isBiometricEnabled = false;

  double get _discountAmount {
    if (_selectedVoucher == null) return 0;
    double basePrice = widget.product.harga * _quantity;
    double amount = 0;
    if (_selectedVoucher!['type'] == 'percent') {
      amount = basePrice * double.parse(_selectedVoucher!['discountAmount'].toString());
      if (amount > 15000) amount = 15000; 
    } else {
      amount = double.parse(_selectedVoucher!['discountAmount'].toString());
    }
    return amount;
  }

  double get _totalPrice {
    double basePrice = widget.product.harga * _quantity;
    double finalPrice = basePrice - _discountAmount;
    return finalPrice > 0 ? finalPrice : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _dbService.getUser(widget.userId);
    if (user != null && mounted) {
      setState(() {
        _userSaldo = user.arcCoin;
        _isBiometricEnabled = user.isBiometricEnabled;
      });
    }
  }

  void _processPurchase() async {
    if (_paymentMethod == 'saldo') {
      if (_userSaldo < _totalPrice) {
        NotifService.showError("Saldo tidak cukup! Silakan Top Up.");
        return; 
      }

      setState(() => _isLoading = true);
      String? storedPin = await _dbService.getUserPin(widget.userId);
      setState(() => _isLoading = false);

      if (storedPin == null) {
        if (!mounted) return;
        _showPinSetupDialog(); 
        return; 
      } 
      
      // Cek Biometrik belum aktif tapi HP support?
      if (!_isBiometricEnabled) {
        bool deviceSupports = await _localAuthService.canCheckBiometrics;
        if (deviceSupports) {
          if (!mounted) return;
          _showBiometricSetupDialog(); 
          return;
        }
      }

      bool verified = await _performVerification();
      if (!verified) return; 
    }

    _executeOrder();
  }

  void _showPinSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("PIN Belum Diatur"),
        content: const Text("Harap atur PIN sebelum menggunakan saldo."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyPasswordAndAction(isPinSetup: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
            child: const Text("Atur PIN"),
          ),
        ],
      ),
    );
  }

  void _showBiometricSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Aktifkan Sidik Jari?"),
        content: const Text("Gunakan sidik jari untuk transaksi lebih cepat. Aktifkan sekarang?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _continueToManualVerification(); // User menolak, lanjut pakai PIN biasa
            }, 
            child: const Text("Nanti Saja", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyPasswordAndAction(isPinSetup: false); // Aktivasi Bio
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
            child: const Text("Ya, Aktifkan"),
          ),
        ],
      ),
    );
  }

  void _verifyPasswordAndAction({required bool isPinSetup}) {
    final passCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Verifikasi Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Masukkan password akun Anda."),
                const SizedBox(height: 15),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              if (!isProcessing) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setStateDialog(() => isProcessing = true);
                  bool isPassValid = await Provider.of<AuthService>(context, listen: false).verifyPassword(passCtrl.text);
                  setStateDialog(() => isProcessing = false);
                  
                  if (isPassValid) {
                    if (!mounted) return;
                    Navigator.pop(ctx); 
                    
                    if (isPinSetup) {
                      _doSetupPin();
                    } else {
                      _doSetupBiometric();
                    }
                  } else {
                    NotifService.showError("Password Salah!");
                  }
                },
                child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text("Lanjut"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _doSetupPin() async {
    // Mode Buat PIN (allowBiometric false)
    bool? pinCreated = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => PinInputScreen(userId: widget.userId, isVerifying: false, allowBiometric: false))
    );
    if (pinCreated == true) {
      if (!mounted) return;
      _askContinuePayment("PIN Berhasil Dibuat"); 
    }
  }

  void _doSetupBiometric() async {
    // 1. Verifikasi PIN dulu (allowBiometric FALSE - karena mau aktifin bio, jangan pake bio dulu)
    bool pinVerified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PinInputScreen(userId: widget.userId, isVerifying: true, allowBiometric: false)),
    ) ?? false;

    if (!pinVerified) return;

    // 2. Scan Jari
    bool bioSuccess = await _localAuthService.authenticateBiometric(reason: "Scan untuk mengaktifkan");
    
    if (bioSuccess) {
      setState(() => _isLoading = true);
      await FirebaseDatabase.instance.ref('users/${widget.userId}').update({'isBiometricEnabled': true});
      setState(() {
        _isLoading = false;
        _isBiometricEnabled = true;
      });
      
      NotifService.showSuccess("Sidik Jari Aktif!");
      if (!mounted) return;
      _askContinuePayment("Biometrik Siap");
    } else {
      NotifService.showError("Gagal mengaktifkan biometrik.");
    }
  }

  void _askContinuePayment(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text("Lanjut pembayaran sekarang?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Nanti")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performVerificationAndPay(); 
            },
            child: const Text("Bayar"),
          ),
        ],
      ),
    );
  }

  void _continueToManualVerification() async {
    // Verifikasi Manual (Bisa pakai Bio kalau sudah aktif, tapi di flow ini user nolak aktivasi, jadi likely pakai PIN)
    // Tapi kita biarkan default allowBiometric true sesuai kondisi user
    bool verified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PinInputScreen(userId: widget.userId, isVerifying: true, allowBiometric: _isBiometricEnabled)),
    ) ?? false;
    if (verified) _executeOrder();
  }

  void _performVerificationAndPay() async {
    bool verified = await _performVerification();
    if (verified) _executeOrder();
  }

  Future<bool> _performVerification() async {
    bool verified = false;

    // Disini user SUDAH PUNYA dan SUDAH AKTIFKAN
    if (_isBiometricEnabled) {
      verified = await _localAuthService.authenticateBiometric(reason: "Konfirmasi Pembayaran");
      if (!verified) {
        if (!mounted) return false;
        // Fallback ke PIN (Bolehkan bio true, karena user sudah punya, cuma gagal scan tadi)
        verified = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PinInputScreen(userId: widget.userId, isVerifying: true, allowBiometric: true)),
        ) ?? false;
      }
    } else {
      if (!mounted) return false;
      // User belum aktifkan bio, jadi tombol bio di PIN screen akan hilang otomatis karena _canUseBiometric cek ulang di layar PIN
      // Tapi kita bisa paksa allowBiometric: false biar aman
      verified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinInputScreen(userId: widget.userId, isVerifying: true, allowBiometric: false)),
      ) ?? false;
    }
    return verified;
  }

  void _executeOrder() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); 

    try {
      await _dbService.createOrder(
        userId: widget.userId,
        items: [OrderItem(productId: widget.product.id, nama: widget.product.nama, qty: _quantity, price: widget.product.harga, imageUrl: widget.product.coverUrl)],
        total: _totalPrice,
        paymentMethod: _paymentMethod,
        voucherCode: _selectedVoucher?['code'],
      );

      if (_paymentMethod == 'saldo') {
        await _dbService.updateUserSaldo(widget.userId, _userSaldo - _totalPrice);
      }
      
      if(_selectedVoucher != null) {
         await _dbService.markVoucherUsed(widget.userId, _selectedVoucher!['key']);
      }

      if (!mounted) return;
      Navigator.pop(context); 
      NotifService.showSuccess("Pesanan berhasil dibuat!");
      
    } catch (e) {
      NotifService.showError("Gagal: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVoucherSelector() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              const Text("Pilih Voucher", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _dbService.getUserVouchers(widget.userId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return const Center(child: Text("Tidak ada voucher"));
                    }
                    Map data = snapshot.data!.snapshot.value as Map;
                    List<Map> vouchers = [];
                    data.forEach((key, value) => vouchers.add({...value, 'key': key}));

                    return ListView.builder(
                      itemCount: vouchers.length,
                      itemBuilder: (context, index) {
                        final v = vouchers[index];
                        return ListTile(
                          title: Text(v['title']),
                          subtitle: Text(v['subtitle']),
                          trailing: ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedVoucher = v);
                              Navigator.pop(ctx);
                            },
                            child: const Text("Pakai"),
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
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.85, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.product.coverUrl, width: 80, height: 80, fit: BoxFit.cover)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.product.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(currencyFormatter.format(widget.product.harga), style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                  Text("Stok: ${widget.product.stock}", style: const TextStyle(color: Colors.grey)),
                ]),
              )
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Jumlah Beli", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { if(_quantity > 1) setState(() => _quantity--); }),
                  Text("$_quantity", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () { if(_quantity < widget.product.stock) setState(() => _quantity++); }),
                ],
              )
            ],
          ),
          const Divider(),
          const Text("Metode Pembayaran", style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile(value: 'cash', groupValue: _paymentMethod, title: const Text("Tunai / Transfer Manual"), onChanged: (val) => setState(() => _paymentMethod = val.toString())),
          RadioListTile(value: 'saldo', groupValue: _paymentMethod, title: Row(children: [const Text("Arc Coin "), Text("(${currencyFormatter.format(_userSaldo)})", style: const TextStyle(color: Colors.grey, fontSize: 12))]), onChanged: (val) => setState(() => _paymentMethod = val.toString())),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showVoucherSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.confirmation_number_outlined, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedVoucher != null ? _selectedVoucher!['title'] : "Pilih Voucher Hemat", style: TextStyle(fontWeight: _selectedVoucher != null ? FontWeight.bold : FontWeight.normal, color: _selectedVoucher != null ? Colors.black : Colors.grey))),
                if (_selectedVoucher != null) IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: () => setState(() => _selectedVoucher = null)) else const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
            ),
          ),
          if (_selectedVoucher != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text("Hemat ${currencyFormatter.format(_discountAmount)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Pembayaran", style: TextStyle(fontSize: 16)), Text(currencyFormatter.format(_totalPrice), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)))]),
          const SizedBox(height: 15),
          CustomButton(text: "BELI SEKARANG", isLoading: _isLoading, onPressed: _processPurchase)
        ],
      ),
    );
  }
}