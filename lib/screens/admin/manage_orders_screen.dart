import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Import Service
import '../../services/db_service.dart';
import '../../services/notif_service.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // Background abu sangat muda
        
        // 1. APP BAR KHUSUS (Hanya Judul)
        appBar: AppBar(
          title: const Text("Kelola Pesanan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),

        // 2. BODY (Search + Tab + List)
        body: Column(
          children: [
            // Area Search Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: Colors.white,
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: "Cari ID Order...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            
            // Area Tab Bar
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFFE91E63),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFFE91E63),
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: "Diproses"),
                  Tab(text: "Selesai"),
                  Tab(text: "Dibatalkan"),
                ],
              ),
            ),

            // Area Isi (List)
            Expanded(
              child: TabBarView(
                children: [
                  _OrderList(statusFilter: const ['Diproses', 'Menunggu'], searchQuery: _searchQuery),
                  _OrderList(statusFilter: const ['Selesai'], searchQuery: _searchQuery),
                  _OrderList(statusFilter: const ['Dibatalkan'], searchQuery: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<String> statusFilter;
  final String searchQuery;

  const _OrderList({required this.statusFilter, required this.searchQuery});

  // Fungsi Konfirmasi
  void _confirmAction(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Batal", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
            child: const Text("Konfirmasi"),
          ),
        ],
      ),
    );
  }

  // Fungsi Copy ID
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("ID Order $text disalin"), 
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final DbService db = DbService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('orders').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildEmptyState();
        }

        Map map = snapshot.data!.snapshot.value as Map;
        List<MapEntry> allOrders = map.entries.toList();

        // FILTER LOGIC
        List<MapEntry> filteredOrders = allOrders.where((entry) {
          String status = entry.value['status'] ?? '';
          String oid = entry.key;
          
          // 1. Cek Status Tab
          bool matchStatus = statusFilter.contains(status);
          
          // 2. Cek Search Query (Berdasarkan ID Order)
          bool matchSearch = oid.toLowerCase().contains(searchQuery);

          return matchStatus && matchSearch;
        }).toList();

        // Sortir Terbaru
        filteredOrders.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

        if (filteredOrders.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (ctx, i) {
            String oid = filteredOrders[i].key;
            Map data = filteredOrders[i].value;
            String status = data['status'];
            String uid = data['uid'];
            String paymentMethod = data['paymentMethod'] ?? 'cash';
            double total = double.parse(data['total'].toString());
            List items = data['items'] ?? [];

            // Warna Status
            Color statusColor = Colors.orange;
            IconData statusIcon = Icons.inventory_2_outlined;
            if (status == 'Selesai') { statusColor = Colors.green; statusIcon = Icons.check_circle_outline; }
            if (status == 'Dibatalkan') { statusColor = Colors.red; statusIcon = Icons.cancel_outlined; }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.all(16),
                  
                  // Header Kartu
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Row(
                    children: [
                      Text(
                        "Id Order: ...${oid.substring(oid.length - 5)}", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copyToClipboard(context, oid),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.copy, size: 14, color: Colors.grey),
                        ),
                      )
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(fmt.format(total), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.payment, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            paymentMethod == 'saldo' ? 'Arc Coin' : 'Tunai',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Isi Detail (Expanded)
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Detail Barang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 10),
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(item['imageUrl'], width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (c,o,s) => Container(width: 40, height: 40, color: Colors.grey[300])),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text("${fmt.format(item['price'])} x ${item['qty']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Tombol Aksi (Hanya jika status Diproses)
                    if (statusFilter.contains('Diproses'))
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _confirmAction(context, "Tolak Pesanan?", "Stok akan dikembalikan dan saldo user di-refund.", () {
                                  db.adminUpdateOrderStatus(
                                    oid: oid, uid: uid, newStatus: 'Dibatalkan', 
                                    items: items, total: total, paymentMethod: paymentMethod
                                  );
                                  NotifService.showSuccess("Pesanan Ditolak");
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text("Tolak"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _confirmAction(context, "Selesaikan Pesanan?", "Transaksi akan dicatat sebagai 'Terjual'.", () {
                                  db.adminUpdateOrderStatus(
                                    oid: oid, uid: uid, newStatus: 'Selesai', 
                                    items: items, total: total, paymentMethod: paymentMethod
                                  );
                                  NotifService.showSuccess("Pesanan Selesai");
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text("Selesai"),
                            ),
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Status: ${status.toUpperCase()}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 1),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            searchQuery.isEmpty ? "Tidak ada pesanan" : "ID Order tidak ditemukan", 
            style: TextStyle(color: Colors.grey[500], fontSize: 16)
          ),
        ],
      ),
    );
  }
}