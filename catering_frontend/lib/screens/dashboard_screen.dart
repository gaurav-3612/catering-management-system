import 'package:flutter/material.dart';
import '../api_service.dart';
import 'menu_generator_screen.dart';
import 'history_screen.dart';
import 'payment_ledger_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // State Variables
  Map<String, dynamic> stats = {
    "total_events": "-",
    "total_guests": "-",
    "projected_revenue": "-",
    "top_cuisine": "-"
  };

  List<dynamic> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Unified Load Function (Fetches Stats AND Orders)
  void _loadStats() async {
    final data = await ApiService.fetchDashboardStats();
    final invoices = await ApiService.fetchInvoices();

    if (mounted) {
      setState(() {
        stats = data;
        _recentOrders = invoices;
      });
    }
  }

  void _markCompleted(int id) async {
    await ApiService.updateOrderStatus(id, "Completed");
    _loadStats(); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Manager Dashboard"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: STATS ---
            const Text("Business Overview",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard("Total Events", stats['total_events'].toString(),
                    Icons.event_available, Colors.blue),
                _buildStatCard(
                    "Guests Served",
                    stats['total_guests'].toString(),
                    Icons.groups,
                    Colors.orange),
                _buildStatCard(
                    "Est. Revenue",
                    stats['projected_revenue'].toString(),
                    Icons.currency_rupee,
                    Colors.green),
                _buildStatCard("Top Cuisine", stats['top_cuisine'].toString(),
                    Icons.restaurant, Colors.purple),
              ],
            ),

            const SizedBox(height: 30),

            // --- SECTION 2: QUICK ACTIONS ---
            const Text("Quick Actions",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildActionButton(
              context,
              "Create New Menu",
              "Generate AI menu for client",
              Icons.add_circle,
              Colors.deepPurple,
              () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MenuGeneratorScreen()))
                  .then((_) => _loadStats()),
            ),

            const SizedBox(height: 15),

            _buildActionButton(
              context,
              "View History",
              "Manage saved menus & PDFs",
              Icons.history,
              Colors.deepPurple.shade300,
              () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()))
                  .then((_) => _loadStats()),
            ),

            const SizedBox(height: 15),

            _buildActionButton(
              context,
              "Payment Ledger",
              "Track paid & pending invoices",
              Icons.account_balance_wallet,
              Colors.green,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PaymentLedgerScreen())),
            ),

            const SizedBox(height: 30),

            // --- SECTION 3: UPCOMING ORDERS ---
            const Text("Upcoming Orders",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            if (_recentOrders.isEmpty)
              const Center(
                  child: Text("No upcoming orders",
                      style: TextStyle(color: Colors.grey))),

            ..._recentOrders.map((order) {
              bool isCompleted = order['order_status'] == "Completed";
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isCompleted ? Colors.grey : Colors.blue.shade100,
                    child: Icon(Icons.event,
                        color: isCompleted ? Colors.white : Colors.blue),
                  ),
                  title: Text(order['client_name'],
                      style: TextStyle(
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null)),
                  subtitle: Text("Date: ${order['event_date'] ?? 'N/A'}"),
                  trailing: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _markCompleted(order['id']),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10)),
                          child: const Text("Mark Done",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                ),
              );
            }).toList(),

            const SizedBox(height: 50),
          ], // <--- This closing bracket was in the wrong place in your code
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
