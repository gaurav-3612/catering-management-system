import 'package:flutter/material.dart';
import '../api_service.dart';
import 'dart:convert';
import 'menu_detail_screen.dart';
import '../translations.dart'; // Imports AppTranslations class
import '../main.dart'; // Imports currentLanguage ValueNotifier

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;

  // --- HELPER FUNCTION ---
  String t(String key) {
    return AppTranslations.get(currentLanguage.value, key);
  }

  // --- LOGIC TO CALCULATE REAL COST FROM SAVED JSON ---
  double _calculateItemWiseTotal(Map<String, dynamic> menuData) {
    double total = 0;

    // Only look at specific food sections
    List<String> validSections = [
      "starters",
      "main_course",
      "breads",
      "rice",
      "desserts",
      "beverages"
    ];

    menuData.forEach((key, value) {
      if (validSections.contains(key) && value is List) {
        for (var item in value) {
          String s = item.toString();
          // Regex to find price: matches "₹ 40", "Rs.40", "INR 40"
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

  void _deleteMenu(int id) async {
    try {
      await ApiService.deleteMenu(id);
      // Refresh the list after deleting
      setState(() {
        _historyFuture = ApiService.fetchSavedMenus();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t('menu_deleted')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiService.fetchSavedMenus();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('history_title')),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          body: FutureBuilder<List<dynamic>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(t('no_menus')));
              }

              final menus = snapshot.data!;

              return ListView.builder(
                itemCount: menus.length,
                padding: const EdgeInsets.all(10),
                itemBuilder: (context, index) {
                  final menu = menus[index];

                  // 1. Decode the JSON immediately to calculate cost for display
                  String jsonString = menu['menu_json'];
                  Map<String, dynamic> decodedMenu = jsonDecode(jsonString);

                  // 2. Calculate Real Cost vs Budget
                  double aiCost = _calculateItemWiseTotal(decodedMenu);
                  double budget = (menu['budget'] as num).toDouble();
                  double displayCost = aiCost > 0 ? aiCost : budget;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade100,
                        child: const Icon(Icons.restaurant_menu,
                            color: Colors.deepPurple),
                      ),
                      title: Text("${menu['event_type']} (${menu['cuisine']})"),

                      // Updated Subtitle to show Real Cost
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${menu['guest_count']} ${t('guests')}"),
                          Text(
                            "Rate: ₹${displayCost.toStringAsFixed(0)} / plate",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: aiCost > 0
                                    ? Colors.green
                                    : Colors.grey[700]),
                          ),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMenu(menu['id']),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                        ],
                      ),

                      onTap: () {
                        // 3. Navigate to Detail Screen with CORRECT COST
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MenuDetailScreen(
                              fullMenu: decodedMenu,
                              eventType: menu['event_type'],
                              cuisine: menu['cuisine'],
                              menuId: menu['id'],
                              guestCount: menu['guest_count'],
                              // ✅ FIX: Pass the Calculated AI Cost instead of the raw budget
                              budgetPerPlate: displayCost.toInt(),
                            ),
                          ),
                        );
                      },
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
