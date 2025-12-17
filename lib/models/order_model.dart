// models/order_model.dart
// Helper Class untuk detail barang dalam pesanan
class OrderItem {
  final String productId;
  final String nama;
  final int qty;
  final double price;
  final String imageUrl;

  OrderItem({
    required this.productId,
    required this.nama,
    required this.qty,
    required this.price,
    required this.imageUrl,
  });

  // Konversi ke Map untuk disimpan ke Firebase
  Map<String, dynamic> toMap() => {
    'productId': productId,
    'nama': nama,
    'qty': qty,
    'price': price,
    'imageUrl': imageUrl,
  };

  factory OrderItem.fromMap(Map<dynamic, dynamic> data) {
    return OrderItem(
      productId: data['productId'] ?? '',
      nama: data['nama'] ?? '',
      qty: int.tryParse(data['qty'].toString()) ?? 0,
      price: double.tryParse(data['price'].toString()) ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

// Class Utama Order
class OrderModel {
  final String id;
  final String uid;
  final double total;
  final String status; // 'Menunggu', 'Diproses', 'Selesai', 'Dibatalkan'
  final String paymentMethod;
  final String? voucherCode;
  final DateTime timestamp;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.uid,
    required this.total,
    required this.status,
    required this.paymentMethod,
    this.voucherCode,
    required this.timestamp,
    required this.items,
  });

  factory OrderModel.fromMap(String id, Map<dynamic, dynamic> data) {
    var itemsList = <OrderItem>[];
    if (data['items'] != null) {
      // Loop list item dari JSON
      (data['items'] as List).forEach((v) {
        if (v != null) itemsList.add(OrderItem.fromMap(v));
      });
    }

    return OrderModel(
      id: id,
      uid: data['uid'] ?? '',
      total: double.tryParse(data['total'].toString()) ?? 0.0,
      status: data['status'] ?? 'Menunggu',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      voucherCode: data['voucherCode'],
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      items: itemsList,
    );
  }
}