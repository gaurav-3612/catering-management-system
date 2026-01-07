import 'package:flutter/material.dart';
import '../api_service.dart';
import '../translations.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLogin = true; // Toggle between Login and Signup
  bool _isLoading = false;

  void _authenticate() async {
    setState(() => _isLoading = true);
    String username = _userController.text.trim();
    String password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Helper to get text
    String t(String key) => AppTranslations.get(currentLanguage.value, key);

    if (_isLogin) {
      // --- LOGIN LOGIC ---
      // Returns NULL if successful, or Error String if failed
      String? error = await ApiService.login(username, password);

      if (error == null) {
        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(t('login_success')),
                backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        // Failure
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // --- REGISTER LOGIC ---
      // Returns NULL if successful, or Error String if failed
      String? error = await ApiService.register(username, password);

      if (error == null) {
        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(t('register_success')),
                backgroundColor: Colors.green),
          );
          setState(() => _isLogin = true); // Switch to login after signup
        }
      } else {
        // Failure
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentLanguage,
      builder: (context, lang, child) {
        String t(String key) => AppTranslations.get(lang, key);

        return Scaffold(
          backgroundColor: Colors.deepPurple,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LOGO / ICON
                      const Icon(Icons.restaurant_menu,
                          size: 60, color: Colors.deepPurple),
                      const SizedBox(height: 10),
                      Text(
                        t('app_title'),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 30),

                      // TITLE
                      Text(
                        _isLogin ? t('login_title') : t('signup_title'),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      // INPUTS
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: t('username'),
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: t('password'),
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  _isLogin ? t('login_btn') : t('signup_btn'),
                                  style: const TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // TOGGLE LOGIN/SIGNUP
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                            _isLogin ? t('no_account') : t('have_account')),
                      ),

                      // LANGUAGE SWITCHER
                      DropdownButton<String>(
                        value: lang,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text("English")),
                          DropdownMenuItem(value: 'hi', child: Text("हिंदी")),
                          DropdownMenuItem(value: 'te', child: Text("తెలుగు")),
                          DropdownMenuItem(value: 'ta', child: Text("தமிழ்")),
                        ],
                        onChanged: (String? val) {
                          if (val != null) currentLanguage.value = val;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
