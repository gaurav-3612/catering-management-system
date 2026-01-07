import 'package:flutter/material.dart';
import '../api_service.dart';
import 'invoice_screen.dart';
import '../translations.dart'; // Import Translations
import '../main.dart'; // Import currentLanguage

class PricingScreen extends StatefulWidget {
  final int menuId;
  final int guestCount;
  final double baseFoodCost;

  const PricingScreen({
    super.key,
    required this.menuId,
    required this.guestCount,
    required this.baseFoodCost,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  // Controllers for extra costs
  final TextEditingController _laborController =
      TextEditingController(text: "5000");
  final TextEditingController _transportController =
      TextEditingController(text: "2000");

  // Slider Value (Profit Margin)
  double _profitMargin = 20.0; // Default 20%

  // Calculated Values
  double _totalCost = 0;
  double _finalQuote = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotal(); // Calculate immediately on load
  }

  void _calculateTotal() {
    // 1. Base Food Cost
    double foodCost = widget.baseFoodCost;

    // 2. Add Extras
    double labor = double.tryParse(_laborController.text) ?? 0;
    double transport = double.tryParse(_transportController.text) ?? 0;

    // 3. Total Cost (Before Profit)
    double cost = foodCost + labor + transport;

    // 4. Add Profit Margin
    double profitAmount = cost * (_profitMargin / 100);

    setState(() {
      _totalCost = cost;
      _finalQuote = cost + profitAmount;
    });
  }

  void _saveQuote() async {
    // Helper to get current language for SnackBar
    String t(String key) => AppTranslations.get(currentLanguage.value, key);

    try {
      await ApiService.savePricing(
        menuId: widget.menuId,
        baseCost: _totalCost,
        laborCost: double.tryParse(_laborController.text) ?? 0,
        transportCost: double.tryParse(_transportController.text) ?? 0,
        profitMargin: _profitMargin,
        finalAmount: _finalQuote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('quote_saved')), // Translated
            backgroundColor: Colors.green));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceScreen(
              menuId: widget.menuId,
              baseAmount: _finalQuote, // Pass the calculated quote to Invoice
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
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
              title: Text(t('cost_calculator')), // Translated
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1: BASE COST ---
                _buildSummaryCard(
                    t('base_food_cost'), // Translated
                    "₹${widget.baseFoodCost.toStringAsFixed(0)}",
                    Icons.restaurant),

                const SizedBox(height: 20),

                // --- SECTION 2: EXTRAS INPUT ---
                Text(t('additional_charges'), // Translated
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _buildInput(
                            t('labor_cost'), _laborController)), // Translated
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildInput(t('transport_cost'),
                            _transportController)), // Translated
                  ],
                ),

                const SizedBox(height: 20),

                // --- SECTION 3: PROFIT SLIDER ---
                Text(
                    "${t('profit_margin')}: ${_profitMargin.round()}%", // Translated
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Slider(
                  value: _profitMargin,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: "${_profitMargin.round()}%",
                  activeColor: Colors.deepPurple,
                  onChanged: (val) {
                    setState(() {
                      _profitMargin = val;
                    });
                    _calculateTotal();
                  },
                ),

                const Divider(thickness: 2, height: 40),

                // --- SECTION 4: FINAL QUOTE ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.deepPurple.shade200)),
                  child: Column(
                    children: [
                      _buildRow(t('total_cost'),
                          "₹${_totalCost.toStringAsFixed(0)}"), // Translated
                      _buildRow(
                          "${t('profit')} (${_profitMargin.round()}%)", // Translated
                          "+ ₹${(_finalQuote - _totalCost).toStringAsFixed(0)}",
                          isGreen: true),
                      const Divider(),
                      _buildRow(t('final_quote'),
                          "₹${_finalQuote.toStringAsFixed(0)}", // Translated
                          isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saveQuote,
                    icon: const Icon(Icons.save_alt),
                    label: Text(t('save_quote_invoice')), // Translated
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Helpers
  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (val) => _calculateTotal(), // Recalculate when typing
    );
  }

  Widget _buildRow(String label, String value,
      {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 18 : 16)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 18 : 16,
                  color: isGreen ? Colors.green : Colors.black)),
        ],
      ),
    );
  }
}
