import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api_service.dart';
import '../notification_service.dart';
import '../translations.dart';
import '../main.dart';

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

  final FocusNode _discountFocusNode = FocusNode();

  double _grandTotal = 0;
  DateTime _selectedDate = DateTime.now();

  String t(String key) {
    return AppTranslations.get(currentLanguage.value, key);
  }

  @override
  void initState() {
    super.initState();
    _calculateTotal();

    _discountFocusNode.addListener(() {
      if (_discountFocusNode.hasFocus && _discountController.text == "0") {
        _discountController.clear();
      }
    });
  }

  @override
  void dispose() {
    _discountFocusNode.dispose();
    _clientController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    super.dispose();
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

  // --- PDF GENERATION (UPDATED WITH COMPANY PROFILE) ---
  Future<void> _generatePdfInvoice() async {
    // 1. Fetch Company Profile
    final profile = await ApiService.fetchCompanyProfile();

    // 2. Set Default Values if profile is empty
    String companyName = profile['company_name'] ?? "AI Catering Planner";
    String companyAddress = profile['address'] ?? "Generated via App";
    String companyPhone = profile['phone'] ?? "";
    String companyEmail = profile['email'] ?? "";
    String companyGst = profile['gst_number'] ?? "";

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER SECTION ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LEFT: Company Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName,
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.deepPurple)),
                      pw.SizedBox(height: 5),
                      pw.Text(companyAddress),
                      if (companyPhone.isNotEmpty)
                        pw.Text("Phone: $companyPhone"),
                      if (companyEmail.isNotEmpty)
                        pw.Text("Email: $companyEmail"),
                      if (companyGst.isNotEmpty)
                        pw.Text("GSTIN: $companyGst",
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),

                  // RIGHT: Invoice Label
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("INVOICE",
                            style: pw.TextStyle(
                                fontSize: 30,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey)),
                        pw.SizedBox(height: 5),
                        pw.Text(
                            "Date: ${_selectedDate.toString().split(' ')[0]}"),
                        pw.Text("Client: ${_clientController.text}",
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ])
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // --- INVOICE ITEMS TABLE ---
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.deepPurple),
                data: <List<String>>[
                  <String>['Description', 'Amount'],
                  <String>[
                    'Catering Service Base Cost',
                    'Rs. ${widget.baseAmount.toStringAsFixed(2)}'
                  ],
                  <String>[
                    'Tax (${_taxController.text}%)',
                    '+ Rs. ${(widget.baseAmount * ((double.tryParse(_taxController.text) ?? 0) / 100)).toStringAsFixed(2)}'
                  ],
                  <String>['Discount', '- Rs. ${_discountController.text}'],
                  <String>[
                    'GRAND TOTAL',
                    'Rs. ${_grandTotal.toStringAsFixed(2)}'
                  ],
                ],
              ),

              pw.SizedBox(height: 30),

              // --- FOOTER WITH QR ---
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Terms & Conditions:",
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text("1. Please pay within 7 days."),
                          pw.Text("2. Thank you for your business!"),
                        ]),
                    // QR Code for UPI
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data:
                          "upi://pay?pa=$companyPhone@upi&pn=${Uri.encodeComponent(companyName)}&am=$_grandTotal&cu=INR",
                      width: 70,
                      height: 70,
                    ),
                  ])
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'invoice_${_clientController.text}.pdf');
  }

  void _finalizeInvoice() async {
    if (_clientController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('enter_client_name'))));
      return;
    }

    try {
      await ApiService.saveInvoice(
        menuId: widget.menuId,
        clientName: _clientController.text,
        finalAmount: widget.baseAmount,
        taxPercent: double.tryParse(_taxController.text) ?? 0,
        discount: double.tryParse(_discountController.text) ?? 0,
        grandTotal: _grandTotal,
        eventDate: "${_selectedDate.toLocal()}".split(' ')[0],
      );

      await NotificationService.scheduleEventDayReminder(
        title: "Catering Reminder",
        body: "Event for ${_clientController.text} is coming up!",
        eventDate: _selectedDate,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('invoice_saved')),
          backgroundColor: Colors.green,
        ),
      );

      await _generatePdfInvoice();
    } catch (e) {
      print("ERROR SAVING INVOICE: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
              title: Text(t('generate_invoice')),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text("${t('event_date')}: ",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
                  decoration: InputDecoration(
                      labelText: t('client_name'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taxController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: t('tax_gst'),
                            border: const OutlineInputBorder()),
                        onChanged: (val) => _calculateTotal(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        focusNode: _discountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: t('discount'),
                            border: const OutlineInputBorder()),
                        onChanged: (val) => _calculateTotal(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      Text(t('invoice_preview'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      _row(t('subtotal'),
                          "₹${widget.baseAmount.toStringAsFixed(0)}"),
                      _row(t('tax_gst'),
                          "+ ₹${(widget.baseAmount * ((double.tryParse(_taxController.text) ?? 0) / 100)).toStringAsFixed(0)}",
                          color: Colors.red),
                      _row(t('discount'), "- ₹${_discountController.text}",
                          color: Colors.green),
                      const Divider(),
                      _row(t('grand_total'),
                          "₹${_grandTotal.toStringAsFixed(0)}",
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
                    label: Text(t('save_generate_pdf')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
