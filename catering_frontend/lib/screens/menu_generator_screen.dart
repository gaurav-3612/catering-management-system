import 'package:flutter/material.dart';
import '../api_service.dart';
import 'invoice_screen.dart';
import 'history_screen.dart';
import '../translations.dart';
import '../main.dart';

class MenuGeneratorScreen extends StatefulWidget {
  const MenuGeneratorScreen({super.key});

  @override
  State<MenuGeneratorScreen> createState() => _MenuGeneratorScreenState();
}

class _MenuGeneratorScreenState extends State<MenuGeneratorScreen> {
  // Controllers
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // Dropdown Initial Values
  String _selectedEvent = 'Wedding';
  String _selectedCuisine = 'North Indian';
  String _selectedDiet = 'Veg';

  // State variables
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
    super.dispose();
  }

  // --- API CALLS ---

  void _generateMenu() async {
    FocusScope.of(context).unfocus();
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

  void _saveMenu() async {
    if (_generatedMenu == null) return;
    try {
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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('menu_saved')), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  // --- EDITING LOGIC ---

  void _editItem(String section, int index, String oldName) {
    TextEditingController editCtrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Dish"),
        content: TextField(controller: editCtrl),
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
            decoration: const InputDecoration(hintText: "Dish Name - ₹Cost")),
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

  // --- CALCULATION LOGIC ---
  double _calculateItemWiseTotal() {
    double total = 0;
    if (_generatedMenu == null) return 0;

    // Only calculate for known food sections to avoid errors
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

          // Improved Regex to handle "₹ 50", "Rs.50", "50 INR"
          RegExp regExp = RegExp(r'(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)',
              caseSensitive: false);
          Match? match = regExp.firstMatch(s);

          if (match != null) {
            String costStr =
                match.group(1)!.replaceAll(',', ''); // Remove commas
            total += double.tryParse(costStr) ?? 0;
          }
        }
      }
    });
    return total;
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Real AI Cost (Sum of all items)
    double aiCostPerPlate = _calculateItemWiseTotal();

    // 2. Get User Inputs
    int guests = int.tryParse(_guestsController.text) ?? 0;
    double userBudgetPerPlate = double.tryParse(_budgetController.text) ?? 0;

    // 3. LOGIC: Use AI Cost if available (>0), else use User Budget
    double finalRatePerPlate =
        aiCostPerPlate > 0 ? aiCostPerPlate : userBudgetPerPlate;

    // 4. Calculate Final Total Quote (Guests * Actual Rate)
    double totalInvoiceAmount = finalRatePerPlate * guests;

    // 5. Check if Over Budget (Visual Warning)
    bool isOverBudget = aiCostPerPlate > userBudgetPerPlate;

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
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                ),
              ],
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
                    // COST SUMMARY CARD
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
                              Text(
                                  aiCostPerPlate > 0
                                      ? "Actual Cost (AI):"
                                      : "Estimated Cost:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOverBudget
                                          ? Colors.red
                                          : Colors.black)),
                              Text(
                                  "₹${finalRatePerPlate.toStringAsFixed(0)} / plate",
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
                              child: Text(
                                  "⚠️ Cost exceeds budget! Remove items to reduce cost.",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total Quote ($guests guests):",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text("₹${totalInvoiceAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                      fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('suggested_menu'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple)),
                        if (_savedMenuId == null)
                          IconButton(
                            icon: const Icon(Icons.save,
                                color: Colors.deepPurple),
                            onPressed: _saveMenu,
                            tooltip: t('save_history'),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.receipt_long,
                                color: Colors.green, size: 30),
                            tooltip: "Generate Invoice",
                            onPressed: () {
                              // ✅ Passes the ACTUAL Calculated Total
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoiceScreen(
                                    menuId: _savedMenuId!,
                                    baseAmount: totalInvoiceAmount,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
              ),
          ],
        ),
        initiallyExpanded: items.isNotEmpty,
        children: [
          ...items.asMap().entries.map((entry) {
            int idx = entry.key;
            String rawText = entry.value.toString();
            String name = rawText;
            String price = "";

            // Display Parse Logic
            RegExp regExp = RegExp(r'(.*)((?:₹|Rs\.?|INR)\s*[\d,]+(?:\.\d+)?)',
                caseSensitive: false);
            Match? match = regExp.firstMatch(rawText);

            if (match != null) {
              name = match.group(1)?.replaceAll('-', '').trim() ?? rawText;
              price = match.group(2) ?? "";
            }

            return ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 8, color: Colors.green),
              title: Text(name),
              subtitle: price.isNotEmpty
                  ? Text(price,
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
