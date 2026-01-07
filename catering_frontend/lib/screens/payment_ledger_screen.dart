import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api_service.dart';
import '../translations.dart';
import '../main.dart';

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

  // Helper for CSV Export (Kept mostly in English for standard data format)
  void _exportToCsv(List<dynamic> invoices) async {
    List<List<dynamic>> rows = [];
    rows.add([
      "Client Name",
      "Event Date",
      "Grand Total",
      "Total Tax",
      "Status",
      "Order Status"
    ]);

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

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/catering_ledger.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'Payment Ledger Export');
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
    // Listen to language changes
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        // Helper
        String t(String key) => AppTranslations.get(lang, key);

        return Scaffold(
          appBar: AppBar(
            title: Text(t('payment_ledger_title')), // Translated
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: t('export_csv'), // Translated
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(t('no_invoices'))); // Translated
              }

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final inv = snapshot.data![index];
                  double grandTotal =
                      double.tryParse(inv['grand_total'].toString()) ?? 0.0;
                  bool isPaid = inv['is_paid'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 3,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPaid
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(isPaid ? Icons.check : Icons.access_time,
                            color: isPaid ? Colors.green : Colors.orange),
                      ),
                      title: Text(
                          inv['client_name'] ??
                              t('unknown_client'), // Translated
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          "${t('invoice_amount')}: ₹${grandTotal.toStringAsFixed(2)}"), // Translated
                      trailing: Chip(
                        label: Text(isPaid ? t('paid') : t('due'), // Translated
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                        backgroundColor: isPaid ? Colors.green : Colors.orange,
                      ),
                      onTap: () => _showPaymentSheet(inv),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _payments = [];
    _totalPaid = 0;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data =
          await ApiService.fetchPaymentsForInvoice(widget.invoice['id']);
      double paid = 0;
      for (var p in data) {
        paid += double.tryParse(p['amount'].toString()) ?? 0.0;
      }
      if (mounted) {
        setState(() {
          _payments = data;
          _totalPaid = paid;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recordPayment() async {
    double amountToAdd = double.tryParse(_amountController.text) ?? 0;
    if (amountToAdd <= 0) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    await ApiService.addPayment(widget.invoice['id'], amountToAdd, "Cash");
    _amountController.clear();
    await _loadHistory();
    widget.onPaymentAdded();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes for the BottomSheet
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        // Helper
        String t(String key) => AppTranslations.get(lang, key);

        double grandTotal =
            double.tryParse(widget.invoice['grand_total'].toString()) ?? 0.0;

        // --- CALCULATION FIX ---
        double balance = grandTotal - _totalPaid;
        if (balance < 0.01) {
          balance = 0;
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Ledger: ${widget.invoice['client_name']}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadHistory)
                  ],
                ),
                const Divider(),
                _row(t('invoice_amount'),
                    "₹${grandTotal.toStringAsFixed(2)}"), // Translated
                _row(t('total_received'), "₹${_totalPaid.toStringAsFixed(2)}",
                    color: Colors.green), // Translated
                _row(t('balance_due'), "₹${balance.toStringAsFixed(2)}",
                    color: balance > 0 ? Colors.red : Colors.grey,
                    isBold: true), // Translated

                const SizedBox(height: 20),
                Text(t('history'), // Translated
                    style: const TextStyle(fontWeight: FontWeight.bold)),

                if (_isLoading)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()))
                else if (_payments.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(t('no_payments'))), // Translated

                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final p = _payments[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        // Translated "Received"
                        title: Text("${t('received')} ₹${p['amount']}"),
                        subtitle: Text(
                            "${p['payment_date']} via ${p['payment_mode']}"),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // --- PAYMENT INPUT ---
                if (balance > 0) ...[
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: t('enter_payment'), // Translated
                      hintText: "${t('due')}: ₹${balance.toStringAsFixed(2)}",
                      suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.send, color: Colors.deepPurple),
                          onPressed: _recordPayment),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    color: Colors.green.shade100,
                    child: Center(
                        child: Text(t('paid_full'), // Translated
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))),
                  )
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
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
