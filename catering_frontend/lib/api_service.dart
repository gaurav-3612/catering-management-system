import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ CHANGE THIS IP IF NEEDED (Use 10.0.2.2 for Android Emulator)
  static const String baseUrl = "http://10.221.71.64:8000";

  // --- STORE CURRENT USER ID ---
  static int? currentUserId;

  // --- 1. AUTHENTICATION (UPDATED) ---

  // Returns NULL if success, or Error Message if failed
  static Future<String?> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // ✅ SAVE THE USER ID
        currentUserId = data['user_id'];
        return null; // Success
      } else {
        return "Invalid Credentials";
      }
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  static Future<String?> register(String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? "Registration Failed";
      }
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // --- 2. GENERATE MENU (No Change needed here) ---
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
        throw Exception("Failed to load menu: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error connecting to backend: $e");
    }
  }

  // --- 3. SAVE MENU (UPDATED with user_id) ---
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
      "user_id": currentUserId, // <--- SEND USER ID
      "event_type": eventType,
      "cuisine": cuisine,
      "guest_count": guestCount,
      "budget": budget,
      "menu_json": menuJsonString
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to save: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error saving menu: $e");
    }
  }

  // --- 4. FETCH SAVED MENUS (UPDATED with user_id) ---
  static Future<List<dynamic>> fetchSavedMenus() async {
    if (currentUserId == null) return [];

    final url =
        Uri.parse('$baseUrl/get-menus?user_id=$currentUserId'); // <--- FILTER
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load history");
      }
    } catch (e) {
      throw Exception("Error fetching history: $e");
    }
  }

  // --- 5. DELETE MENU ---
  static Future<void> deleteMenu(int id) async {
    final url = Uri.parse('$baseUrl/delete-menu/$id');
    try {
      final response = await http.delete(url);
      if (response.statusCode != 200) {
        throw Exception("Failed to delete menu");
      }
    } catch (e) {
      throw Exception("Error deleting menu: $e");
    }
  }

  // --- 6. DASHBOARD STATS (UPDATED with user_id) ---
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    if (currentUserId == null) return {};

    final url = Uri.parse(
        '$baseUrl/dashboard-stats?user_id=$currentUserId'); // <--- FILTER
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "total_events": 0,
          "total_guests": 0,
          "projected_revenue": "0",
          "top_cuisine": "N/A"
        };
      }
    } catch (e) {
      return {
        "total_events": 0,
        "total_guests": 0,
        "projected_revenue": "0",
        "top_cuisine": "Error"
      };
    }
  }

  // --- 7. SAVE PRICING (UPDATED with user_id) ---
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
      "user_id": currentUserId, // <--- SEND USER ID
      "menu_id": menuId,
      "base_cost": baseCost,
      "labor_cost": laborCost,
      "transport_cost": transportCost,
      "profit_margin_percent": profitMargin,
      "final_quote_amount": finalAmount
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception("Failed to save pricing: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error saving pricing: $e");
    }
  }

  // --- 8. SAVE INVOICE (UPDATED with user_id) ---
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
      "user_id": currentUserId, // <--- SEND USER ID
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

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception("Failed to save invoice");
      }
    } catch (e) {
      throw Exception("Error saving invoice: $e");
    }
  }

  // --- 9. FETCH INVOICES (UPDATED with user_id) ---
  static Future<List<dynamic>> fetchInvoices() async {
    if (currentUserId == null) return [];

    final url = Uri.parse(
        '$baseUrl/get-invoices?user_id=$currentUserId'); // <--- FILTER
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load invoices");
    }
  }

  // --- 10. ADD PAYMENT ---
  static Future<void> addPayment(
      int invoiceId, double amount, String mode) async {
    final url = Uri.parse('$baseUrl/add-payment');
    final body = {
      "invoice_id": invoiceId,
      "amount": amount,
      "payment_date": DateTime.now().toString().split(' ')[0],
      "payment_mode": mode
    };

    final response = await http.post(url,
        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));

    if (response.statusCode != 200) throw Exception("Failed to add payment");
  }

  // --- 11. FETCH PAYMENTS FOR INVOICE ---
  static Future<List<dynamic>> fetchPaymentsForInvoice(int invoiceId) async {
    final url = Uri.parse('$baseUrl/get-payments/$invoiceId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load payments");
    }
  }

  // --- 12. UPDATE ORDER STATUS ---
  static Future<void> updateOrderStatus(int id, String status) async {
    final url =
        Uri.parse('$baseUrl/update-order-status?invoice_id=$id&status=$status');
    await http.post(url);
  }

  // --- 13. COMPANY PROFILE ---
  static Future<void> saveCompanyProfile({
    required String companyName,
    required String address,
    required String phone,
    String? email,
    String? gst,
  }) async {
    if (currentUserId == null) throw Exception("User not logged in");

    final url = Uri.parse('$baseUrl/save-profile');
    final body = {
      "user_id": currentUserId,
      "company_name": companyName,
      "address": address,
      "phone": phone,
      "email": email ?? "",
      "gst_number": gst ?? ""
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
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {}; // Return empty if failed or no profile
      }
    } catch (e) {
      return {};
    }
  }

  // --- 14. REGENERATE SECTION ---
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
      throw Exception("Error: $e");
    }
  }
}
