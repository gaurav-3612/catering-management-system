import 'package:catering_frontend/screens/history_screen.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';

class MenuGeneratorScreen extends StatefulWidget {
  const MenuGeneratorScreen({super.key});

  @override
  State<MenuGeneratorScreen> createState() => _MenuGeneratorScreenState();
}

class _MenuGeneratorScreenState extends State<MenuGeneratorScreen> {
  // Controllers
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // Dropdown Initial Values (Restored all options)
  String _selectedEvent = 'Wedding';
  String _selectedCuisine = 'North Indian';
  String _selectedDiet = 'Veg';

  // State variables
  bool _isLoading = false;
  Map<String, dynamic>? _generatedMenu;
  String? _errorMessage;

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
    });

    try {
      final menu = await ApiService.generateMenu(
        eventType: _selectedEvent,
        cuisine: _selectedCuisine,
        guestCount: int.tryParse(_guestsController.text) ?? 100,
        budget: int.tryParse(_budgetController.text) ?? 500,
        dietaryPreference: _selectedDiet,
      );

      // --- ROBUST PARSING FIX ---
      // We create a new Map to hold our editable data
      Map<String, dynamic> safeMenu = {};

      menu.forEach((key, value) {
        // Only add this section if the value is actually a List
        if (value is List) {
          safeMenu[key] = List<dynamic>.from(value);
        } else {
          // If the AI returns weird data (like a Map or String), ignore it or use empty list
          safeMenu[key] = [];
          print("Warning: Section $key was not a List. Received: $value");
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
      print("Menu Generation Error: $e"); // Print to console for debugging
    }
  }

  void _saveMenu() async {
    if (_generatedMenu == null) return;
    try {
      await ApiService.saveMenuToDatabase(
        eventType: _selectedEvent,
        cuisine: _selectedCuisine,
        guestCount: int.tryParse(_guestsController.text) ?? 100,
        budget: int.tryParse(_budgetController.text) ?? 500,
        fullMenu: _generatedMenu!,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Menu Saved!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
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
            decoration: const InputDecoration(labelText: "Dish Name")),
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
        title: Text("Add to $section"),
        content: TextField(
            controller: addCtrl,
            decoration: const InputDecoration(labelText: "New Dish Name")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (addCtrl.text.isNotEmpty) {
                setState(() {
                  if (_generatedMenu![section] == null) {
                    _generatedMenu![section] = [];
                  }
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

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("AI Menu Planner"),
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
                      // RESTORED FULL EVENT LIST
                      _buildDropdown(
                          "Event Type",
                          [
                            "Wedding",
                            "Birthday",
                            "Corporate",
                            "Anniversary",
                            "Engagement"
                          ],
                          _selectedEvent,
                          (v) => setState(() => _selectedEvent = v!)),
                      const SizedBox(height: 10),

                      // RESTORED FULL CUISINE LIST
                      _buildDropdown(
                          "Cuisine",
                          [
                            "North Indian",
                            "South Indian",
                            "Chinese",
                            "Continental",
                            "Italian"
                          ],
                          _selectedCuisine,
                          (v) => setState(() => _selectedCuisine = v!)),
                      const SizedBox(height: 10),

                      // RESTORED DIETARY PREFERENCE
                      _buildDropdown(
                          "Dietary Preference",
                          ["Veg", "Non-Veg", "Vegan", "Jain"],
                          _selectedDiet,
                          (v) => setState(() => _selectedDiet = v!)),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  "Guests", _guestsController, Icons.people,
                                  isNumber: true)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildTextField("Budget/Plate",
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
                          label: Text(
                              _isLoading ? "Generating..." : "Generate Menu"),
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

              // --- ERROR DISPLAY ---
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.shade100,
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ),

              // --- MENU RESULTS SECTION ---
              if (_generatedMenu != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Suggested Menu",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    IconButton(
                      icon: const Icon(Icons.save, color: Colors.deepPurple),
                      onPressed: _saveMenu,
                      tooltip: "Save to History",
                    )
                  ],
                ),
                const SizedBox(height: 10),

                // Editable Sections (Matches backend JSON keys exactly)
                _buildEditableSection("starters", "Starters"),
                _buildEditableSection("main_course", "Main Course"),
                _buildEditableSection("breads", "Breads"),
                _buildEditableSection("rice", "Rice"),
                _buildEditableSection("desserts", "Desserts"),
                _buildEditableSection("beverages", "Beverages"),
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildEditableSection(String jsonKey, String title) {
    // Safety check: Ensure the list exists, default to empty list if not
    List<dynamic> items = _generatedMenu![jsonKey] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        initiallyExpanded:
            items.isNotEmpty, // Open automatically if there are items
        children: [
          ...items.asMap().entries.map((entry) {
            int idx = entry.key;
            String name = entry.value.toString();
            return ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 8, color: Colors.green),
              title: Text(name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: () => _editItem(jsonKey, idx, name)),
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
            label: const Text("Add Item"),
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
