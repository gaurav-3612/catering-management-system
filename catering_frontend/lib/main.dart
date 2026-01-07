import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'notification_service.dart';
import 'screens/login_screen.dart';

// GLOBAL NOTIFIER for Language Change
ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (e) {
    print("Notification Init Error: $e");
  }
  runApp(const CateringApp());
}

class CateringApp extends StatelessWidget {
  const CateringApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to language changes
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, langCode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Catering Manager',
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
            scaffoldBackgroundColor: Colors.grey[100],
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: true,
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}
