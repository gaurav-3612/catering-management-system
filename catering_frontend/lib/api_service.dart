import 'dart:convert';
import 'package:http/http.dart' as http;
import 'db_helper.dart';

class ApiService {
  // (10.0.2.2 for Android Emulator, Local IP for Real Device)
  static const String baseUrl = "http://10.221.71.64:8000";

  static int? currentUserId;

  // --- 1. AUTHENTICATION ---
  static Future<String?> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUserId = data['user_id'];
        return null;
      } else {
        return "Invalid Credentials";
      }
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // Clear session logic
  static void logout() {
    currentUserId = null;
    DatabaseHelper.instance.clearAll();
  }

  static Future<String?> register(String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );
      if (response.statusCode == 200) return null;
      final body = jsonDecode(response.body);
      return body['detail'] ?? "Registration Failed";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // --- 2. FETCH MENUS (WITH OFFLINE CACHING) ---
  static Future<List<dynamic>> fetchSavedMenus() async {
    if (currentUserId == null) return [];

    try {
      // A. Try Network
      final url = Uri.parse('$baseUrl/get-menus?user_id=$currentUserId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        // B. Save to Local DB
        await DatabaseHelper.instance.cacheMenus(currentUserId!, data);
        print(" Menus fetched from Server & Cached");
        return data;
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      // C. Fallback to Local DB
      print(" Network failed ($e). Loading cached menus...");
      return await DatabaseHelper.instance.getCachedMenus(currentUserId!);
    }
  }

  // --- 3. FETCH INVOICES (WITH OFFLINE CACHING) ---
  static Future<List<dynamic>> fetchInvoices() async {
    if (currentUserId == null) return [];

    try {
      final url = Uri.parse('$baseUrl/get-invoices?user_id=$currentUserId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        // Save to Local DB
        await DatabaseHelper.instance.cacheInvoices(currentUserId!, data);
        print(" Invoices fetched from Server & Cached");
        return data;
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      print(" Network failed ($e). Loading cached invoices...");
      return await DatabaseHelper.instance.getCachedInvoices(currentUserId!);
    }
  }

  // --- 4. GENERATE MENU ---
  static Future<Map<String, dynamic>> generateMenu({
    required String eventType,
    required String cuisine,
    required int guestCount,
    required int budget,
    required String dietaryPreference,
  }) async {
    final url = Uri.parse('$baseUrl/generate-menu');
    final Map<String, dynamic> requestBody = {
      "event_type": eventType,
      "cuisine": cuisine,
      "guest_count": guestCount,
      "budget_per_plate": budget,
      "dietary_preference": dietaryPreference,
      "special_requirements": "None"
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        String menuString = decodedResponse['menu_data'];
        menuString =
            menuString.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(menuString);
      } else {
        throw Exception("Failed to load menu");
      }
    } catch (e) {
      throw Exception("Internet required for AI generation.");
    }
  }

  // --- 5. REGENERATE SECTION ---
  static Future<List<String>> regenerateSection({
    required String section,
    required String eventType,
    required String cuisine,
    required String dietary,
    required List<String> currentItems,
  }) async {
    final url = Uri.parse('$baseUrl/regenerate-section');
    final body = {
      "section": section,
      "event_type": eventType,
      "cuisine": cuisine,
      "dietary": dietary,
      "current_items": currentItems
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['new_items']);
      } else {
        throw Exception("Failed to regenerate");
      }
    } catch (e) {
      throw Exception("Connection Error");
    }
  }

  // --- 6. SAVE MENU ---
  static Future<Map<String, dynamic>> saveMenuToDatabase({
    required String eventType,
    required String cuisine,
    required int guestCount,
    required int budget,
    required Map<String, dynamic> fullMenu,
  }) async {
    if (currentUserId == null) throw Exception("User not logged in");

    final url = Uri.parse('$baseUrl/save-menu');
    final String menuJsonString = jsonEncode(fullMenu);

    final Map<String, dynamic> body = {
      "user_id": currentUserId,
      "event_type": eventType,
      "cuisine": cuisine,
      "guest_count": guestCount,
      "budget": budget,
      "menu_json": menuJsonString
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to save");
    }
  }

  // --- 7. DELETE MENU ---
  static Future<void> deleteMenu(int id) async {
    final url = Uri.parse('$baseUrl/delete-menu/$id');
    await http.delete(url);
  }

  // --- 8. DASHBOARD STATS ---
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    if (currentUserId == null) return {};
    final url = Uri.parse('$baseUrl/dashboard-stats?user_id=$currentUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- 9. SAVE PRICING ---
  static Future<void> savePricing({
    required int menuId,
    required double baseCost,
    required double laborCost,
    required double transportCost,
    required double profitMargin,
    required double finalAmount,
  }) async {
    if (currentUserId == null) throw Exception("User not logged in");
    final url = Uri.parse('$baseUrl/save-pricing');
    final Map<String, dynamic> body = {
      "user_id": currentUserId,
      "menu_id": menuId,
      "base_cost": baseCost,
      "labor_cost": laborCost,
      "transport_cost": transportCost,
      "profit_margin_percent": profitMargin,
      "final_quote_amount": finalAmount
    };
    await http.post(url,
        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
  }

  // --- 10. SAVE INVOICE ---
  static Future<void> saveInvoice({
    required int menuId,
    required String clientName,
    required double finalAmount,
    required double taxPercent,
    required double discount,
    required double grandTotal,
    required String eventDate,
  }) async {
    if (currentUserId == null) throw Exception("User not logged in");
    final url = Uri.parse('$baseUrl/save-invoice');
    final Map<String, dynamic> body = {
      "user_id": currentUserId,
      "menu_id": menuId,
      "client_name": clientName,
      "final_amount": finalAmount,
      "tax_percent": taxPercent,
      "discount_amount": discount,
      "grand_total": grandTotal,
      "is_paid": false,
      "event_date": eventDate,
      "order_status": "Pending"
    };
    await http.post(url,
        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
  }

  // --- 13. COMPANY PROFILE (UPDATED) ---
  static Future<void> saveCompanyProfile({
    required String companyName,
    required String address,
    required String phone,
    String? email,
    String? gst,
    String? logoBase64,
  }) async {
    if (currentUserId == null) throw Exception("User not logged in");

    final url = Uri.parse('$baseUrl/save-profile');
    final body = {
      "user_id": currentUserId,
      "company_name": companyName,
      "address": address,
      "phone": phone,
      "email": email ?? "",
      "gst_number": gst ?? "",
      "logo_base64": logoBase64 ?? ""
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to save profile");
    }
  }

  static Future<Map<String, dynamic>> fetchCompanyProfile() async {
    if (currentUserId == null) return {};
    final url = Uri.parse('$baseUrl/get-profile?user_id=$currentUserId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- 12. PAYMENTS & STATUS ---
  static Future<void> addPayment(
      int invoiceId, double amount, String mode) async {
    final url = Uri.parse('$baseUrl/add-payment');
    final body = {
      "invoice_id": invoiceId,
      "amount": amount,
      "payment_date": DateTime.now().toString().split(' ')[0],
      "payment_mode": mode
    };
    await http.post(url,
        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
  }

  static Future<List<dynamic>> fetchPaymentsForInvoice(int invoiceId) async {
    final url = Uri.parse('$baseUrl/get-payments/$invoiceId');
    final response = await http.get(url);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load payments");
  }

  static Future<void> updateOrderStatus(int id, String status) async {
    final url =
        Uri.parse('$baseUrl/update-order-status?invoice_id=$id&status=$status');
    await http.post(url);
  }
}
