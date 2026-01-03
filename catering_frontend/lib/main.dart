import 'package:flutter/material.dart';
import 'api_service.dart'; // Import your new service

void main() {
  runApp(const MaterialApp(home: TestMenuScreen()));
}

class TestMenuScreen extends StatefulWidget {
  const TestMenuScreen({super.key});

  @override
  State<TestMenuScreen> createState() => _TestMenuScreenState();
}

class _TestMenuScreenState extends State<TestMenuScreen> {
  String result = "Press the button to generate a menu";

  void testApi() async {
    setState(() {
      result = "Loading... (Asking AI)";
    });

    try {
      // Calling your new API Service
      final menu = await ApiService.generateMenu(
        eventType: "Wedding",
        cuisine: "South Indian",
        guestCount: 500,
        budget: 400,
        dietaryPreference: "Veg",
      );

      setState(() {
        // Just printing the raw data to screen for now
        result =
            "Success! \n\nStarters: ${menu['starters']}\n\nMains: ${menu['main_course']}";
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Backend Test")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: testApi,
              child: const Text("TEST CONNECTION"),
            ),
            const SizedBox(height: 20),
            Text(result),
          ],
        ),
      ),
    );
  }
}
