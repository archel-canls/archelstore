import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Imports
import 'config/theme.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/notif_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/user/dashboard_screen.dart';
import 'screens/user/my_order_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'widgets/loading_overlay.dart';

// Konfigurasi Firebase (Sesuaikan dengan milik Anda jika berbeda)
const FirebaseOptions myFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDmTjmyIp5fX6f6nXNe9HWyicCPGBG2SCg",
  authDomain: "archelstore-777.firebaseapp.com",
  databaseURL: "https://archelstore-777-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "archelstore-777",
  storageBucket: "archelstore-777.firebasestorage.app",
  messagingSenderId: "474403931284",
  appId: "1:474403931284:web:54028df72894249d1ce081",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cek apakah Firebase sudah aktif untuk mencegah error "Duplicate App"
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: myFirebaseOptions);
    } catch (e) {
      print("Firebase Init Error: $e");
    }
  }

  // Auto-Create Admin
  try {
    await AuthService().ensureAdminExists();
  } catch (e) {
    print("Gagal cek admin: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const ArchelStoreApp(),
    ),
  );
}

class ArchelStoreApp extends StatelessWidget {
  const ArchelStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Archel Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<UserModel?>(
        stream: authService.userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: LoadingOverlay());
          }
          
          final user = snapshot.data;

          if (user == null) return const LoginScreen();

          if (user.role == 'admin') {
            return const AdminDashboardScreen();
          } else {
            return const UserMainScreen();
          }
        },
      ),
    );
  }
}

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});
  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _idx = 0;
  final List<Widget> _screens = [
    const DashboardScreen(),
    const MyOrderScreen(),
    const ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Pesanan'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}