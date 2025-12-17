// models/voucher_model.dart
class VoucherModel {
  final String id;
  final String code; // Contoh: "DISKON10"
  final double discountAmount; // Contoh: 10000
  final double minPurchase; // Minimal belanja 50000

  VoucherModel({
    required this.id,
    required this.code,
    required this.discountAmount,
    required this.minPurchase,
  });

  factory VoucherModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return VoucherModel(
      id: id,
      code: data['code'] ?? '',
      discountAmount: double.tryParse(data['discountAmount'].toString()) ?? 0.0,
      minPurchase: double.tryParse(data['minPurchase'].toString()) ?? 0.0,
    );
  }
}