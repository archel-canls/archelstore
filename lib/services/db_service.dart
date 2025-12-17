import 'dart:convert';
import 'package:crypto/crypto.dart'; 
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../models/order_model.dart';

class DbService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // =======================================================================
  // 🔐 HELPER KEAMANAN & USER
  // =======================================================================
  String _hashPin(String pin, String uid) {
    const String staticSalt = "PinSaltArchel"; 
    String dynamicSalt = uid.length > 5 ? uid.substring(0, 5) : uid;
    var bytes = utf8.encode("$pin$staticSalt$dynamicSalt"); 
    return sha256.convert(bytes).toString();
  }

  Future<bool> isUserLockedOut(String uid) async {
    final snap = await _db.child('users/$uid/security_status').get();
    if (!snap.exists) return false;
    final data = snap.value as Map;
    final lockoutTimeStr = data['lockoutUntil'];
    if (lockoutTimeStr != null) {
      final lockoutTime = DateTime.parse(lockoutTimeStr);
      if (DateTime.now().isBefore(lockoutTime)) return true;
      else { await resetAuthAttempts(uid); return false; }
    }
    return false;
  }

  Future<int> handleAuthFailure(String uid) async {
    final snap = await _db.child('users/$uid/security_status/failed_count').get();
    int failedCount = snap.exists ? int.parse(snap.value.toString()) : 0;
    failedCount++;
    if (failedCount >= 8) {
      final lockoutUntil = DateTime.now().add(const Duration(minutes: 10)).toIso8601String();
      await _db.child('users/$uid/security_status').update({'failed_count': failedCount, 'lockoutUntil': lockoutUntil});
      return 0; 
    } else {
      await _db.child('users/$uid/security_status').update({'failed_count': failedCount});
      return 8 - failedCount;
    }
  }

  Future<void> resetAuthAttempts(String uid) async {
    await _db.child('users/$uid/security_status').remove();
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _db.child('users/$uid').get();
    if (snap.exists) return UserModel.fromMap(snap.value as Map);
    return null;
  }

  Future<void> updateUserProfile(String uid, {String? nama, String? phone, String? photoBase64}) async {
    Map<String, dynamic> updates = {};
    if (nama != null && nama.isNotEmpty) updates['nama'] = nama;
    if (phone != null && phone.isNotEmpty) updates['phoneNumber'] = phone;
    if (photoBase64 != null && photoBase64.isNotEmpty) updates['photoUrl'] = photoBase64;
    if (updates.isNotEmpty) await _db.child('users/$uid').update(updates);
  }

  Future<void> updateUserSaldo(String uid, double newBalance, {String reason = "Transaksi"}) async {
    await _db.child('users/$uid/arcCoin').set(newBalance);
    await sendNotification(uid, "Info Saldo", "$reason. Saldo: ${fmt.format(newBalance)}", 'saldo');
  }

  Future<double> getCurrentSaldo(String uid) async {
    final snap = await _db.child('users/$uid/arcCoin').get();
    return snap.exists ? double.parse(snap.value.toString()) : 0;
  }

  Future<void> setUserPin(String uid, String pin) async {
    await _db.child('users/$uid/securityPin').set(_hashPin(pin, uid));
  }

  Future<String?> getUserPin(String uid) async {
    final snap = await _db.child('users/$uid/securityPin').get();
    return snap.exists ? snap.value.toString() : null;
  }

  Future<void> buyVip(String uid, double currentCoin) async {
    if (currentCoin < 10000) throw Exception("Saldo tidak cukup");
    await _db.child('users/$uid').update({
      'arcCoin': currentCoin - 10000,
      'isVip': true,
      'vipExpiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });
    await _generateVipVouchers(uid);
    await sendNotification(uid, "VIP Aktif!", "Selamat! Anda sekarang VIP Member.", "info");
  }

  Future<void> _generateVipVouchers(String uid) async {
    String v1Id = _db.push().key!;
    await _db.child('users/$uid/my_vouchers/$v1Id').set({
      'code': 'VIP10', 'title': 'Diskon 10% All Item', 'subtitle': 'Maksimal Rp 15.000', 'discountAmount': 0.10, 'type': 'percent', 'isUsed': false,
    });
    String v2Id = _db.push().key!;
    await _db.child('users/$uid/my_vouchers/$v2Id').set({
      'code': 'VIP5K', 'title': 'Potongan Rp 5.000', 'subtitle': 'Min. Belanja Rp 50.000', 'discountAmount': 5000, 'type': 'fixed', 'isUsed': false,
    });
  }

  Stream<DatabaseEvent> getUserVouchers(String uid) {
    return _db.child('users/$uid/my_vouchers').orderByChild('isUsed').equalTo(false).onValue;
  }

  Future<void> markVoucherUsed(String uid, String voucherKey) async {
    await _db.child('users/$uid/my_vouchers/$voucherKey').update({'isUsed': true});
  }

  Future<void> sendNotification(String uid, String title, String body, String type) async {
    await _db.child('notifications/$uid').push().set({
      'title': title, 'body': body, 'type': type, 'timestamp': DateTime.now().toIso8601String(), 'isRead': false,
    });
  }

  // =======================================================================
  // ⭐ RATING SYSTEM
  // =======================================================================

  Future<void> submitRating(String oid, List items, int rating) async {
    await _db.child('orders/$oid').update({
      'isRated': true,
      'ratingScore': rating
    });

    for (var item in items) {
      String pid = item['productId']; 
      DatabaseReference prodRef = _db.child('products/$pid');
      
      DataSnapshot snap = await prodRef.get();
      if(snap.exists) {
        Map data = snap.value as Map;
        double currentTotal = double.tryParse(data['ratingTotal'].toString()) ?? 0.0;
        int currentCount = int.tryParse(data['ratingCount'].toString()) ?? 0;

        await prodRef.update({
          'ratingTotal': currentTotal + rating,
          'ratingCount': currentCount + 1,
        });
      }
    }
  }

  // =======================================================================
  // 📦 ORDER MANAGEMENT
  // =======================================================================

  Future<void> adminUpdateOrderStatus({
    required String oid, required String uid, required String newStatus,
    required List items, required double total, required String paymentMethod
  }) async {
    await _db.child('orders/$oid').update({'status': newStatus});

    if (newStatus == 'Dibatalkan') {
      await _returnStockAndRefund(uid, items, total, paymentMethod, oid);
    } else if (newStatus == 'Selesai') {
      for (var item in items) {
        String pid = item['productId'];
        int qty = int.parse(item['qty'].toString());
        DataSnapshot s = await _db.child('products/$pid/terjual').get();
        int currentSold = s.exists ? int.parse(s.value.toString()) : 0;
        await _db.child('products/$pid/terjual').set(currentSold + qty);
      }
    }

    String title = newStatus == 'Selesai' ? "Pesanan Selesai 🎉" : (newStatus == 'Dibatalkan' ? "Pesanan Dibatalkan ❌" : "Update Pesanan");
    await sendNotification(uid, title, "Status pesanan berubah menjadi $newStatus", 'order');
  }

  Future<void> userCancelOrder(String oid, String uid, List items, double total, String paymentMethod) async {
    await _db.child('orders/$oid').update({'status': 'Dibatalkan'});
    await _returnStockAndRefund(uid, items, total, paymentMethod, oid);
    await sendNotification(uid, "Pesanan Dibatalkan", "Anda telah membatalkan pesanan #${oid.substring(oid.length-5)}", 'order');
  }

  Future<void> _returnStockAndRefund(String uid, List items, double total, String paymentMethod, String oid) async {
    for (var item in items) {
      String pid = item['productId'];
      int qty = int.parse(item['qty'].toString());
      DataSnapshot s = await _db.child('products/$pid/stock').get();
      if (s.exists) {
        int currentStock = int.parse(s.value.toString());
        await _db.child('products/$pid/stock').set(currentStock + qty);
      }
    }
    if (paymentMethod == 'saldo') {
      double currentSaldo = await getCurrentSaldo(uid);
      await updateUserSaldo(uid, currentSaldo + total, reason: "Refund Order #${oid.substring(oid.length-5)}");
    }
  }

  Future<void> createOrder({
    required String userId, required List<OrderItem> items, required double total, required String paymentMethod, String? voucherCode
  }) async {
    String oid = _db.push().key!;
    await _db.child('orders/$oid').set({
      'uid': userId, 'total': total, 'status': 'Diproses', 'paymentMethod': paymentMethod, 'voucherCode': voucherCode,
      'timestamp': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
      'isRated': false, // Default belum dinilai
    });
    
    for (var item in items) {
      DataSnapshot s = await _db.child('products/${item.productId}/stock').get();
      if (s.exists) {
        int current = int.parse(s.value.toString());
        await _db.child('products/${item.productId}/stock').set(current - item.qty);
      }
    }

    String orderIdShort = oid.substring(oid.length - 5);
    await sendNotification(userId, "Pesanan Dibuat", "Order #$orderIdShort sedang diproses. Total: ${fmt.format(total)}", "order");
  }
}