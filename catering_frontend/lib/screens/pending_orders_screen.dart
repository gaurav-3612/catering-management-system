import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchPendingOrders();

      // AUTO-SORTING: Upcoming dates first
      data.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['event_date']) ?? DateTime.now();
        DateTime dateB = DateTime.tryParse(b['event_date']) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- [OPTIMIZED] VIEW MENU LOGIC ---
  // Uses the new /orders/get/ endpoint instead of loading all menus
  Future<void> _viewMenuForOrder(int invoiceId) async {
    // Show loading indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call the new specific endpoint
      final orderDetails = await ApiService.fetchOrderDetails(invoiceId);

      Navigator.pop(context); // Close loading indicator

      if (orderDetails.isNotEmpty && orderDetails['menu_details'] != null) {
        // Direct access to the menu data provided by the backend
        _showMenuDialog(orderDetails['menu_details']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Menu data unavailable.")));
      }
    } catch (e) {
      Navigator.pop(context); // Close loading indicator on error
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showMenuDialog(Map<String, dynamic> menuData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Catering Menu",
              style: TextStyle(color: Colors.deepPurple)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: menuData.entries.map((entry) {
                if (entry.value is! List || (entry.value as List).isEmpty)
                  return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(entry.key.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple)),
                    ),
                    ...entry.value.map((item) =>
                        Text("• $item", style: const TextStyle(fontSize: 14))),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"))
          ],
        );
      },
    );
  }

  // --- VIEW INVOICE LOGIC ---
  void _viewInvoiceForOrder(dynamic order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Invoice #${order['id']}",
              style: const TextStyle(color: Colors.green)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Client: ${order['client_name']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Total Amount: ₹${order['final_amount']}"),
              Text("Tax: ${order['tax_percent']}%"),
              Text("Discount: -₹${order['discount_amount']}"),
              const Divider(),
              Text("Grand Total: ₹${order['grand_total']}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 10),
              Text("Status: ${order['is_paid'] ? 'PAID' : 'BALANCE DUE'}",
                  style: TextStyle(
                      color: order['is_paid'] ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"))
          ],
        );
      },
    );
  }

  // --- DEADLINE NOTIFICATION ---
  void _scheduleDeadlineNotification(String eventDate) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.alarm, color: Colors.white),
        const SizedBox(width: 10),
        Text("Reminder set for $eventDate")
      ]),
      backgroundColor: Colors.deepPurple,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Operational Dashboard"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text("No upcoming events."))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    var order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 8),
                      elevation: 3,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        title: Text(
                            "${order['event_type'] ?? 'Event'} - ${order['client_name'] ?? 'Client'}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(
                                  "${order['event_date']}  |  ${order['guest_count'] ?? '-'} Guests"),
                            ]),
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: Colors.blue),
                              const SizedBox(width: 5),
                              Text("Status: ${order['order_status']}",
                                  style: const TextStyle(color: Colors.blue)),
                            ]),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle,
                                size: 12,
                                color: order['is_paid']
                                    ? Colors.green
                                    : Colors.red),
                            const SizedBox(height: 4),
                            Text(order['is_paid'] ? "Paid" : "Bal.",
                                style: TextStyle(
                                    color: order['is_paid']
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onTap: () => _showOrderOptions(context, order),
                      ),
                    );
                  },
                ),
    );
  }

  void _showOrderOptions(BuildContext context, dynamic order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Text("Manage: ${order['client_name']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(),

            // OPTION 1: VIEW MENU (Now calls specific endpoint)
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Colors.orange),
              title: const Text("View Menu Details"),
              onTap: () {
                Navigator.pop(context);
                // We pass the INVOICE ID here to fetch linked menu details
                _viewMenuForOrder(order['id']);
              },
            ),

            // OPTION 2: VIEW INVOICE
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: const Text("Quick Access to Invoice"),
              onTap: () {
                Navigator.pop(context);
                _viewInvoiceForOrder(order);
              },
            ),

            // OPTION 3: REMINDER
            ListTile(
              leading: const Icon(Icons.notification_add, color: Colors.purple),
              title: const Text("Set Deadline Reminder"),
              onTap: () {
                Navigator.pop(context);
                _scheduleDeadlineNotification(order['event_date']);
              },
            ),

            // OPTION 4: MARK COMPLETED
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text("Mark as Completed"),
              onTap: () async {
                Navigator.pop(context);
                await ApiService.updateOrderStatus(order['id'], "Completed");
                _loadData();
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
