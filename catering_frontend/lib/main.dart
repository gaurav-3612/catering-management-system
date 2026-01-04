import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart'; // Import the new file

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DashboardScreen(), // Change this from MenuGeneratorScreen
  ));
}
