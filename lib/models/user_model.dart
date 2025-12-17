class UserModel {
  final String uid;
  final String nama;
  final String username;
  final String email;
  final String role; // 'admin' atau 'user'
  final double arcCoin;
  final bool isVip;
  final bool isBiometricEnabled;
  final String? phoneNumber;
  final String? photoUrl;        // <--- TAMBAHAN BARU
  final String? vipExpiryDate;   // <--- TAMBAHAN BARU

  UserModel({
    required this.uid,
    required this.nama,
    required this.username,
    required this.email,
    required this.role,
    this.arcCoin = 0,
    this.isVip = false,
    this.isBiometricEnabled = false,
    this.phoneNumber,
    this.photoUrl,       // <--- TAMBAHAN BARU
    this.vipExpiryDate,  // <--- TAMBAHAN BARU
  });

  // Factory untuk mengubah data JSON dari Firebase menjadi Object User
  factory UserModel.fromMap(Map<dynamic, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      nama: data['nama'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      // Parsing aman: ubah ke string dulu baru ke double agar tidak error jika data int
      arcCoin: double.tryParse(data['arcCoin'].toString()) ?? 0.0,
      isVip: data['isVip'] ?? false,
      isBiometricEnabled: data['isBiometricEnabled'] ?? false,
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],           // <--- TAMBAHAN BARU
      vipExpiryDate: data['vipExpiryDate'], // <--- TAMBAHAN BARU
    );
  }

  // Untuk update data ke Firebase (jika perlu)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nama': nama,
      'username': username,
      'email': email,
      'role': role,
      'arcCoin': arcCoin,
      'isVip': isVip,
      'isBiometricEnabled': isBiometricEnabled,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,           // <--- TAMBAHAN BARU
      'vipExpiryDate': vipExpiryDate, // <--- TAMBAHAN BARU
    };
  }
}