import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'notif_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // STREAM REALTIME: Mendengarkan perubahan di database langsung
  Stream<UserModel?> get userStream {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        _currentUser = null;
        return Stream.value(null);
      } else {
        // Menggunakan onValue agar saat saldo/vip berubah, UI langsung update
        return _db.child('users/${user.uid}').onValue.map((event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = event.snapshot.value as Map;
            _currentUser = UserModel.fromMap(data); // Update local cache
            return _currentUser;
          }
          return null;
        });
      }
    });
  }

  // Auto Admin
Future<void> ensureAdminExists() async {
    // 1. CEK PENTING: Jika sudah ada user yang login, HENTIKAN proses ini.
    // Ini mencegah user yang sudah login tiba-tiba ter-logout.
    if (_auth.currentUser != null) {
      return; 
    }

    const adminEmail = 'archelscuritypw@gmail.com';
    const adminPass = 'admin123'; 

    try {
      // 2. Coba Login dulu sebagai Admin (Hanya jika tidak ada user login)
      UserCredential userCred;
      try {
        userCred = await _auth.signInWithEmailAndPassword(
          email: adminEmail, 
          password: adminPass
        );
      } catch (e) {
        // 3. Jika Login Gagal (User belum ada), Coba Register
        try {
          userCred = await _auth.createUserWithEmailAndPassword(
            email: adminEmail, 
            password: adminPass
          );
        } catch (e2) {
          print("Gagal Login & Register Admin: $e2");
          return; 
        }
      }

      // 4. Update data Admin di Database
      if (userCred.user != null) {
        String uid = userCred.user!.uid;
        
        final adminSnap = await _db.child('users/$uid').get();

        if (!adminSnap.exists || (adminSnap.value as Map)['role'] != 'admin') {
          print("Membuat Data Admin...");
          await _db.child('users/$uid').set({
            'uid': uid,
            'nama': 'Super Admin',
            'username': 'admin',
            'email': adminEmail,
            'role': 'admin',
            'arcCoin': 999999999,
            'isVip': true,
            'isBiometricEnabled': false,
            'phoneNumber': '08123456789',
            'photoUrl': '',
            'vipExpiryDate': DateTime.now().add(const Duration(days: 3650)).toIso8601String(),
          });
        }
        
        // 5. Logout HANYA jika yang login barusan adalah admin sistem ini
        // (Agar saat user biasa mau daftar/login, formnya bersih)
        await _auth.signOut();
      }
    } catch (e) {
      print("Error ensureAdminExists: $e");
    }
  }
  // Verifikasi Password untuk Edit PIN
  Future<bool> verifyPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> registerUser({required String email, required String password, required String nama, required String username, required String phone}) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _db.child('users/${cred.user!.uid}').set({
        'uid': cred.user!.uid, 'nama': nama, 'username': username, 'email': email, 'phoneNumber': phone,
        'role': 'user', 'arcCoin': 0, 'isVip': false, 'isBiometricEnabled': false
      });
      return true;
    } on FirebaseAuthException catch (e) {
      NotifService.showError(e.message ?? "Register Gagal");
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (_) { 
      NotifService.showError("Login Gagal: Periksa Email/Password");
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}