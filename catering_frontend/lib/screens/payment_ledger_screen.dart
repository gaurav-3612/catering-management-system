import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api_service.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({super.key});

  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  late Future<List<dynamic>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _invoicesFuture = ApiService.fetchInvoices();
    });
  }

  // --- CSV EXPORT FUNCTION (New Feature) ---
  void _exportToCsv(List<dynamic> invoices) async {
    List<List<dynamic>> rows = [];

    // 1. Add Header Row
    rows.add([
      "Client Name",
      "Event Date",
      "Grand Total",
      "Total Tax",
      "Status",
      "Order Status"
    ]);

    // 2. Add Data Rows
    for (var inv in invoices) {
      rows.add([
        inv['client_name'],
        inv['event_date'],
        inv['grand_total'],
        inv['tax_percent'],
        inv['is_paid'] ? "Paid" : "Pending",
        inv['order_status']
      ]);
    }

    // 3. Convert to CSV String
    String csvData = const ListToCsvConverter().convert(rows);

    // 4. Save to File and Share
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/catering_ledger.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    // 5. Open Share Sheet
    await Share.shareXFiles([XFile(path)], text: 'Here is the Payment Ledger');
  }

  void _showPaymentSheet(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          PaymentDetailSheet(invoice: invoice, onPaymentAdded: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Ledger"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // EXPORT BUTTON
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export to Excel",
            onPressed: () async {
              final data = await _invoicesFuture;
              _exportToCsv(data);
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty)
            return const Center(child: Text("No Invoices Generated Yet"));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final inv = snapshot.data![index];
              bool isPaid = inv['is_paid'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(isPaid ? Icons.check : Icons.access_time,
                        color: isPaid ? Colors.green : Colors.orange),
                  ),
                  title: Text(inv['client_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Total: ₹${inv['grand_total']}"),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(isPaid ? "PAID" : "PENDING",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  onTap: () => _showPaymentSheet(inv),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- SUB-WIDGET: PAYMENT DETAILS SHEET ---
class PaymentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onPaymentAdded;

  const PaymentDetailSheet(
      {super.key, required this.invoice, required this.onPaymentAdded});

  @override
  State<PaymentDetailSheet> createState() => _PaymentDetailSheetState();
}

class _PaymentDetailSheetState extends State<PaymentDetailSheet> {
  final TextEditingController _amountController = TextEditingController();
  List<dynamic> _payments = [];
  double _totalPaid = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await ApiService.fetchPaymentsForInvoice(widget.invoice['id']);
    double paid = 0;
    for (var p in data) {
      paid += (p['amount'] as num).toDouble();
    }
    if (mounted) {
      setState(() {
        _payments = data;
        _totalPaid = paid;
      });
    }
  }

  void _recordPayment() async {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    await ApiService.addPayment(widget.invoice['id'], amount, "Cash");
    _amountController.clear();
    await _loadHistory();
    widget.onPaymentAdded();
  }

  @override
  Widget build(BuildContext context) {
    double grandTotal = (widget.invoice['grand_total'] as num).toDouble();
    double balance = grandTotal - _totalPaid;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Ledger: ${widget.invoice['client_name']}",
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          _row("Grand Total", "₹$grandTotal"),
          _row("Total Paid", "₹$_totalPaid", color: Colors.green),
          _row("Balance Due", "₹${balance < 0 ? 0 : balance}",
              color: Colors.red, isBold: true),
          const SizedBox(height: 20),
          const Text("History:", style: TextStyle(fontWeight: FontWeight.bold)),
          ..._payments.map((p) => ListTile(
                dense: true,
                title: Text("Received ₹${p['amount']}"),
                subtitle:
                    Text(p['payment_date'] + " (" + p['payment_mode'] + ")"),
                leading: const Icon(Icons.check_circle,
                    color: Colors.green, size: 16),
              )),
          if (balance > 0) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter Payment Amount",
                suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepPurple),
                    onPressed: _recordPayment),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _row(String label, String val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(val,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}
