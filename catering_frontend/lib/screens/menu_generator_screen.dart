import 'package:flutter/material.dart';
import '../api_service.dart';
import 'pricing_screen.dart';
import '../translations.dart';
import '../main.dart';

class MenuGeneratorScreen extends StatefulWidget {
  const MenuGeneratorScreen({super.key});

  @override
  State<MenuGeneratorScreen> createState() => _MenuGeneratorScreenState();
}

class _MenuGeneratorScreenState extends State<MenuGeneratorScreen> {
  // Input Controllers
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _specialReqController = TextEditingController();

  // Dropdown Values
  String _selectedEvent = 'Wedding';
  String _selectedCuisine = 'North Indian';
  String _selectedDiet = 'Veg';

  // State Variables
  bool _isLoading = false;
  Map<String, dynamic>? _generatedMenu;
  int? _savedMenuId;
  String? _errorMessage;

  // Translation Helper
  String t(String key) => AppTranslations.get(currentLanguage.value, key);

  @override
  void dispose() {
    _guestsController.dispose();
    _budgetController.dispose();
    _specialReqController.dispose();
    super.dispose();
  }

  // --- 1. GENERATE MENU (Calls AI) ---
  void _generateMenu() async {
    FocusScope.of(context).unfocus();

    if (_guestsController.text.isEmpty || _budgetController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('enter_all_details'))));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedMenu = null;
      _savedMenuId = null;
    });

    try {
      final menu = await ApiService.generateMenu(
        eventType: _selectedEvent,
        cuisine: _selectedCuisine,
        guestCount: int.tryParse(_guestsController.text) ?? 100,
        budget: int.tryParse(_budgetController.text) ?? 500,
        dietaryPreference: _selectedDiet,
        // [FIX] Now passing the text from the controller!
        specialRequirements: _specialReqController.text,
      );

      // Robust Parsing: Ensure all values are Lists
      Map<String, dynamic> safeMenu = {};
      menu.forEach((key, value) {
        if (value is List) {
          safeMenu[key] = List<dynamic>.from(value);
        } else {
          safeMenu[key] = [];
        }
      });

      setState(() {
        _generatedMenu = safeMenu;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  // --- 2. REGENERATE SECTION ---
  void _regenerateSectionItems(String sectionKey) async {
    setState(() => _isLoading = true);
    try {
      List<String> currentItems = (_generatedMenu![sectionKey] as List)
          .map((e) => e.toString())
          .toList();

      List<String> newItems = await ApiService.regenerateSection(
        section: sectionKey,
        eventType: _selectedEvent,
        cuisine: _selectedCuisine,
        dietary: _selectedDiet,
        currentItems: currentItems,
      );

      setState(() {
        _generatedMenu![sectionKey] = newItems;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$sectionKey Refreshed!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 3. SAVE & NAVIGATE TO PRICING ---
  void _saveAndProceed() async {
    if (_generatedMenu == null) return;
    try {
      // 1. Save to Database
      final response = await ApiService.saveMenuToDatabase(
        eventType: _selectedEvent,
        cuisine: _selectedCuisine,
        guestCount: int.tryParse(_guestsController.text) ?? 100,
        budget: int.tryParse(_budgetController.text) ?? 500,
        fullMenu: _generatedMenu!,
      );

      setState(() {
        _savedMenuId = response['id'];
      });

      // 2. Calculate initial Base Cost estimate to pass to Pricing
      double estimatedBaseCost = _calculateItemWiseTotal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('menu_saved')), backgroundColor: Colors.green));

        // 3. Navigate to Pricing Screen (Screen 2)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PricingScreen(
              menuId: _savedMenuId!,
              guestCount: int.tryParse(_guestsController.text) ?? 100,
              baseFoodCost: estimatedBaseCost, // Passes the AI's estimate
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    }
  }

  // --- EDITING LOGIC ---
  void _editItem(String section, int index, String oldName) {
    TextEditingController editCtrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Dish"),
        content: TextField(
            controller: editCtrl,
            // [FIX] Updated hint to show you can use dashes
            decoration:
                const InputDecoration(helperText: "Format: Name - Cost")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _generatedMenu![section][index] = editCtrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _deleteItem(String section, int index) {
    setState(() {
      _generatedMenu![section].removeAt(index);
    });
  }

  void _addItem(String section) {
    TextEditingController addCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${t('add_item')} $section"),
        content: TextField(
            controller: addCtrl,
            decoration: const InputDecoration(hintText: "Dish Name - Cost")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (addCtrl.text.isNotEmpty) {
                setState(() {
                  _generatedMenu![section] ??= [];
                  _generatedMenu![section].add(addCtrl.text);
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  // --- [FIXED] SMART CALCULATION LOGIC ---
  double _calculateItemWiseTotal() {
    double total = 0;
    if (_generatedMenu == null) return 0;

    List<String> validSections = [
      "starters",
      "main_course",
      "breads",
      "rice",
      "desserts",
      "beverages"
    ];

    _generatedMenu!.forEach((key, value) {
      if (validSections.contains(key) && value is List) {
        for (var item in value) {
          String s = item.toString();

          // [FIX] Improved Regex to catch prices separated by '-', ':', '₹', or 'Rs.'
          // Captures: "Item - 200", "Item: 200", "Item ₹200"
          RegExp regExp = RegExp(r'(?:₹|Rs\.?|INR|[-–:])\s*([\d,]+(?:\.\d+)?)',
              caseSensitive: false);
          Match? match = regExp.firstMatch(s);

          if (match != null) {
            String costStr = match.group(1)!.replaceAll(',', '');
            double val = double.tryParse(costStr) ?? 0;
            total += val;
          }
        }
      }
    });
    return total;
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    int guests = int.tryParse(_guestsController.text) ?? 100;

    // This updates LIVE whenever you edit items because setState re-runs build()
    double aiCostPerPlate = _calculateItemWiseTotal();

    double userBudgetPerPlate = double.tryParse(_budgetController.text) ?? 0;
    double finalRatePerPlate =
        aiCostPerPlate > 0 ? aiCostPerPlate : userBudgetPerPlate;
    double totalInvoiceAmount = finalRatePerPlate * guests;
    bool isOverBudget =
        aiCostPerPlate > userBudgetPerPlate && aiCostPerPlate > 0;

    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(t('menu_generator_title')),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- FORM SECTION ---
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildDropdown(
                              t('event_type'),
                              [
                                "Wedding",
                                "Birthday",
                                "Corporate",
                                "Anniversary"
                              ],
                              _selectedEvent,
                              (v) => setState(() => _selectedEvent = v!)),
                          const SizedBox(height: 10),
                          _buildDropdown(
                              t('cuisine'),
                              [
                                "North Indian",
                                "South Indian",
                                "Chinese",
                                "Continental"
                              ],
                              _selectedCuisine,
                              (v) => setState(() => _selectedCuisine = v!)),
                          const SizedBox(height: 10),
                          _buildDropdown(
                              t('dietary'),
                              ["Veg", "Non-Veg", "Vegan", "Jain"],
                              _selectedDiet,
                              (v) => setState(() => _selectedDiet = v!)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(t('guests'),
                                      _guestsController, Icons.people,
                                      isNumber: true)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _buildTextField(t('budget'),
                                      _budgetController, Icons.currency_rupee,
                                      isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField("Special Req. (Optional)",
                              _specialReqController, Icons.notes),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _generateMenu,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.auto_awesome),
                              label: Text(_isLoading
                                  ? t('generating')
                                  : t('generate_btn')),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.red.shade100,
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),

                  // --- RESULTS SECTION ---
                  if (_generatedMenu != null) ...[
                    // Budget Status Card
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: isOverBudget ? Colors.red : Colors.green),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5)
                          ]),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Your Budget:",
                                  style: TextStyle(color: Colors.grey)),
                              Text("₹${userBudgetPerPlate.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Actual Cost:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOverBudget
                                          ? Colors.red
                                          : Colors.black)),
                              Text(
                                  "₹${aiCostPerPlate.toStringAsFixed(0)} / plate",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isOverBudget
                                          ? Colors.red
                                          : Colors.green)),
                            ],
                          ),
                          if (isOverBudget)
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Text("⚠️ Cost exceeds budget!",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Quote:",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("₹${totalInvoiceAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.deepPurple)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Navigation Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveAndProceed,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(t('save_next')),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Menu Categories
                    _buildEditableSection("starters", t('starters')),
                    _buildEditableSection("main_course", t('main_course')),
                    _buildEditableSection("breads", t('breads')),
                    _buildEditableSection("rice", t('rice')),
                    _buildEditableSection("desserts", t('desserts')),
                    _buildEditableSection("beverages", t('beverages')),
                  ],
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditableSection(String jsonKey, String title) {
    List<dynamic> items = _generatedMenu![jsonKey] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            if (_generatedMenu != null)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                onPressed: () => _regenerateSectionItems(jsonKey),
                tooltip: "Regenerate",
              ),
          ],
        ),
        initiallyExpanded: items.isNotEmpty,
        children: [
          ...items.asMap().entries.map((entry) {
            int idx = entry.key;
            String rawText = entry.value.toString();

            String displayName = rawText;
            String displayPrice = "";

            // [FIX] Updated display logic to match calculation logic
            RegExp regExp = RegExp(
                r'(.*)((?:₹|Rs\.?|INR|[-–:])\s*[\d,]+(?:\.\d+)?)',
                caseSensitive: false);
            Match? match = regExp.firstMatch(rawText);

            if (match != null) {
              displayName =
                  match.group(1)?.replaceAll('-', '').trim() ?? rawText;
              displayPrice = match.group(2) ?? "";
            }

            return ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 8, color: Colors.green),
              title: Text(displayName),
              subtitle: displayPrice.isNotEmpty
                  ? Text(displayPrice,
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold))
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: () => _editItem(jsonKey, idx, rawText)),
                  IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteItem(jsonKey, idx)),
                ],
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: () => _addItem(jsonKey),
            icon: const Icon(Icons.add),
            label: Text(t('add_item')),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String val,
      ValueChanged<String?> change) {
    return DropdownButtonFormField(
        value: val,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: change,
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50));
  }

  Widget _buildTextField(String label, TextEditingController c, IconData icon,
      {bool isNumber = false}) {
    return TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50));
  }
}
