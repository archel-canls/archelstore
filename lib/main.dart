import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:local_auth/local_auth.dart'; //

class LocalAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> checkBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        // PERBAIKAN DI SINI: ganti 'authoptions' menjadi 'authOptions'
        options: const AuthenticationOptions( 
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate;
    } on Exception catch (e) {
      print('Error during authentication: $e');
      return false;
    }
  }
}

final _localAuthService = LocalAuthService(); // Instance global
// --- Konfigurasi Firebase Anda ---
// Gunakan konfigurasi yang diberikan sebelumnya
const FirebaseOptions myFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDmTjmyIp5fX6f6nXNe9HWyicCPGBG2SCg",
  authDomain: "archelstore-777.firebaseapp.com",
  databaseURL: "https://archelstore-777-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "archelstore-777",
  storageBucket: "archelstore-777.firebasestorage.app",
  messagingSenderId: "474403931284",
  appId: "1:474403931284:web:54028df72894249d1ce081",
);
// ---------------------------------

// Inisialisasi Firebase dan Database Ref
late final FirebaseAuth _auth = FirebaseAuth.instance;
late final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: myFirebaseOptions, 
    );
  } catch (e) {
    print('Gagal menginisialisasi Firebase: $e');
  }
  
  // Memastikan user 'admin' ada
  await _initializeAdmin();
  await _auth.signOut();
  runApp(const ArchelStoreApp());
}

// =========================================================================
// 1. MODEL DATA (DATA STRUCTURES)
// =========================================================================

class UserModel {
  final String uid;
  final String nama;
  final String username;
  final String telepon;
  final String password;
  final double arcCoin;
  final bool isVip;
  final String? pin;
  final bool isBiometricSet;
  final String role; // 'user' atau 'admin'
  final String? vipExpiryDate;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.nama,
    required this.username,
    required this.telepon,
    required this.password,
    this.arcCoin = 0.0,
    this.isVip = false,
    this.pin,
    this.isBiometricSet = false,
    this.role = 'user',
    this.vipExpiryDate,
    this.photoUrl = 'https://placehold.co/100x100/CCCCCC/FFFFFF?text=P',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      nama: map['nama'] ?? '',
      username: map['username'] ?? '',
      telepon: map['telepon'] ?? '',
      password: map['password'] ?? '', // Sebaiknya tidak menyimpan password asli
      arcCoin: (map['arcCoin'] as num?)?.toDouble() ?? 0.0,
      isVip: map['isVip'] ?? false,
      pin: map['pin'],
      isBiometricSet: map['isBiometricSet'] ?? false,
      role: map['role'] ?? 'user',
      vipExpiryDate: map['vipExpiryDate'],
      photoUrl: map['photoUrl'] ?? 'https://placehold.co/100x100/CCCCCC/FFFFFF?text=P',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'username': username,
      'telepon': telepon,
      'password': password,
      'arcCoin': arcCoin,
      'isVip': isVip,
      'pin': pin,
      'isBiometricSet': isBiometricSet,
      'role': role,
      'vipExpiryDate': vipExpiryDate,
      'photoUrl': photoUrl,
    };
  }
}

class ProductModel {
  final String id;
  final String nama;
  final String coverUrl;
  final List<String> detailPhotos;
  final String deskripsi;
  final double harga;
  final int stock;
  final int terjual;

  ProductModel({
    required this.id,
    required this.nama,
    required this.coverUrl,
    this.detailPhotos = const [],
    required this.deskripsi,
    required this.harga,
    required this.stock,
    this.terjual = 0,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      nama: map['nama'] ?? 'Unknown Product',
      coverUrl: map['coverUrl'] ?? 'https://placehold.co/400x400/0000FF/FFFFFF?text=Product',
      detailPhotos: List<String>.from(map['detailPhotos'] ?? []),
      deskripsi: map['deskripsi'] ?? '',
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
      stock: map['stock'] ?? 0,
      terjual: map['terjual'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'coverUrl': coverUrl,
      'detailPhotos': detailPhotos,
      'deskripsi': deskripsi,
      'harga': harga,
      'stock': stock,
      'terjual': terjual,
    };
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final String productName;
  final String productCoverUrl;
  final int jumlahBeli;
  final double totalHarga;
  final String metodeBayar; // 'cash' atau 'saldo'
  final String? voucherCode;
  final double diskonVoucher;
  final String status; // 'diproses', 'dibatalkan', 'selesai'
  final DateTime tanggalOrder;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.productName,
    required this.productCoverUrl,
    required this.jumlahBeli,
    required this.totalHarga,
    required this.metodeBayar,
    this.voucherCode,
    this.diskonVoucher = 0.0,
    this.status = 'diproses',
    required this.tanggalOrder,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productCoverUrl: map['productCoverUrl'] ?? 'https://placehold.co/50x50',
      jumlahBeli: map['jumlahBeli'] ?? 0,
      totalHarga: (map['totalHarga'] as num?)?.toDouble() ?? 0.0,
      metodeBayar: map['metodeBayar'] ?? 'cash',
      voucherCode: map['voucherCode'],
      diskonVoucher: (map['diskonVoucher'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'diproses',
      tanggalOrder: DateTime.parse(map['tanggalOrder']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'productId': productId,
      'productName': productName,
      'productCoverUrl': productCoverUrl,
      'jumlahBeli': jumlahBeli,
      'totalHarga': totalHarga,
      'metodeBayar': metodeBayar,
      'voucherCode': voucherCode,
      'diskonVoucher': diskonVoucher,
      'status': status,
      'tanggalOrder': tanggalOrder.toIso8601String(),
    };
  }
}

class VoucherModel {
  final String code;
  final double diskonPersen; // 0.10 untuk 10%
  final double diskonMaksimal;
  final double minimumPembelian;
  final String jenis; // 'arc' (hanya saldo) atau 'all' (semua pembayaran)
  final int maxPenggunaan; // Maksimal penggunaan total
  int digunakan; // Jumlah yang sudah digunakan

  VoucherModel({
    required this.code,
    required this.diskonPersen,
    required this.diskonMaksimal,
    this.minimumPembelian = 0.0,
    this.jenis = 'all',
    this.maxPenggunaan = 1,
    this.digunakan = 0,
  });

  factory VoucherModel.fromMap(Map<String, dynamic> map, String code) {
    return VoucherModel(
      code: code,
      diskonPersen: (map['diskonPersen'] as num?)?.toDouble() ?? 0.0,
      diskonMaksimal: (map['diskonMaksimal'] as num?)?.toDouble() ?? 0.0,
      minimumPembelian: (map['minimumPembelian'] as num?)?.toDouble() ?? 0.0,
      jenis: map['jenis'] ?? 'all',
      maxPenggunaan: map['maxPenggunaan'] ?? 1,
      digunakan: map['digunakan'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diskonPersen': diskonPersen,
      'diskonMaksimal': diskonMaksimal,
      'minimumPembelian': minimumPembelian,
      'jenis': jenis,
      'maxPenggunaan': maxPenggunaan,
      'digunakan': digunakan,
    };
  }
}

// =========================================================================
// 2. LAYANAN FIREBASE (DB & AUTH)
// =========================================================================

Future<void> _initializeAdmin() async {
  try {
    // 1. Cek apakah ada admin yang terdaftar di Authentication
    UserCredential? adminCredential;
    try {
      adminCredential = await _auth.signInWithEmailAndPassword(
        email: 'admin@archelstore.com',
        password: 'admin123',
      );
    } catch (e) {
      // Jika belum ada, buat akun admin
      adminCredential = await _auth.createUserWithEmailAndPassword(
        email: 'admin@archelstore.com',
        password: 'admin123',
      );
    }

    // 2. Pastikan data di Realtime Database ada
    final adminUid = adminCredential.user!.uid;
    final adminRef = _dbRef.child('users').child(adminUid);
    final snapshot = await adminRef.get();

    if (!snapshot.exists) {
      final adminData = UserModel(
        uid: adminUid,
        nama: 'Administrator Archel Store',
        username: 'admin',
        telepon: '0895617352225', // Nomor WA Pusat Bantuan
        password: 'admin123',
        role: 'admin',
        arcCoin: 99999999.0,
        isVip: true,
      ).toMap();
      await adminRef.set(adminData);
      print('Admin user initialized successfully.');
    }
  } catch (e) {
    print('Failed to initialize admin user: $e');
  }
}

// =========================================================================
// 3. WIDGET UTAMA (MAIN APP)
// =========================================================================

class ArchelStoreApp extends StatelessWidget {
  const ArchelStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archel Store',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      // Menggunakan StreamBuilder untuk mengelola status login
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            // Jika sudah login, cek role pengguna
            return FutureBuilder<UserModel?>(
              future: _getUserData(snapshot.data!.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (userSnapshot.hasData) {
                  final user = userSnapshot.data!;
                  if (user.role == 'admin') {
                    return const AdminMainScreen();
                  } else {
                    return const UserMainScreen();
                  }
                }
                // Jika data pengguna tidak ditemukan (error), arahkan ke login
                return const AuthScreen(); 
              },
            );
          }
          // Jika belum login
          return const AuthScreen();
        },
      ),
    );
  }

  Future<UserModel?> _getUserData(String uid) async {
    final snapshot = await _dbRef.child('users').child(uid).get();
    if (snapshot.exists) {
      return UserModel.fromMap(Map<String, dynamic>.from(snapshot.value as Map), uid);
    }
    return null;
  }
}
// =========================================================================
// 4. LAYAR OTENTIKASI (LOGIN, REGISTER, LUPA PASSWORD)
// =========================================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // State untuk berpindah antar form: 0=Login, 1=Register, 2=Forgot
  int _currentForm = 0; 

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_currentForm) {
      case 0:
        content = LoginForm(
          onRegister: () => setState(() => _currentForm = 1),
          onForgot: () => setState(() => _currentForm = 2),
        );
        break;
      case 1:
        content = RegisterForm(
          onLogin: () => setState(() => _currentForm = 0),
        );
        break;
      case 2:
        content = ForgotPasswordForm(
          onLogin: () => setState(() => _currentForm = 0),
        );
        break;
      default:
        content = const Text('Error');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Archel Store - Otentikasi')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(30.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

// --- WIDGET LOGIN 🚀 ---
class LoginForm extends StatefulWidget {
  final VoidCallback onRegister;
  final VoidCallback onForgot;

  const LoginForm({required this.onRegister, required this.onForgot, super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    
    // Gunakan email fiktif yang sama dengan alur Register
    final emailFiktif = '$username@archelstore.com';

    try {
      await _auth.signInWithEmailAndPassword(
        email: emailFiktif,
        password: password,
      );
      
      // Jika berhasil, navigasi ke halaman utama (Asumsi: di luar scope file ini)
      // Contoh: Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));

      setState(() {
        _message = 'Login Berhasil! Selamat datang, $username.';
      });
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        setState(() => _message = 'Username atau Password salah.');
      } else {
        setState(() => _message = 'Error Login: ${e.message}');
      }
    } catch (e) {
      setState(() => _message = 'Error Login Umum: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selamat Datang',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Silakan masuk ke akun Anda',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(_message, style: TextStyle(color: _message.contains('Berhasil') ? Colors.green : Colors.red), textAlign: TextAlign.center),
          ),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onForgot,
            child: const Text('Lupa Password?'),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('MASUK', style: TextStyle(fontSize: 18)),
        ),
        const Divider(height: 30),
        TextButton(
          onPressed: widget.onRegister,
          child: const Text('Belum punya akun? Daftar Sekarang'),
        ),
      ],
    );
  }
}

// --- WIDGET REGISTER ---
class RegisterForm extends StatefulWidget {
  final VoidCallback onLogin;
  const RegisterForm({required this.onLogin, super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _teleponController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() => _message = 'Konfirmasi password tidak cocok.');
      _isLoading = false;
      return;
    }
    
    // Alur register: 1. Buat akun Auth, 2. Simpan data lengkap ke RTDB
    try {
      // 1. Buat akun Auth (menggunakan UID@archelstore.com sebagai email fiktif)
      // Ini akan memberikan kita UID yang valid
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: '${_usernameController.text}@archelstore.com', 
        password: password,
      );
      
      final userUid = userCredential.user!.uid;
      
      // 2. Simpan data ke Realtime Database
      final newUser = UserModel(
        uid: userUid,
        nama: _namaController.text.trim(),
        username: _usernameController.text.trim(),
        telepon: _teleponController.text.trim(),
        password: password, // Menyimpan password (tidak direkomendasikan untuk produksi)
        arcCoin: 0.0,
        role: 'user',
      );
      
      await _dbRef.child('users').child(userUid).set(newUser.toMap());
      
      setState(() {
        _message = 'Pendaftaran Berhasil! Silakan Login.';
      });
      widget.onLogin(); // Kembali ke halaman login
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        setState(() => _message = 'Password terlalu lemah.');
      } else if (e.code == 'email-already-in-use') {
        // Ini akan terpicu jika username (yang dijadikan bagian email fiktif) 
        // sudah ada di Firebase Auth
        setState(() => _message = 'Username sudah digunakan.');
      } else {
        setState(() => _message = 'Error Daftar: ${e.message}');
      }
    } catch (e) {
       setState(() => _message = 'Error Pendaftaran Umum: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Daftar Akun Baru',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(_message, style: TextStyle(color: _message.contains('Berhasil') ? Colors.green : Colors.red), textAlign: TextAlign.center),
          ),
        TextField(controller: _namaController, decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 15),
        TextField(controller: _teleponController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor Telepon (+62...)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 15),
        TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username (Unik)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 15),
        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 15),
        TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi Password', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text('DAFTAR', style: TextStyle(fontSize: 18)),
        ),
        const Divider(height: 30),
        TextButton(
          onPressed: widget.onLogin,
          child: const Text('Sudah punya akun? Kembali ke Login'),
        ),
      ],
    );
  }
}

// --- WIDGET LUPA PASSWORD ---
class ForgotPasswordForm extends StatefulWidget {
  final VoidCallback onLogin;
  const ForgotPasswordForm({required this.onLogin, super.key});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final TextEditingController _teleponController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    
    // NOTE: Karena kita menggunakan otentikasi email fiktif di Firebase Auth,
    // Reset password akan dilakukan via WA OTP (Simulasi)
    
    final telepon = _teleponController.text.trim();
    if (!telepon.startsWith('08') && !telepon.startsWith('+62')) {
       setState(() => _message = 'Format nomor telepon salah.');
       _isLoading = false;
       return;
    }

    // 1. Cari user di RTDB
    final userSnapshot = await _dbRef.child('users').orderByChild('telepon').equalTo(telepon).get();
    
    if (!userSnapshot.exists || userSnapshot.value == null) {
      setState(() => _message = 'Nomor telepon tidak terdaftar.');
      _isLoading = false;
      return;
    }
    
    // 2. Kirim ke WA (Simulasi)
    final waUrl = 'https://wa.me/$telepon?text=Kode+OTP+reset+password+Anda+adalah:+\\*[123456]\\*';
    
    try {
       await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      // Handle jika tidak bisa launch URL (misalnya di Web)
      setState(() => _message = 'Gagal membuka WhatsApp. Pastikan aplikasi terinstal. $e');
      _isLoading = false;
      return;
    }
   
    setState(() {
      _message = 'Kode OTP telah dikirimkan ke WhatsApp Anda. Silakan cek WA dan kembali ke halaman login.';
    });
    
    // Di aplikasi nyata, ini akan berlanjut ke form OTP dan Password Baru.
    // Di sini, kita simulasikan kembali ke Login setelah kirim WA.
    Future.delayed(const Duration(seconds: 3), widget.onLogin);
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Lupa Password',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(_message, style: TextStyle(color: _message.contains('Error') || _message.contains('Gagal') ? Colors.red : Colors.blue), textAlign: TextAlign.center),
          ),
        TextField(
          controller: _teleponController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Masukkan Nomor Telepon Anda',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text('RESET VIA WHATSAPP', style: TextStyle(fontSize: 18)),
        ),
        const Divider(height: 30),
        TextButton(
          onPressed: widget.onLogin,
          child: const Text('Kembali ke Login'),
        ),
      ],
    );
  }
}

// =========================================================================
// 5. LAYAR UTAMA PENGGUNA (DASHBOARD, MY ORDER, PROFILE)
// =========================================================================

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _userScreens = [
    const UserDashboardScreen(),
    const MyOrderScreen(),
    const UserProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _userScreens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'My Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- WIDGET DASHBOARD PENGGUNA ---
class UserDashboardScreen extends StatelessWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').child(uid).onValue,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Gagal memuat data pengguna.'));
        }

        final userData = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map), uid);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard Archel Store', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () => _showSearch(context)),
              IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => _showCart(context)),
              IconButton(icon: const Icon(Icons.notifications), onPressed: () => _showNotifications(context)),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Saldo dan VIP
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Arc Coin Saldo', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            Text('Rp ${userData.arcCoin.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: userData.isVip ? Colors.amber : Colors.blueGrey,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(userData.isVip ? 'VIP Member' : 'Reguler', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showTopUp(context),
                          icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                          label: const Text('Top Up', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Produk Pilihan (Random)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // List Produk Random
                StreamBuilder<DatabaseEvent>(
                  stream: _dbRef.child('products').onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return const Center(child: Text('Belum ada produk.'));
                    }

                    final productsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    final productList = productsMap.entries.map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e.value), e.key)).toList();
                    
                    // Ambil 6 produk secara random
                    productList.shuffle();
                    final randomProducts = productList.take(6).toList();

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75, // Untuk ruang gambar dan teks
                      ),
                      itemCount: randomProducts.length,
                      itemBuilder: (context, index) {
                        final product = randomProducts[index];
                        return ProductCard(product: product);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showSearch(BuildContext context) {
    // Implementasi Search
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Pencarian Barang')));
  }
  
  void _showCart(BuildContext context) {
    // Implementasi Keranjang Belanja
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halaman Keranjang Belanja')));
  }
  
  void _showNotifications(BuildContext context) {
    // Implementasi Notifikasi
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halaman Notifikasi')));
  }
  
  void _showTopUp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const TopUpModal(),
    );
  }
}

// --- WIDGET CARD PRODUK ---
class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: product),
        ));
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  product.coverUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, size: 50)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${product.harga.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.fire_truck, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Terjual ${product.terjual}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODAL TOP UP SALDO ---
class TopUpModal extends StatelessWidget {
  const TopUpModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Up Arc Coin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          _buildPaymentMethod(context, 'ShopeePay', Icons.wallet_travel),
          _buildPaymentMethod(context, 'Transfer Bank', Icons.account_balance),
          _buildPaymentMethod(context, 'QRIS', Icons.qr_code),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(BuildContext context, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Logika simulasi pembayaran
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Simulasi Top Up via $title berhasil! Saldo ditambahkan (Simulasi)'),
        ));
        // Di aplikasi nyata, ini akan mengarahkan ke halaman pembayaran
        _updateArcCoin(100000.0); // Tambahkan Rp 100.000
      },
    );
  }
  
  Future<void> _updateArcCoin(double amount) async {
    final uid = _auth.currentUser!.uid;
    final userRef = _dbRef.child('users').child(uid);
    final snapshot = await userRef.get();
    
    if (snapshot.exists) {
      final currentCoin = (Map<String, dynamic>.from(snapshot.value as Map)['arcCoin'] as num).toDouble();
      await userRef.update({'arcCoin': currentCoin + amount});
    }
  }
}

// --- WIDGET DETAIL PRODUK ---
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({required this.product, super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = [product.coverUrl, ...product.detailPhotos];

    return Scaffold(
      appBar: AppBar(title: Text(product.nama)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Galeri Foto
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Text('Foto tidak tersedia')),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.nama, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Rp ${product.harga.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, color: Colors.red, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Stok: ${product.stock}', style: TextStyle(fontSize: 16, color: product.stock > 0 ? Colors.green : Colors.red)),
                        const Divider(height: 30),

                        const Text('Deskripsi Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          product.deskripsi,
                          maxLines: _showFullDescription ? null : 3,
                          overflow: _showFullDescription ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showFullDescription = !_showFullDescription;
                            });
                          },
                          child: Text(_showFullDescription ? 'Lihat Lebih Sedikit' : 'Lihat Lebih Banyak'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer Beli & Keranjang
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: product.stock == 0 ? _showStockEmpty : () => _addToCart(context, product),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Tambah ke Keranjang'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: product.stock == 0 ? _showStockEmpty : () => _showBuySidebar(context, product),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Beli Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showStockEmpty() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Maaf, stok tidak tersedia untuk saat ini.'),
      backgroundColor: Colors.red,
    ));
  }
  
  void _addToCart(BuildContext context, ProductModel product) {
    if (product.stock == 0) return _showStockEmpty();
    
    // Logika penambahan ke keranjang (simulasi)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product.nama} berhasil ditambahkan ke keranjang.'),
      backgroundColor: Colors.green,
    ));
    // NOTE: Stok tidak berkurang saat ditambahkan ke keranjang
  }
  
  void _showBuySidebar(BuildContext context, ProductModel product) {
    if (product.stock == 0) return _showStockEmpty();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BuySidebar(product: product),
    );
  }
}

// --- WIDGET SIDEBAR PEMBELIAN ---
class BuySidebar extends StatefulWidget {
  final ProductModel product;
  const BuySidebar({required this.product, super.key});

  @override
  State<BuySidebar> createState() => _BuySidebarState();
}

class _BuySidebarState extends State<BuySidebar> {
  int _quantity = 1;
  String _paymentMethod = 'cash'; // 'cash' atau 'saldo'
  String _voucherCode = '';
  double _discount = 0.0;
  bool _isLoading = false;
  String _message = '';

  Future<VoucherModel?> _getVoucher(String code) async {
    final snapshot = await _dbRef.child('vouchers').child(code.toUpperCase()).get();
    if (snapshot.exists) {
      return VoucherModel.fromMap(Map<String, dynamic>.from(snapshot.value as Map), code);
    }
    return null;
  }
  
  Future<void> _checkVoucher() async {
    setState(() {
      _discount = 0.0;
      _message = '';
    });
    
    if (_voucherCode.isEmpty) return;
    
    final voucher = await _getVoucher(_voucherCode);
    if (voucher == null) {
      setState(() => _message = 'Kode voucher tidak valid.');
      return;
    }
    
    if (voucher.digunakan >= voucher.maxPenggunaan) {
      setState(() => _message = 'Kode voucher sudah habis/nonaktif.');
      return;
    }
    
    final subtotal = widget.product.harga * _quantity;
    
    if (subtotal < voucher.minimumPembelian) {
      setState(() => _message = 'Minimal pembelian Rp ${voucher.minimumPembelian.toStringAsFixed(0)} untuk voucher ini.');
      return;
    }
    
    if (_paymentMethod == 'cash' && voucher.jenis == 'arc') {
      setState(() => _message = 'Voucher ARC hanya bisa digunakan dengan pembayaran Saldo (Arc Coin).');
      return;
    }

    // Hitung diskon
    final calculatedDiscount = subtotal * voucher.diskonPersen;
    final finalDiscount = min(calculatedDiscount, voucher.diskonMaksimal);

    setState(() {
      _discount = finalDiscount;
      _message = 'Voucher berhasil diterapkan! Diskon: Rp ${finalDiscount.toStringAsFixed(0)}';
    });
  }

  double get _subtotal => widget.product.harga * _quantity;
  double get _totalPrice => _subtotal - _discount;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Detail Pembelian', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Detail Barang
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(product.coverUrl, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Stok Tersedia: ${product.stock}', style: const TextStyle(color: Colors.grey)),
                              Text('Rp ${product.harga.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // Jumlah Beli
                    _buildQuantitySelector(),
                    const Divider(height: 30),

                    // Metode Pembayaran
                    _buildPaymentMethodSelector(),
                    const Divider(height: 30),

                    // Voucher
                    _buildVoucherInput(),
                    const Divider(height: 30),

                    // Ringkasan Harga
                    _buildPriceSummary(),
                    
                    if (_message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_message, style: TextStyle(color: _message.contains('berhasil') ? Colors.green : Colors.red)),
                      ),
                  ],
                ),
              ),
              
              // Tombol Beli Sekarang
              Container(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processPurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text('Beli Sekarang (Rp ${_totalPrice.toStringAsFixed(0)})', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Jumlah Beli', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            IconButton(
              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 50,
              child: TextField(
                controller: TextEditingController(text: _quantity.toString()),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (value) {
                  int? newQty = int.tryParse(value);
                  if (newQty != null && newQty >= 1 && newQty <= widget.product.stock) {
                    setState(() => _quantity = newQty);
                  } else if (newQty != null && newQty > widget.product.stock) {
                    setState(() {
                       _quantity = widget.product.stock;
                       _message = 'Maksimal pembelian hanya ${widget.product.stock} unit.';
                    });
                  }
                },
              ),
            ),
            IconButton(
              onPressed: _quantity < widget.product.stock ? () => setState(() => _quantity++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
        RadioListTile<String>(
          title: const Text('Cash (Bayar di tempat / Transfer)'),
          value: 'cash',
          groupValue: _paymentMethod,
          onChanged: (val) {
            setState(() {
              _paymentMethod = val!;
              _discount = 0.0; // Reset voucher jika ganti metode
              _voucherCode = '';
              _message = '';
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('Saldo Arc Coin'),
          value: 'saldo',
          groupValue: _paymentMethod,
          onChanged: (val) {
            setState(() {
              _paymentMethod = val!;
              _discount = 0.0; // Reset voucher jika ganti metode
              _voucherCode = '';
              _message = '';
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildVoucherInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kode Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (val) => _voucherCode = val,
                decoration: const InputDecoration(
                  labelText: 'Masukkan Kode Voucher',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _checkVoucher,
              child: const Text('Cek'),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPriceSummary() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Harga Barang', style: TextStyle(color: Colors.grey)),
            Text('Rp ${_subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Diskon Voucher', style: TextStyle(color: Colors.grey)),
            Text('- Rp ${_discount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Rp ${_totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
          ],
        ),
      ],
    );
  }

  Future<void> _processPurchase() async {
    if (widget.product.stock < _quantity) {
      setState(() => _message = 'Maaf, stok tidak mencukupi.');
      return;
    }
    
    if (_paymentMethod == 'saldo') {
      await _processSaldoPayment();
    } else {
      await _createOrder('Pembayaran Cash akan diproses setelah Admin konfirmasi.');
    }
  }

  Future<void> _processSaldoPayment() async {
    final uid = _auth.currentUser!.uid;
    final userSnapshot = await _dbRef.child('users').child(uid).get();
    final user = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.value as Map), uid);
    
    if (user.arcCoin < _totalPrice) {
      setState(() => _message = 'Maaf, saldo Arc Coin kurang. Saldo Anda: Rp ${user.arcCoin.toStringAsFixed(0)}');
      return;
    }

    // Tampilkan Verifikasi PIN/Biometrik
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinBiometricVerification(
        user: user,
        onVerified: () {
          // Saldo Cukup dan PIN/Biometrik Benar
          _executeTransaction(user);
          Navigator.pop(context); // Tutup dialog PIN
          Navigator.pop(context); // Tutup modal sidebar
        },
      ),
    );
  }
  
  Future<void> _executeTransaction(UserModel user) async {
    setState(() => _isLoading = true);
    final uid = user.uid;
    
    // 1. Kurangi Saldo
    final newCoin = user.arcCoin - _totalPrice;
    await _dbRef.child('users').child(uid).update({'arcCoin': newCoin});
    
    // 2. Tandai Voucher digunakan (jika ada)
    if (_voucherCode.isNotEmpty) {
      final voucherRef = _dbRef.child('vouchers').child(_voucherCode.toUpperCase());
      await voucherRef.child('digunakan').get().then((snapshot) {
        if (snapshot.exists) {
          final currentUsed = snapshot.value as int;
          voucherRef.update({'digunakan': currentUsed + 1});
        }
      });
    }

    // 3. Buat Order
    await _createOrder('Pembayaran Saldo Berhasil! Menunggu konfirmasi Admin.');
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _createOrder(String successMessage) async {
    final uid = _auth.currentUser!.uid;
    final userSnapshot = await _dbRef.child('users').child(uid).get();
    final userName = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.value as Map), uid).username;
    
    final newOrder = OrderModel(
      id: _dbRef.child('orders').push().key!,
      userId: uid,
      userName: userName,
      productId: widget.product.id,
      productName: widget.product.nama,
      productCoverUrl: widget.product.coverUrl,
      jumlahBeli: _quantity,
      totalHarga: _totalPrice,
      metodeBayar: _paymentMethod,
      voucherCode: _voucherCode.isNotEmpty ? _voucherCode.toUpperCase() : null,
      diskonVoucher: _discount,
      status: 'diproses',
      tanggalOrder: DateTime.now(),
    );
    
    await _dbRef.child('orders').child(newOrder.id).set(newOrder.toMap());
    
    // Tampilkan notifikasi
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(successMessage),
      backgroundColor: Colors.blueAccent,
    ));
    // Kembali ke Dashboard
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// --- MODAL PIN / BIOMETRIK (VERIFIKASI TRANSAKSI) ---
class PinBiometricVerification extends StatefulWidget {
  final UserModel user;
  final VoidCallback onVerified;
  const PinBiometricVerification({required this.user, required this.onVerified, super.key});

  @override
  State<PinBiometricVerification> createState() => _PinBiometricVerificationState();
}

class _PinBiometricVerificationState extends State<PinBiometricVerification> {
  final TextEditingController _pinController = TextEditingController();
  bool _usePin = true; 
  String _message = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Jika sidik jari sudah diatur, coba verifikasi dengan biometrik terlebih dahulu
    if (widget.user.isBiometricSet) {
      _usePin = false;
      _authenticateBiometric();
    }
  }

  // FUNGSI BARU: Verifikasi Biometrik Asli (Sudah ada delay)
  Future<void> _authenticateBiometric() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _message = 'Memulai pemindaian Sidik Jari...';
    });
    
    final isAvailable = await _localAuthService.checkBiometrics();
    if (!isAvailable) {
      setState(() {
        _message = 'Perangkat tidak mendukung atau Sidik Jari belum disetup di OS. Silakan gunakan PIN.';
        _usePin = true;
        _isAuthenticating = false;
      });
      return;
    }

    final didAuthenticate = await _localAuthService.authenticate(
        'Verifikasi Sidik Jari untuk menyelesaikan pembayaran Arc Coin');

    if (mounted) {
      if (didAuthenticate) {
        // 1. Tampilkan notif berhasil verifikasi di dialog
        setState(() => _message = 'Sidik Jari berhasil diverifikasi!');
        
        // 2. Beri jeda singkat agar pesan berhasil terlihat (Sudah ada)
        await Future.delayed(const Duration(milliseconds: 500)); 
        
        // 3. Lanjutkan ke transaksi
        if (mounted) { // Pengecekan mounted tambahan
             widget.onVerified();
        }
      } else {
        setState(() {
          _message = 'Verifikasi Sidik Jari gagal atau dibatalkan. Gunakan PIN.';
          _usePin = true;
          _isAuthenticating = false;
        });
      }
    }
  }
  
  // FUNGSI PIN (DIPERBAIKI DENGAN DELAY)
  Future<void> _verifyPin() async { // Dibuat async
    if (_pinController.text == widget.user.pin) {
      // 1. Tampilkan notif berhasil verifikasi di dialog
      setState(() => _message = 'PIN berhasil diverifikasi!');
      
      // 2. Beri jeda singkat agar pesan berhasil terlihat
      await Future.delayed(const Duration(milliseconds: 500)); 
      
      // 3. Lanjutkan ke transaksi
      if (mounted) { // Pengecekan mounted untuk menghindari error setelah pop
          widget.onVerified();
      }
    } else {
      setState(() => _message = 'PIN salah.');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (Sisa kode Build Method PinBiometricVerification tidak ada perubahan)
    if (widget.user.pin == null) {
      return AlertDialog(
        title: const Text('Atur PIN Terlebih Dahulu'),
        content: const Text('Anda wajib mengatur PIN sebelum melakukan pembayaran saldo. Atur sekarang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Asumsi AccountSettingsScreen ada dalam navigasi
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const AccountSettingsScreen(), 
              ));
            },
            child: const Text('Atur Sekarang'),
          ),
        ],
      );
    }
    
    return AlertDialog(
      title: const Text('Verifikasi Pembayaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pesan Status
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(_message, 
                style: TextStyle(
                  color: _message.contains('salah') || _message.contains('gagal') ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          
          // Input PIN (Hanya ditampilkan jika mode PIN aktif)
          if (_usePin)
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Masukkan PIN 6 Digit'),
            ),
          
          // Ikon Biometrik (Hanya ditampilkan jika mode Biometrik aktif)
          if (!_usePin && widget.user.isBiometricSet)
            Column(
              children: [
                const Icon(Icons.fingerprint, size: 50, color: Colors.blueAccent),
                const SizedBox(height: 5),
                Text(_isAuthenticating ? 'Menunggu verifikasi sistem...' : 'Sidik Jari aktif. Pindai sidik jari Anda.'),
              ],
            ),
          
          const SizedBox(height: 10),
          
          // Tombol Toggle PIN/Biometrik
          if (widget.user.isBiometricSet && !_isAuthenticating)
            TextButton.icon(
              icon: Icon(_usePin ? Icons.fingerprint : Icons.lock),
              label: Text(_usePin ? 'Gunakan Sidik Jari' : 'Gunakan PIN'),
              onPressed: () {
                setState(() {
                  _usePin = !_usePin;
                  _message = '';
                  if (!_usePin) _authenticateBiometric();
                });
              },
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        if (_usePin && !_isAuthenticating)
          ElevatedButton(onPressed: _verifyPin, child: const Text('Konfirmasi PIN')),
      ],
    );
  }
}
// --- WIDGET MY ORDER ---
class MyOrderScreen extends StatelessWidget {
  const MyOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Diproses'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OrderList(status: 'diproses'),
            _OrderList(status: 'selesai'),
            _OrderList(status: 'dibatalkan'),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final String status;
  const _OrderList({required this.status});

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('orders').orderByChild('userId').equalTo(uid).onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Tidak ada pesanan.'));
        }

        final ordersMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final orderList = ordersMap.entries
            .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((order) => order.status == status)
            .toList();

        if (orderList.isEmpty) {
          return Center(child: Text('Tidak ada pesanan dengan status "$status".'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: orderList.length,
          itemBuilder: (context, index) {
            final order = orderList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Image.network(order.productCoverUrl, width: 50, height: 50, fit: BoxFit.cover),
                title: Text(order.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID Order: ${order.id.substring(0, 8)}\nJumlah: ${order.jumlahBeli} x\nTotal: Rp ${order.totalHarga.toStringAsFixed(0)}'),
                isThreeLine: true,
                trailing: Chip(label: Text(order.status.toUpperCase())),
              ),
            );
          },
        );
      },
    );
  }
}


// --- WIDGET PROFILE PENGGUNA ---
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').child(uid).onValue,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Gagal memuat data profil.'));
        }

        final userData = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map), uid);
        
        return Scaffold(
          appBar: AppBar(title: const Text('Profil Saya')),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header Profil
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  color: Colors.blueAccent.withOpacity(0.1),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 50, backgroundImage: NetworkImage(userData.photoUrl!)),
                      const SizedBox(height: 10),
                      Text(userData.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(userData.nama, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildProfileInfoBox(context, 'ARC COIN', 'Rp ${userData.arcCoin.toStringAsFixed(0)}', Colors.orange),
                          const SizedBox(width: 15),
                          _buildProfileInfoBox(context, 'SHOPPE VIP', userData.isVip ? 'Aktif' : 'Non-Aktif', userData.isVip ? Colors.amber : Colors.blueGrey),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                // Menu Akun Saya
                _buildMenuTitle('AKUN SAYA'),
                _buildProfileMenuItem(context, Icons.edit, 'Edit Foto Profil', () {}),
                _buildProfileMenuItem(context, Icons.phone, 'Ganti Nomor Telepon', () {}),
                _buildProfileMenuItem(context, Icons.person, 'Username', () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username tidak bisa diganti.')));
                }),
                _buildProfileMenuItem(context, Icons.lock, 'Ganti Password', () {}),
                _buildProfileMenuItem(context, Icons.vpn_key, 'Pengaturan PIN & Biometrik', () {
                   Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
                }),
                
                // Menu Lain
                _buildMenuTitle('LAINNYA'),
                _buildProfileMenuItem(context, Icons.discount, 'Voucher Saya (ARC Voucher)', () {
                   Navigator.of(context).push(MaterialPageRoute(builder: (context) => const VoucherScreen()));
                }),
                _buildProfileMenuItem(context, Icons.help_outline, 'Pusat Bantuan (WhatsApp)', () => _launchWhatsApp(userData.username)),

                // Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await _auth.signOut();
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProfileInfoBox(BuildContext context, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
  
  Widget _buildMenuTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
    );
  }
  
  Widget _buildProfileMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      trailing: title != 'Username' ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }
  
  Future<void> _launchWhatsApp(String username) async {
    const phone = '62895617352225'; // +62895617352225
    final message = 'Halo, saya $username, ada kendala/yang ingin saya sampaikan: ';
    final waUrl = 'https://wa.me/$phone?text=$message';
    await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
  }
}
// --- SCREEN PENGATURAN AKUN (PIN & BIOMETRIK) ---
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _message = '';

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').child(uid).onValue,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map), uid);

        return Scaffold(
          appBar: AppBar(title: const Text('Pengaturan Akun')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.green.withOpacity(0.2),
                    child: Text(_message, style: const TextStyle(color: Colors.green)),
                  ),
                
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.pin_drop),
                    title: Text(userData.pin == null ? 'Atur PIN Pembayaran' : 'Ganti PIN Pembayaran'),
                    subtitle: Text(userData.pin == null ? 'Wajib untuk pembayaran saldo' : 'PIN aktif: ${userData.pin}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showPinDialog(context, userData),
                  ),
                ),
                
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: Text(userData.isBiometricSet ? 'Hapus Sidik Jari' : 'Atur Sidik Jari'),
                    subtitle: Text(userData.isBiometricSet ? 'Aktif' : 'Non-Aktif'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _handleBiometricSetting(context, userData),
                  ),
                ),

                const Divider(height: 30),
                const Text('Pengaturan Umum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                // Tambahan pengaturan umum lainnya
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _showPinDialog(BuildContext context, UserModel user) async {
    await showDialog(
      context: context,
      builder: (context) => PinSettingDialog(user: user),
    );
    final userSnapshot = await _dbRef.child('users').child(user.uid).get();
    // Gunakan '!' karena diasumsikan user selalu ada setelah snapshot
    final updatedUser = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.value as Map), user.uid);
    if (updatedUser.pin != null && user.pin == null) {
      setState(() => _message = 'PIN berhasil diatur!');
    }
  }

  void _handleBiometricSetting(BuildContext context, UserModel user) {
    if (user.pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wajib mengatur PIN sebelum mengatur Sidik Jari.')));
      return;
    }
    
    // Tampilkan verifikasi PIN sebelum melakukan otentikasi biometrik
    showDialog(
      context: context,
      builder: (context) => BiometricSettingDialog(
        user: user,
        onPinVerified: () => _enrollOrDeleteBiometric(context, user),
      ),
    );
  }

  // FUNGSI BARU: Menggunakan LocalAuthService untuk pendaftaran/penghapusan biometrik asli
  Future<void> _enrollOrDeleteBiometric(BuildContext context, UserModel user) async {
    // Tutup dialog PIN setelah verifikasi
    Navigator.pop(context); 

    final isAvailable = await _localAuthService.checkBiometrics();
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perangkat tidak mendukung atau belum mengaktifkan Sidik Jari.')));
      return;
    }

    final reason = user.isBiometricSet 
        ? 'Konfirmasi untuk MENGHAPUS Sidik Jari dari aplikasi ini' 
        : 'Pindai sidik jari Anda untuk MENYIMPAN sebagai metode otentikasi';
    
    // Autentikasi biometrik asli
    final didAuthenticate = await _localAuthService.authenticate(reason);

    if (didAuthenticate) {
      final newStatus = !user.isBiometricSet;
      
      // Simpan status biometrik ke database ('isBiometricSet' = tersimpan di authentication database)
      await _dbRef.child('users').child(user.uid).update({'isBiometricSet': newStatus}); //
      
      // Update UI dan tampilkan pesan
      setState(() => _message = newStatus 
          ? 'Sidik Jari berhasil diatur dan tersimpan di authentication database.' 
          : 'Sidik Jari berhasil dihapus.');
      
    } else {
      // Autentikasi gagal atau dibatalkan
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal melakukan verifikasi Sidik Jari. Silakan coba lagi.')));
    }
  }
}
// --- DIALOG PENGATURAN PIN ---
class PinSettingDialog extends StatefulWidget {
  final UserModel user;
  const PinSettingDialog({required this.user, super.key});

  @override
  State<PinSettingDialog> createState() => _PinSettingDialogState();
}

class _PinSettingDialogState extends State<PinSettingDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String _message = '';
  bool _isPasswordVerified = false;

  Future<void> _verifyPassword() async {
    // Verifikasi password akun
    if (_passwordController.text == widget.user.password) {
      setState(() => _isPasswordVerified = true);
    } else {
      setState(() => _message = 'Password salah.');
    }
  }

  Future<void> _setPin() async {
    final newPin = _pinController.text;
    if (newPin.length != 6) {
      setState(() => _message = 'PIN harus 6 digit.');
      return;
    }

    await _dbRef.child('users').child(widget.user.uid).update({'pin': newPin});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN berhasil diatur!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user.pin == null ? 'Atur PIN' : 'Ganti PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_message.isNotEmpty)
            Text(_message, style: const TextStyle(color: Colors.red)),
          
          if (!_isPasswordVerified)
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password Akun (Verifikasi)'),
            ),
          
          if (_isPasswordVerified)
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN Baru (6 Digit)'),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        if (!_isPasswordVerified)
          ElevatedButton(onPressed: _verifyPassword, child: const Text('Lanjutkan')),
        if (_isPasswordVerified)
          ElevatedButton(onPressed: _setPin, child: const Text('Simpan PIN')),
      ],
    );
  }
}

// --- DIALOG PENGATURAN BIOMETRIK ---
class BiometricSettingDialog extends StatefulWidget {
  final UserModel user;
  final VoidCallback onPinVerified;
  const BiometricSettingDialog({required this.user, required this.onPinVerified, super.key});

  @override
  State<BiometricSettingDialog> createState() => _BiometricSettingDialogState();
}

class _BiometricSettingDialogState extends State<BiometricSettingDialog> {
  final TextEditingController _pinController = TextEditingController();
  String _message = '';

  void _verifyPin() {
    // Verifikasi PIN
    if (_pinController.text == widget.user.pin) {
      // Jika PIN benar, panggil callback untuk melanjutkan ke proses Biometrik (enroll/delete)
      widget.onPinVerified(); 
    } else {
      // Jika PIN salah, tampilkan pesan error
      setState(() => _message = 'PIN salah.');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user.isBiometricSet ? 'Hapus Sidik Jari' : 'Atur Sidik Jari'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tampilkan pesan error jika ada
          if (_message.isNotEmpty)
            Text(_message, style: const TextStyle(color: Colors.red)),
          
          // Instruksi untuk pengguna
          const Text('Masukkan PIN Anda untuk mengkonfirmasi perubahan:'),
          
          // Input field untuk PIN
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN Pembayaran'),
          ),
        ],
      ),
      actions: [
        // Tombol Batal
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        
        // Tombol Konfirmasi yang memicu verifikasi PIN
        ElevatedButton(onPressed: _verifyPin, child: const Text('Konfirmasi')),
      ],
    );
  }
}

// --- SCREEN VOUCHER SAYA ---
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  String _message = '';

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').child(uid).onValue,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map), uid);

        return Scaffold(
          appBar: AppBar(title: const Text('Voucher Saya & VIP')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pembelian VIP
                Card(
                  elevation: 4,
                  color: userData.isVip ? Colors.amber.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shoppe VIP Membership', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (userData.isVip)
                          Text('Status: AKTIF hingga ${userData.vipExpiryDate}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
                        else
                          const Text('Harga: 10.000 Arc Coin. Dapatkan Diskon 10% dan Voucher Rp 5.000/minggu selama sebulan.'),
                        
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: userData.isVip ? null : () => _buyVip(userData),
                          style: ElevatedButton.styleFrom(backgroundColor: userData.isVip ? Colors.grey : Colors.amber),
                          child: Text(userData.isVip ? 'VIP Aktif' : 'Beli Sekarang (10.000 Arc Coin)'),
                        ),
                        if (_message.isNotEmpty) Text(_message, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text('ARC VOUCHER (Khusus Pembayaran Saldo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),

                // Simulasi daftar voucher
                _buildVoucherItem('DISC10VIP', 'Diskon 10% Maks. 15rb', 'Tanpa Min. Beli', userData.isVip),
                _buildVoucherItem('POTONG5K', 'Voucher Rp 5.000', 'Min. Beli Rp 50.000', userData.isVip),
                _buildVoucherItem('ARC30K', 'Diskon 30% Maks. 30K', 'Min. Beli Rp 100.000', true),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildVoucherItem(String code, String title, String subtitle, bool isEnabled) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isEnabled ? Colors.white : Colors.grey[200],
      child: ListTile(
        leading: Icon(Icons.discount, color: isEnabled ? Colors.red : Colors.grey),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isEnabled ? Colors.black : Colors.grey)),
        subtitle: Text('$subtitle\nKode: $code'),
        trailing: Text(isEnabled ? 'AKTIF' : 'NON-AKTIF', style: TextStyle(color: isEnabled ? Colors.green : Colors.grey)),
      ),
    );
  }
  
  Future<void> _buyVip(UserModel user) async {
    const price = 10000.0;
    if (user.arcCoin < price) {
      setState(() => _message = 'Maaf, saldo Arc Coin Anda kurang.');
      return;
    }
    
    // Kurangi saldo dan aktifkan VIP
    final newCoin = user.arcCoin - price;
    final expiryDate = DateTime.now().add(const Duration(days: 30)).toIso8601String();
    
    await _dbRef.child('users').child(user.uid).update({
      'arcCoin': newCoin,
      'isVip': true,
      'vipExpiryDate': expiryDate,
    });
    
    // Tambahkan voucher VIP ke database
    final voucherDisc10 = VoucherModel(
      code: 'DISC10VIP',
      diskonPersen: 0.10,
      diskonMaksimal: 15000.0,
      minimumPembelian: 0.0,
      jenis: 'arc',
      maxPenggunaan: 1,
      digunakan: 0,
    ).toMap();
    
    final voucherPotong5k = VoucherModel(
      code: 'POTONG5K',
      diskonPersen: 1.0, // Diskon 100%
      diskonMaksimal: 5000.0, // Tapi maks 5000
      minimumPembelian: 50000.0,
      jenis: 'arc',
      maxPenggunaan: 4, // 1x per minggu selama 4 minggu
      digunakan: 0,
    ).toMap();
    
    await _dbRef.child('vouchers').child('DISC10VIP').set(voucherDisc10);
    await _dbRef.child('vouchers').child('POTONG5K').set(voucherPotong5k);
    
    setState(() => _message = 'VIP berhasil diaktifkan! Saldo berkurang 10.000 Arc Coin.');
  }
}


// =========================================================================
// 6. LAYAR ADMIN (DASHBOARD, PRODUK, AKUN, PEMBELIAN)
// =========================================================================

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _adminScreens = [
    const AdminDashboardScreen(),
    const AdminManagementScreen(type: 'account'),
    const AdminManagementScreen(type: 'order'),
    const AdminProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _adminScreens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Manajemen Akun',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Manajemen Beli',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.redAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- WIDGET DASHBOARD ADMIN ---
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manajemen Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const AddEditProductScreen(),
                ));
              },
              icon: const Icon(Icons.add_box),
              label: const Text('Tambah Barang Baru'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 20),
            
            const Text('Daftar Semua Barang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('products').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('Belum ada produk terdaftar.'));
                }

                final productsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                final productList = productsMap.entries.map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e.value), e.key)).toList();
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: productList.length,
                  itemBuilder: (context, index) {
                    final product = productList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Image.network(product.coverUrl, width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(product.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Stok: ${product.stock} | Terjual: ${product.terjual} | Rp ${product.harga.toStringAsFixed(0)}'),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AddEditProductScreen(product: product),
                          ));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN TAMBAH/EDIT BARANG ---
class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product; // Null jika Tambah
  const AddEditProductScreen({this.product, super.key});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _coverUrlController;
  late TextEditingController _deskripsiController;
  late TextEditingController _hargaController;
  late TextEditingController _stockController;
  
  List<String> _detailPhotos = [];
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.product?.nama ?? '');
    _coverUrlController = TextEditingController(text: widget.product?.coverUrl ?? '');
    _deskripsiController = TextEditingController(text: widget.product?.deskripsi ?? '');
    _hargaController = TextEditingController(text: widget.product?.harga.toString() ?? '');
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '');
    _detailPhotos = List.from(widget.product?.detailPhotos ?? []);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final id = widget.product?.id ?? _dbRef.child('products').push().key!;
      final newProduct = ProductModel(
        id: id,
        nama: _namaController.text,
        coverUrl: _coverUrlController.text,
        detailPhotos: _detailPhotos,
        deskripsi: _deskripsiController.text,
        harga: double.parse(_hargaController.text),
        stock: int.parse(_stockController.text),
        terjual: widget.product?.terjual ?? 0,
      );
      
      await _dbRef.child('products').child(id).set(newProduct.toMap());
      
      setState(() => _message = 'Barang berhasil ${widget.product == null ? 'ditambah' : 'diupdate'}!');
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
      
    } catch (e) {
      setState(() => _message = 'Gagal menyimpan barang: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Barang?'),
        content: const Text('Apakah Anda yakin ingin menghapus barang ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed == true && widget.product != null) {
      await _dbRef.child('products').child(widget.product!.id).remove();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang berhasil dihapus!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Tambah Barang Baru' : 'Edit Barang: ${widget.product!.nama}'),
        actions: [
          if (widget.product != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteProduct,
            ),
        ],
      ),
     body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_message.isNotEmpty)
                Text(_message, style: TextStyle(color: _message.contains('berhasil') ? Colors.green : Colors.red)),
              
              // PERBAIKAN: Nama Barang (v!.isEmpty -> v == null || v.isEmpty)
              TextFormField(
                controller: _namaController, 
                decoration: const InputDecoration(labelText: 'Nama Barang'), 
                validator: (String? v) => v == null || v.isEmpty ? 'Wajib diisi' : null
              ),
              const SizedBox(height: 10),
              
              // PERBAIKAN: URL Cover Utama (v!.isEmpty -> v == null || v.isEmpty)
              TextFormField(
                controller: _coverUrlController, 
                decoration: const InputDecoration(labelText: 'URL Cover Utama'), 
                validator: (String? v) => v == null || v.isEmpty ? 'Wajib diisi' : null
              ),
              const SizedBox(height: 10),
              
              // PERBAIKAN: Deskripsi (v!.isEmpty -> v == null || v.isEmpty)
              TextFormField(
                controller: _deskripsiController, 
                maxLines: 3, 
                decoration: const InputDecoration(labelText: 'Deskripsi'), 
                validator: (String? v) => v == null || v.isEmpty ? 'Wajib diisi' : null
              ),
              const SizedBox(height: 10),
              
              // PERBAIKAN: HARGA (tryParse aman dari null assertion !)
              TextFormField(
                controller: _hargaController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: 'Harga (Rp)'), 
                validator: (String? v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (double.tryParse(v) == null) return 'Wajib angka dan gunakan titik untuk desimal';
                  return null;
                }
              ),
              const SizedBox(height: 10),
              
              // PERBAIKAN: STOK (tryParse aman dari null assertion !)
              TextFormField(
                controller: _stockController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: 'Stok'), 
                validator: (String? v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (int.tryParse(v) == null) return 'Wajib angka bulat';
                  return null;
                }
              ),
              const SizedBox(height: 20),
              
              // Foto Tambahan
              const Text('Foto Tambahan (URL)', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._detailPhotos.asMap().entries.map((entry) =>  
                Row(
                  children: [
                    Expanded(child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _detailPhotos.removeAt(entry.key)),
                    ),
                  ],
                ),
              ).toList(),
              ElevatedButton.icon(
                onPressed: () => _showAddPhotoDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Foto Detail'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              ),
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(widget.product == null ? 'SIMPAN BARANG' : 'UPDATE BARANG', style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPhotoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah URL Foto'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'URL Foto Tambahan')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _detailPhotos.add(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET MANAJEMEN AKUN & PEMBELIAN ---
class AdminManagementScreen extends StatelessWidget {
  final String type; // 'account' atau 'order'
  const AdminManagementScreen({required this.type, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(type == 'account' ? 'Manajemen Akun Pengguna' : 'Manajemen Pembelian'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}), // Fitur Searching
        ],
      ),
      body: type == 'account' ? const _AccountManagementList() : const _OrderManagementTabs(),
    );
  }
}

class _AccountManagementList extends StatelessWidget {
  const _AccountManagementList();

  Future<void> _deleteUser(String uid, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun?'),
        content: const Text('Apakah Anda yakin ingin menghapus akun ini? (Data RTDB akan dihapus)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Hanya menghapus data di Realtime Database. Penghapusan di Firebase Auth
      // memerlukan Cloud Functions atau Admin SDK. Kita simulasikan di RTDB saja.
      await _dbRef.child('users').child(uid).remove();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun berhasil dihapus dari RTDB.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('users').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Tidak ada akun terdaftar.'));
        }

        final usersMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final userList = usersMap.entries
            .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((user) => user.role == 'user') // Hanya tampilkan user biasa
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: userList.length,
          itemBuilder: (context, index) {
            final user = userList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!)),
                title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Nama: ${user.nama}\nTelepon: ${user.telepon}\nArc Coin: ${user.arcCoin.toStringAsFixed(0)}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user.uid, context),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderManagementTabs extends StatelessWidget {
  const _OrderManagementTabs();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Diproses'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AdminOrderList(status: 'diproses'),
                _AdminOrderList(status: 'selesai'),
                _AdminOrderList(status: 'dibatalkan'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderList extends StatelessWidget {
  final String status;
  const _AdminOrderList({required this.status});
  
  // Fungsi untuk mengkonfirmasi atau membatalkan pesanan
  Future<void> _updateOrder(OrderModel order, String newStatus, BuildContext context) async {
    final isConfirmed = newStatus == 'selesai';
    
    // 1. Update status pesanan
    await _dbRef.child('orders').child(order.id).update({'status': newStatus});
    
    // 2. Jika Selesai, kurangi stok
    if (isConfirmed) {
      final productRef = _dbRef.child('products').child(order.productId);
      final productSnapshot = await productRef.get();
      if (productSnapshot.exists) {
        final product = ProductModel.fromMap(Map<String, dynamic>.from(productSnapshot.value as Map), order.productId);
        productRef.update({
          'stock': product.stock - order.jumlahBeli,
          'terjual': product.terjual + order.jumlahBeli,
        });
      }
    } 
    // 3. Jika Dibatalkan ATAU Gagal (dan bayar pakai saldo), kembalikan saldo & voucher
    else if (order.metodeBayar == 'saldo' && newStatus == 'dibatalkan') {
      final userRef = _dbRef.child('users').child(order.userId);
      final userSnapshot = await userRef.get();
      if (userSnapshot.exists) {
        final user = UserModel.fromMap(Map<String, dynamic>.from(userSnapshot.value as Map), order.userId);
        userRef.update({'arcCoin': user.arcCoin + order.totalHarga});
      }
      
      // Kembalikan penggunaan voucher (aktifkan lagi)
      if (order.voucherCode != null) {
        final voucherRef = _dbRef.child('vouchers').child(order.voucherCode!);
        await voucherRef.child('digunakan').get().then((snapshot) {
          if (snapshot.exists) {
            final currentUsed = snapshot.value as int;
            if (currentUsed > 0) voucherRef.update({'digunakan': currentUsed - 1});
          }
        });
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Pesanan ${order.id.substring(0, 8)} berhasil diubah status menjadi $newStatus.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('orders').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Tidak ada pesanan.'));
        }

        final ordersMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final orderList = ordersMap.entries
            .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((order) => order.status == status)
            .toList();

        if (orderList.isEmpty) {
          return Center(child: Text('Tidak ada pesanan dengan status "$status".'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: orderList.length,
          itemBuilder: (context, index) {
            final order = orderList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Image.network(order.productCoverUrl, width: 50, height: 50, fit: BoxFit.cover),
                title: Text('ID: ${order.id.substring(0, 8)} - ${order.productName}'),
                subtitle: Text('User: ${order.userName} | Total: Rp ${order.totalHarga.toStringAsFixed(0)} | Bayar: ${order.metodeBayar.toUpperCase()}'),
                isThreeLine: true,
                trailing: status == 'diproses' 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _updateOrder(order, 'selesai', context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _updateOrder(order, 'dibatalkan', context),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

// --- WIDGET PROFILE ADMIN ---
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Admin')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text('Selamat Datang, Admin!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Anda memiliki hak penuh atas Archel Store.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  await _auth.signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}