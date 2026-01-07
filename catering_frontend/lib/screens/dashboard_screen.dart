import 'package:flutter/material.dart';
import '../api_service.dart';
import '../translations.dart';
import '../main.dart';
import 'menu_generator_screen.dart';
import 'history_screen.dart';
import 'payment_ledger_screen.dart';
import 'login_screen.dart'; // ✅ Import Login Screen
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  Future<void> _loadStats() async {
    // ApiService automatically sends the currentUserId now!
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
    _loadStats();
  }

  // Helper Function for Translation
  String t(String key, String lang) {
    return AppTranslations.get(lang, key);
  }

  // ✅ LOGOUT FUNCTION
  void _logout() {
    // 1. Clear the Session ID
    ApiService.currentUserId = null;

    // 2. Navigate back to Login and remove Dashboard from history
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(t('dashboard_title', lang)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            actions: [
              // LANGUAGE DROPDOWN
              DropdownButton<String>(
                value: lang,
                dropdownColor: Colors.deepPurple,
                icon: const Icon(Icons.language, color: Colors.white),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                      value: 'en',
                      child: Text("English",
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'hi',
                      child:
                          Text("हिंदी", style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'te',
                      child: Text("తెలుగు",
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'ta',
                      child:
                          Text("தமிழ்", style: TextStyle(color: Colors.white))),
                ],
                onChanged: (String? val) {
                  if (val != null) {
                    currentLanguage.value = val;
                  }
                },
              ),
              const SizedBox(width: 10),
              // SETTINGS BUTTON
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Settings",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

              // ✅ LOGOUT BUTTON
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: "Logout",
                onPressed: _logout,
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadStats,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('business_overview', lang),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                    children: [
                      _buildStatCard(
                          t('total_events', lang),
                          stats['total_events'].toString(),
                          Icons.event_available,
                          Colors.blue),
                      _buildStatCard(
                          t('guests_served', lang),
                          stats['total_guests'].toString(),
                          Icons.groups,
                          Colors.orange),
                      _buildStatCard(
                          t('est_revenue', lang),
                          stats['projected_revenue'].toString(),
                          Icons.currency_rupee,
                          Colors.green),
                      _buildStatCard(
                          t('top_cuisine', lang),
                          stats['top_cuisine'].toString(),
                          Icons.restaurant,
                          Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(t('quick_actions', lang),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildActionButton(
                    context,
                    t('create_menu', lang),
                    t('create_menu_desc', lang),
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
                    t('view_history', lang),
                    t('view_history_desc', lang),
                    Icons.history,
                    Colors.deepPurple.shade300,
                    () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()))
                        .then((_) => _loadStats()),
                  ),
                  const SizedBox(height: 15),
                  _buildActionButton(
                    context,
                    t('payment_ledger', lang),
                    t('payment_ledger_desc', lang),
                    Icons.account_balance_wallet,
                    Colors.green,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PaymentLedgerScreen())),
                  ),
                  const SizedBox(height: 30),
                  Text(t('upcoming_orders', lang),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  if (_recentOrders.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                          child: Text("No upcoming orders found.",
                              style: TextStyle(color: Colors.grey))),
                    ),
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
                        title: Text(order['client_name'] ?? "Unknown"),
                        subtitle: Text("Date: ${order['event_date']}"),
                        trailing: isCompleted
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : ElevatedButton(
                                onPressed: () => _markCompleted(order['id']),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: Text(t('mark_done', lang),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
            Expanded(
              child: Column(
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
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
