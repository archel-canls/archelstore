import 'package:flutter/material.dart';

// Import Halaman Admin
import 'manage_products_screen.dart';
import 'manage_orders_screen.dart';
import 'manage_users_screen.dart'; // Pastikan file ini ada
import 'admin_profile_screen.dart'; // Pastikan file ini ada

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _idx = 0;
  
  final List<Widget> _pages = [
    const ManageProductsScreen(), // 0: Manajemen Produk (Search bar ada di sini)
    const ManageOrdersScreen(),   // 1: Pesanan
    const ManageUsersScreen(),    // 2: User
    const AdminProfileScreen(),   // 3: Profil
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // AppBar dihapus dari sini agar setiap halaman bisa custom header
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: Colors.white,
        elevation: 5,
        indicatorColor: const Color(0xFFE91E63).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined), 
            selectedIcon: Icon(Icons.inventory_2, color: Color(0xFFE91E63)),
            label: "Produk"
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt), 
            selectedIcon: Icon(Icons.list_alt, color: Color(0xFFE91E63)),
            label: "Pesanan"
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline), 
            selectedIcon: Icon(Icons.people, color: Color(0xFFE91E63)),
            label: "User"
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person, color: Color(0xFFE91E63)),
            label: "Profil"
          ),
        ],
      ),
    );
  }
}