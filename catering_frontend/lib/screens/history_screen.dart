import 'package:flutter/material.dart';
import '../api_service.dart';
import 'dart:convert'; // NEEDED FOR jsonDecode
import 'menu_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;

  void _deleteMenu(int id) async {
    try {
      await ApiService.deleteMenu(id);
      // Refresh the list after deleting
      setState(() {
        _historyFuture = ApiService.fetchSavedMenus();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Menu deleted"), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Load the data as soon as the screen opens
    _historyFuture = ApiService.fetchSavedMenus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Menus"),
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
            return const Center(child: Text("No saved menus found."));
          }

          final menus = snapshot.data!;

          return ListView.builder(
            itemCount: menus.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final menu = menus[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: const Icon(Icons.restaurant_menu,
                        color: Colors.deepPurple),
                  ),
                  title: Text("${menu['event_type']} (${menu['cuisine']})"),
                  subtitle: Text("${menu['guest_count']} Guests"),

                  // UPDATED TRAILING SECTION
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMenu(menu['id']),
                      ),
                      // Arrow Icon
                      const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                    ],
                  ),

                  onTap: () {
                    // 1. Get the stored JSON string
                    String jsonString = menu['menu_json'];

                    // 2. Convert it back to a Map (List of food)
                    Map<String, dynamic> decodedMenu = jsonDecode(jsonString);

                    // 3. Navigate to the Detail Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuDetailScreen(
                          fullMenu: decodedMenu,
                          eventType: menu['event_type'],
                          cuisine: menu['cuisine'],
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
  }
}
