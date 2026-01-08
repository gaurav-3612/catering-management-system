import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../translations.dart';
import '../main.dart';
import 'invoice_screen.dart';

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
  // Overhead Controllers
  final TextEditingController _laborCtrl = TextEditingController(text: "5000");
  final TextEditingController _transportCtrl =
      TextEditingController(text: "2000");
  final TextEditingController _miscCtrl = TextEditingController(text: "0");

  // [NEW] Persistent Controllers Map for Dynamic Menu Items
  // This prevents the cursor from jumping when typing!
  final Map<String, TextEditingController> _itemControllers = {};

  double _profitMargin = 20.0;
  double _calculatedBaseFoodCost = 0.0;
  double _totalCost = 0.0;
  double _finalQuote = 0.0;

  Map<String, double> _itemCosts = {};
  bool _isLoading = true;

  final Set<String> _validCategories = {
    "starters",
    "main course",
    "main_course",
    "breads",
    "rice",
    "desserts",
    "beverages",
    "salads",
    "soups"
  };

  String t(String key) => AppTranslations.get(currentLanguage.value, key);

  @override
  void initState() {
    super.initState();
    _loadSmartMenuData();
  }

  @override
  void dispose() {
    // Clean up all controllers
    _laborCtrl.dispose();
    _transportCtrl.dispose();
    _miscCtrl.dispose();
    for (var ctrl in _itemControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSmartMenuData() async {
    try {
      final menus = await ApiService.fetchSavedMenus();
      final myMenu =
          menus.firstWhere((m) => m['id'] == widget.menuId, orElse: () => null);

      if (myMenu != null) {
        Map<String, dynamic> menuJson = jsonDecode(myMenu['menu_json']);

        setState(() {
          _isLoading = false;
          _itemCosts.clear();
          // Clear old controllers if reloading
          _itemControllers.clear();

          menuJson.forEach((key, items) {
            if (_isValidCategory(key)) {
              double categoryTotal = 0.0;

              if (items is List) {
                for (var itemStr in items) {
                  RegExp regex = RegExp(r'(?:Rs\.?|₹)\s*(\d+(?:\.\d+)?)',
                      caseSensitive: false);
                  Match? match = regex.firstMatch(itemStr.toString());

                  if (match != null) {
                    double val = double.tryParse(match.group(1)!) ?? 0;
                    if (val > 0) {
                      categoryTotal +=
                          (val < 500) ? val * widget.guestCount : val;
                    }
                  }
                }
              }

              if (categoryTotal == 0) {
                categoryTotal = _getFallbackEstimate(key, widget.guestCount);
              }

              _itemCosts[key] = categoryTotal;

              // [NEW] Initialize Controller Once
              _itemControllers[key] =
                  TextEditingController(text: categoryTotal.toStringAsFixed(0));
            }
          });

          _recalculate();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidCategory(String key) {
    String lowerKey = key.toLowerCase().trim();
    return _validCategories.any((valid) => lowerKey.contains(valid));
  }

  double _getFallbackEstimate(String category, int guests) {
    String lower = category.toLowerCase();
    if (lower.contains('starter')) return guests * 60.0;
    if (lower.contains('main')) return guests * 180.0;
    if (lower.contains('dessert')) return guests * 50.0;
    if (lower.contains('bread')) return guests * 20.0;
    if (lower.contains('rice')) return guests * 30.0;
    if (lower.contains('beverage')) return guests * 30.0;
    return guests * 40.0;
  }

  void _recalculate() {
    double foodSum = 0;

    // Sum up based on CURRENT state values
    _itemCosts.forEach((key, value) {
      foodSum += value;
    });

    double labor = double.tryParse(_laborCtrl.text) ?? 0;
    double transport = double.tryParse(_transportCtrl.text) ?? 0;
    double misc = double.tryParse(_miscCtrl.text) ?? 0;

    double subtotal = foodSum + labor + transport + misc;
    double profitAmount = subtotal * (_profitMargin / 100);

    setState(() {
      _calculatedBaseFoodCost = foodSum;
      _totalCost = subtotal;
      _finalQuote = subtotal + profitAmount;
    });
  }

  void _saveAndProceed() async {
    await ApiService.savePricing(
      menuId: widget.menuId,
      baseCost: _calculatedBaseFoodCost,
      laborCost: double.tryParse(_laborCtrl.text) ?? 0,
      transportCost: double.tryParse(_transportCtrl.text) ?? 0,
      profitMargin: _profitMargin,
      finalAmount: _finalQuote,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceScreen(
            menuId: widget.menuId,
            baseAmount: _finalQuote,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('cost_calculator')),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER INFO ---
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoStat("Guests", "${widget.guestCount}"),
                            _buildInfoStat("Cost/Plate",
                                "₹${(_finalQuote / (widget.guestCount > 0 ? widget.guestCount : 1)).toStringAsFixed(0)}"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SECTION 1: FOOD COSTS ---
                      Text("1. ${t('base_food_cost')}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      const Text("Prices auto-estimated. Tap to edit.",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 10),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: _itemCosts.entries.map((entry) {
                            return ListTile(
                              title: Text(
                                  entry.key.toUpperCase().replaceAll("_", " "),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              trailing: SizedBox(
                                width: 130,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  decoration: const InputDecoration(
                                    prefixText: "₹ ",
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  // [FIX] Use the Persistent Controller from the Map
                                  controller: _itemControllers[entry.key],

                                  onChanged: (val) {
                                    // Update state variable but DO NOT rebuild controller
                                    _itemCosts[entry.key] =
                                        double.tryParse(val) ?? 0;
                                    _recalculate();
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- SECTION 2: OVERHEADS ---
                      Text("2. ${t('additional_charges')}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _buildInput(t('labor_cost'), _laborCtrl)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildInput(
                                  t('transport_cost'), _transportCtrl)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildInput("Misc/Fuel", _miscCtrl),

                      const SizedBox(height: 20),

                      // --- SECTION 3: PROFIT ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${t('profit_margin')}",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("${_profitMargin.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                      Slider(
                        value: _profitMargin,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: Colors.green,
                        label: "${_profitMargin.round()}%",
                        onChanged: (val) {
                          setState(() {
                            _profitMargin = val;
                            _recalculate();
                          });
                        },
                      ),

                      const Divider(thickness: 2),

                      // --- SECTION 4: TOTAL ---
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            _summaryRow(
                                t('base_food_cost'), _calculatedBaseFoodCost),
                            _summaryRow(t('total_cost'), _totalCost,
                                isBold: true),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t('final_quote'),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple)),
                                Text("₹${_finalQuote.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _finalQuote > 0 ? _saveAndProceed : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(t('save_quote_invoice')),
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

  Widget _buildInfoStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: "₹",
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _recalculate(),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("₹${value.toStringAsFixed(0)}",
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
