import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  String? _base64Logo; // To store image string
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchCompanyProfile();
    if (data.isNotEmpty) {
      setState(() {
        _nameCtrl.text = data['company_name'] ?? "";
        _addrCtrl.text = data['address'] ?? "";
        _phoneCtrl.text = data['phone'] ?? "";
        _emailCtrl.text = data['email'] ?? "";
        _gstCtrl.text = data['gst_number'] ?? "";
        _base64Logo = data['logo_base64']; // Load existing logo
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _base64Logo = base64Encode(bytes); // Convert to String
      });
    }
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name and Phone are required!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.saveCompanyProfile(
        companyName: _nameCtrl.text,
        address: _addrCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        gst: _gstCtrl.text,
        logoBase64: _base64Logo, // Save Logo
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Profile Saved!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Company Settings"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _base64Logo != null
                          ? MemoryImage(base64Decode(_base64Logo!))
                          : null,
                      child: _base64Logo == null
                          ? const Icon(Icons.add_a_photo,
                              size: 40, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Tap to add Company Logo"),
                  const SizedBox(height: 20),
                  _input("Company Name", _nameCtrl, Icons.store),
                  _input("Address", _addrCtrl, Icons.location_on),
                  _input("Phone", _phoneCtrl, Icons.phone, isNum: true),
                  _input("Email (Optional)", _emailCtrl, Icons.email),
                  _input("GST / Tax ID (Optional)", _gstCtrl,
                      Icons.confirmation_number),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Save Settings",
                          style: TextStyle(fontSize: 18)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _input(String label, TextEditingController c, IconData icon,
      {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: c,
        keyboardType: isNum ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
