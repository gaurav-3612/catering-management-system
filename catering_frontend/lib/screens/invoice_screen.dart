import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api_service.dart';

class InvoiceScreen extends StatefulWidget {
  final int menuId;
  final double baseAmount; // Amount from Pricing Screen

  const InvoiceScreen({
    super.key,
    required this.menuId,
    required this.baseAmount,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _taxController =
      TextEditingController(text: "18"); // Default 18% GST
  final TextEditingController _discountController =
      TextEditingController(text: "0");

  double _grandTotal = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _calculateTotal();
  }

  void _calculateTotal() {
    double tax = double.tryParse(_taxController.text) ?? 0;
    double discount = double.tryParse(_discountController.text) ?? 0;

    double taxAmount = widget.baseAmount * (tax / 100);
    setState(() {
      _grandTotal = (widget.baseAmount + taxAmount) - discount;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- PDF GENERATION WITH QR CODE ---
  Future<void> _generatePdfInvoice() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. HEADER WITH QR CODE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("INVOICE",
                            style: pw.TextStyle(
                                fontSize: 40, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            "Date: ${_selectedDate.toString().split(' ')[0]}"),
                        pw.Text("Client: ${_clientController.text}",
                            style: const pw.TextStyle(fontSize: 18)),
                      ]),
                  // QR CODE WIDGET (Built-in to pdf package)
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data:
                        "upi://pay?pa=catering@upi&pn=CateringService&am=$_grandTotal&cu=INR", // Simulated UPI Link
                    width: 80,
                    height: 80,
                  ),
                ],
              ),

              pw.Divider(),
              pw.SizedBox(height: 20),

              // 2. INVOICE TABLE
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Description', 'Amount'],
                  <String>[
                    'Catering Service Base Cost',
                    'Rs. ${widget.baseAmount.toStringAsFixed(2)}'
                  ],
                  <String>[
                    'Tax (${_taxController.text}%)',
                    '+ Rs. ${(widget.baseAmount * (double.parse(_taxController.text) / 100)).toStringAsFixed(2)}'
                  ],
                  <String>['Discount', '- Rs. ${_discountController.text}'],
                  <String>[
                    'GRAND TOTAL',
                    'Rs. ${_grandTotal.toStringAsFixed(2)}'
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text("Scan QR Code to Pay via UPI",
                  style:
                      const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
              pw.Text("Thank you for your business!",
                  style:
                      const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'invoice_${_clientController.text}.pdf');
  }

  // Save to DB and Generate PDF
  void _finalizeInvoice() async {
    if (_clientController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter Client Name")));
      return;
    }

    try {
      // 1. Save to Database
      await ApiService.saveInvoice(
        menuId: widget.menuId,
        clientName: _clientController.text,
        finalAmount: widget.baseAmount,
        taxPercent: double.parse(_taxController.text),
        discount: double.parse(_discountController.text),
        grandTotal: _grandTotal,
        eventDate: "${_selectedDate.toLocal()}".split(' ')[0],
      );

      // 2. Generate PDF
      await _generatePdfInvoice();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Generate Invoice"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Date Picker Row
            Row(
              children: [
                const Text("Event Date: ",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today,
                      color: Colors.deepPurple),
                  label: Text("${_selectedDate.toLocal()}".split(' ')[0],
                      style: const TextStyle(
                          fontSize: 16, color: Colors.deepPurple)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _clientController,
              decoration: const InputDecoration(
                  labelText: "Client Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Tax % (GST)", border: OutlineInputBorder()),
                    onChanged: (val) => _calculateTotal(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Discount (Rs)",
                        border: OutlineInputBorder()),
                    onChanged: (val) => _calculateTotal(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  const Text("Invoice Preview",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _row("Subtotal", "₹${widget.baseAmount.toStringAsFixed(0)}"),
                  _row("Tax",
                      "+ ₹${(widget.baseAmount * (double.parse(_taxController.text) / 100)).toStringAsFixed(0)}",
                      color: Colors.red),
                  _row("Discount", "- ₹${_discountController.text}",
                      color: Colors.green),
                  const Divider(),
                  _row("Grand Total", "₹${_grandTotal.toStringAsFixed(0)}",
                      isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _finalizeInvoice,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Save & Generate PDF"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}
