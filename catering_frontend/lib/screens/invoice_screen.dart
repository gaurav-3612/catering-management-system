import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api_service.dart';
import '../notification_service.dart';
import '../translations.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class InvoiceScreen extends StatefulWidget {
  final int menuId;
  final double baseAmount;

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
      TextEditingController(text: "18");
  final TextEditingController _discountController =
      TextEditingController(text: "0");
  final FocusNode _discountFocusNode = FocusNode();

  double _grandTotal = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _menuDetails; // To store fetched menu items

  String t(String key) => AppTranslations.get(currentLanguage.value, key);

  @override
  void initState() {
    super.initState();
    _calculateTotal();
    _fetchMenuDetails(); // [ADDED] Fetch items for the invoice

    _discountFocusNode.addListener(() {
      if (_discountFocusNode.hasFocus && _discountController.text == "0") {
        _discountController.clear();
      }
    });
  }

  // [ADDED] Fetch menu items to show in PDF
  Future<void> _fetchMenuDetails() async {
    try {
      final menus = await ApiService.fetchSavedMenus();
      final myMenu =
          menus.firstWhere((m) => m['id'] == widget.menuId, orElse: () => null);

      if (myMenu != null) {
        setState(() {
          _menuDetails = jsonDecode(myMenu['menu_json']);
        });
      }
    } catch (e) {
      print("Could not load menu details for invoice: $e");
    }
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _generatePdfInvoice() async {
    final profile = await ApiService.fetchCompanyProfile();

    String companyName = profile['company_name'] ?? "AI Catering Planner";
    String companyAddress = profile['address'] ?? "Generated via App";
    String companyPhone = profile['phone'] ?? "";
    String companyEmail = profile['email'] ?? "";
    String? logoBase64 = profile['logo_base64'];

    pw.MemoryImage? logoImage;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoBase64));
      } catch (e) {
        print("Error decoding logo: $e");
      }
    }

    final pdf = pw.Document();

    // Prepare Invoice Items Table Data
    List<List<String>> tableData = [
      ['Description', 'Details / Amount'], // Header
    ];

    // [UPDATED] Clean the text to remove ₹ symbols
    if (_menuDetails != null) {
      _menuDetails!.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          // 1. Join items
          String items = (value).take(4).join(", ");
          if (value.length > 4) items += " +${value.length - 4} more";

          // 2. FIX: Replace the Rupee symbol with "Rs."
          items = items.replaceAll('₹', 'Rs. ');

          tableData.add([key.toUpperCase(), items]);
        }
      });
    }

    // Add Costs
    tableData.add(['', '']); // Spacer
    tableData.add(['Base Cost', 'Rs. ${widget.baseAmount.toStringAsFixed(2)}']);
    tableData.add([
      'Tax (${_taxController.text}%)',
      '+ Rs. ${(widget.baseAmount * ((double.tryParse(_taxController.text) ?? 0) / 100)).toStringAsFixed(2)}'
    ]);
    tableData.add(['Discount', '- Rs. ${_discountController.text}']);
    tableData.add(['GRAND TOTAL', 'Rs. ${_grandTotal.toStringAsFixed(2)}']);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                            width: 80,
                            height: 80,
                            margin: const pw.EdgeInsets.only(bottom: 10),
                            child: pw.Image(logoImage)),
                      pw.Text(companyName,
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.deepPurple)),
                      pw.Text(companyAddress),
                      if (companyPhone.isNotEmpty)
                        pw.Text("Phone: $companyPhone"),
                      if (companyEmail.isNotEmpty)
                        pw.Text("Email: $companyEmail"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("INVOICE",
                          style: pw.TextStyle(
                              fontSize: 30,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey)),
                      pw.Text(
                          "Date: ${_selectedDate.toString().split(' ')[0]}"),
                      pw.Text("Client: ${_clientController.text}",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  )
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // [UPDATED] DYNAMIC TABLE
              pw.Table.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.deepPurple),
                  data: tableData,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(2),
                  }),

              pw.SizedBox(height: 30),

              // FOOTER & QR
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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('invoice_saved')), backgroundColor: Colors.green));
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
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DashboardScreen()),
                      (route) => false,
                    );
                  },
                )
              ]),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ... (UI Inputs remain exactly the same as your code) ...
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
