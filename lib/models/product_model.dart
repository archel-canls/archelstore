// models/product_model.dart
class ProductModel {
  final String id;
  final String nama;
  final String category;
  final double harga;
  final int stock;
  final String deskripsi;
  final String coverUrl; // URL Foto Utama
  final int terjual;

  ProductModel({
    required this.id,
    required this.nama,
    required this.category,
    required this.harga,
    required this.stock,
    required this.deskripsi,
    required this.coverUrl,
    this.terjual = 0,
  });

  factory ProductModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return ProductModel(
      id: id,
      nama: data['nama'] ?? 'Tanpa Nama',
      category: data['category'] ?? 'Umum',
      harga: double.tryParse(data['harga'].toString()) ?? 0.0,
      stock: int.tryParse(data['stock'].toString()) ?? 0,
      deskripsi: data['deskripsi'] ?? '-',
      coverUrl: data['coverUrl'] ?? 'https://placehold.co/400', // Placeholder jika gambar rusak
      terjual: int.tryParse(data['terjual'].toString()) ?? 0,
    );
  }
}