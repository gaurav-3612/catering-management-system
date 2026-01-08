import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';
import '../translations.dart';
import '../main.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({super.key});

  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  late Future<List<dynamic>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _ledgerFuture = ApiService.fetchPaymentLedger();
    });
  }

  // --- EXPORT TO SPREADSHEET (FIXED) ---
  void _exportToCsv(List<dynamic> ledgerData) async {
    List<List<dynamic>> rows = [];
    rows.add([
      "Client Name",
      "Event Date",
      "Total Amount",
      "Amount Paid",
      "Balance Due",
      "Status",
      "Order Status"
    ]);

    for (var item in ledgerData) {
      // [FIX] Ensure date is clean string to avoid ###
      String cleanDate = item['event_date'].toString().split(' ')[0];

      rows.add([
        item['client_name'],
        cleanDate, // Uses clean YYYY-MM-DD
        item['total_amount'],
        item['amount_paid'],
        item['balance_due'],
        item['status'],
        item['order_status']
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/catering_ledger.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'Payment Ledger Export');
  }

  void _showPaymentSheet(Map<String, dynamic> ledgerItem) {
    Map<String, dynamic> invoiceData = {
      'id': ledgerItem['invoice_id'],
      'client_name': ledgerItem['client_name'],
      'grand_total': ledgerItem['total_amount']
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          PaymentDetailSheet(invoice: invoiceData, onPaymentAdded: _refresh),
    );
  }

  // --- COLOR-CODED STATUSES ---
  Color _getStatusColor(String status) {
    switch (status) {
      case "Paid":
        return Colors.green;
      case "Partial":
        return Colors.orange;
      case "Pending":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- WHATSAPP REMINDER ---
  void _sendWhatsAppReminder(
      String clientName, String eventDate, double balance) async {
    String message = "Hello $clientName, reminder for event on $eventDate. "
        "Balance of Rs. ${balance.toStringAsFixed(2)} is due.";

    String encodedMessage = Uri.encodeComponent(message);
    Uri whatsappUrl = Uri.parse("whatsapp://send?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        Share.share(message);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open WhatsApp")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        String t(String key) => AppTranslations.get(lang, key);

        return Scaffold(
          appBar: AppBar(
            title: Text(t('payment_ledger_title')),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: t('export_csv'),
                onPressed: () async {
                  final data = await _ledgerFuture;
                  _exportToCsv(data);
                },
              )
            ],
          ),
          body: FutureBuilder<List<dynamic>>(
            future: _ledgerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(t('no_invoices')));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  String status = item['status'];
                  double balance =
                      double.tryParse(item['balance_due'].toString()) ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 3,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor:
                            _getStatusColor(status).withOpacity(0.1),
                        child: Icon(
                          status == "Paid" ? Icons.check : Icons.access_time,
                          color: _getStatusColor(status),
                        ),
                      ),
                      title: Text(item['client_name'] ?? t('unknown_client'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(
                              "${t('invoice_amount')}: Rs. ${item['total_amount']}"), // Fixed symbol
                          Text(
                              "${t('balance_due')}: Rs. ${balance.toStringAsFixed(2)}", // Fixed symbol
                              style: TextStyle(
                                  color:
                                      balance > 0 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (balance > 0)
                            IconButton(
                              icon: const Icon(Icons.mark_chat_unread,
                                  color: Colors.green, size: 24),
                              tooltip: "Send WhatsApp Reminder",
                              onPressed: () => _sendWhatsAppReminder(
                                  item['client_name'],
                                  item['event_date'],
                                  balance),
                            ),
                          Chip(
                            label: Text(status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            backgroundColor: _getStatusColor(status),
                          ),
                        ],
                      ),
                      onTap: () => _showPaymentSheet(item),
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

  void _editPayment(int paymentId, double currentAmount, String currentMode) {
    final editCtrl = TextEditingController(text: currentAmount.toString());
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Edit Payment"),
              content: TextField(
                controller: editCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Correct Amount",
                    prefixText: "Rs. "), // Fixed symbol
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      await ApiService.updatePayment(
                          paymentId, double.parse(editCtrl.text), currentMode);
                      _loadHistory();
                      widget.onPaymentAdded();
                    },
                    child: const Text("Update"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        String t(String key) => AppTranslations.get(lang, key);

        double grandTotal =
            double.tryParse(widget.invoice['grand_total'].toString()) ?? 0.0;
        double balance = grandTotal - _totalPaid;
        if (balance < 0.01) balance = 0;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Ledger: ${widget.invoice['client_name']}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                _row(t('invoice_amount'),
                    "Rs. ${grandTotal.toStringAsFixed(2)}"), // Fixed symbol
                _row(
                    t('total_received'), "Rs. ${_totalPaid.toStringAsFixed(2)}",
                    color: Colors.green), // Fixed symbol
                _row(t('balance_due'),
                    "Rs. ${balance.toStringAsFixed(2)}", // Fixed symbol
                    color: balance > 0 ? Colors.red : Colors.grey,
                    isBold: true),
                const SizedBox(height: 20),

                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_payments.isEmpty)
                  Text(t('no_payments')),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final p = _payments[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      title: Text(
                          "${t('received')} Rs. ${p['amount']}"), // Fixed symbol
                      subtitle:
                          Text("${p['payment_date']} via ${p['payment_mode']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit,
                            size: 16, color: Colors.grey),
                        onPressed: () => _editPayment(
                            p['id'], p['amount'], p['payment_mode']),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),
                if (balance > 0)
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: t('enter_payment'),
                      hintText:
                          "${t('due')}: Rs. ${balance.toStringAsFixed(2)}", // Fixed symbol
                      suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.send, color: Colors.deepPurple),
                          onPressed: _recordPayment),
                      border: const OutlineInputBorder(),
                    ),
                  ),
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
