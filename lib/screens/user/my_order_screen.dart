import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/notif_service.dart';

class MyOrderScreen extends StatefulWidget {
  const MyOrderScreen({super.key});

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen> {
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
        backgroundColor: const Color(0xFFF5F5F5), // Background abu sangat muda
        
        // 1. APP BAR
        appBar: AppBar(
          title: const Text("Pesanan Saya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, 
        ),

        body: Column(
          children: [
            // 2. SEARCH BAR & TABS
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const TabBar(
                    labelColor: Color(0xFFE91E63),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFFE91E63),
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: [
                      Tab(text: "Diproses"),
                      Tab(text: "Selesai"),
                      Tab(text: "Dibatalkan"),
                    ],
                  ),
                ],
              ),
            ),

            // 3. ORDER LIST
            Expanded(
              child: TabBarView(
                children: [
                  _UserOrderList(statusFilter: const ['Diproses', 'Menunggu'], searchQuery: _searchQuery),
                  _UserOrderList(statusFilter: const ['Selesai'], searchQuery: _searchQuery),
                  _UserOrderList(statusFilter: const ['Dibatalkan'], searchQuery: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserOrderList extends StatelessWidget {
  final List<String> statusFilter;
  final String searchQuery;

  const _UserOrderList({required this.statusFilter, required this.searchQuery});

  // Fungsi Konfirmasi Batalkan
  void _confirmCancel(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Batalkan Pesanan?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Pesanan akan dibatalkan. Jika menggunakan saldo, dana akan dikembalikan."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kembali", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Ya, Batalkan"),
          ),
        ],
      ),
    );
  }

  // Dialog Rating
  void _showRatingDialog(BuildContext context, String oid, List items) {
    int selectedStars = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Beri Penilaian", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Bagaimana pengalaman belanja Anda?", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        index < selectedStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                      onPressed: () => setDialogState(() => selectedStars = index + 1),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text("$selectedStars Bintang", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Nanti Saja", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  DbService().submitRating(oid, items, selectedStars);
                  Navigator.pop(ctx);
                  NotifService.showSuccess("Terima kasih atas penilaian Anda!");
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                child: const Text("Kirim"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("ID Order $text disalin"), 
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.all(20),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    if (user == null) return const SizedBox();

    final DbService db = DbService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('orders').orderByChild('uid').equalTo(user.uid).onValue,
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
          bool matchStatus = statusFilter.contains(status);
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
            String paymentMethod = data['paymentMethod'] ?? 'cash';
            double total = double.parse(data['total'].toString());
            List items = data['items'] ?? [];
            bool isRated = data['isRated'] ?? false;

            // Config Warna Status
            Color statusColor;
            String statusText;
            IconData statusIcon;

            if (status == 'Selesai') {
              statusColor = Colors.green;
              statusText = "Selesai";
              statusIcon = Icons.check_circle;
            } else if (status == 'Dibatalkan') {
              statusColor = Colors.red;
              statusText = "Dibatalkan";
              statusIcon = Icons.cancel;
            } else {
              statusColor = Colors.orange;
              statusText = "Diproses";
              statusIcon = Icons.inventory_2;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // HEADER KARTU (ID & Status)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.black54),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text("Order #${oid.substring(oid.length - 5)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 5),
                                    InkWell(
                                      onTap: () => _copyToClipboard(context, oid),
                                      child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                                    )
                                  ],
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(data['timestamp'])),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // BODY (List Item)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover,
                                  errorBuilder: (c,o,s) => Container(width: 50, height: 50, color: Colors.grey[200]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("${item['qty']} x ${fmt.format(item['price'])}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        
                        const SizedBox(height: 10),
                        
                        // Total Payment
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(paymentMethod == 'saldo' ? 'Via: Arc Coin' : 'Via: Tunai', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Total Belanja", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(fmt.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE91E63))),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // FOOTER (Action Buttons)
                  if (statusFilter.contains('Diproses') || (statusFilter.contains('Selesai') && !isRated))
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          if (statusFilter.contains('Diproses'))
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _confirmCancel(context, () {
                                    db.userCancelOrder(oid, user.uid, items, total, paymentMethod);
                                    NotifService.showSuccess("Pesanan Dibatalkan");
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("Batalkan Pesanan"),
                              ),
                            ),
                          
                          if (statusFilter.contains('Selesai') && !isRated)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showRatingDialog(context, oid, items),
                                icon: const Icon(Icons.star_rate_rounded, size: 18),
                                label: const Text("Beri Nilai"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber, 
                                  foregroundColor: Colors.black, 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                  if (isRated && statusFilter.contains('Selesai'))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 5),
                          Text("Anda memberi ${data['ratingScore']} Bintang", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                        ],
                      ),
                    )
                ],
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
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Belum ada pesanan", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}