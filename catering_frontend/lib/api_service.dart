import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.221.71.64:8000";

  // --- 1. GENERATE MENU ---
  static Future<Map<String, dynamic>> generateMenu({
    required String eventType,
    required String cuisine,
    required int guestCount,
    required int budget,
    required String dietaryPreference,
  }) async {
    final url = Uri.parse('$baseUrl/generate-menu');

    // Using budget_per_plate as per your request
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

  // --- 2. SAVE MENU (CRITICAL FIX) ---
  // I changed 'void' to 'Map<String, dynamic>' so we can get the NEW ID.
  static Future<Map<String, dynamic>> saveMenuToDatabase({
    required String eventType,
    required String cuisine,
    required int guestCount,
    required int budget,
    required Map<String, dynamic> fullMenu,
  }) async {
    final url = Uri.parse('$baseUrl/save-menu');
    final String menuJsonString = jsonEncode(fullMenu);

    final Map<String, dynamic> body = {
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
        // RETURN THE RESPONSE (This contains the New ID)
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to save: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error saving menu: $e");
    }
  }

  // --- 3. FETCH SAVED MENUS ---
  static Future<List<dynamic>> fetchSavedMenus() async {
    final url = Uri.parse('$baseUrl/get-menus');
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

  // --- 4. DELETE MENU ---
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

  // --- 5. DASHBOARD STATS ---
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final url = Uri.parse('$baseUrl/dashboard-stats');
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

  // --- 6. SAVE PRICING ---
  static Future<void> savePricing({
    required int menuId,
    required double baseCost,
    required double laborCost,
    required double transportCost,
    required double profitMargin,
    required double finalAmount,
  }) async {
    final url = Uri.parse('$baseUrl/save-pricing');
    final Map<String, dynamic> body = {
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

  // --- 7. SAVE INVOICE ---
  static Future<void> saveInvoice({
    required int menuId,
    required String clientName,
    required double finalAmount,
    required double taxPercent,
    required double discount,
    required double grandTotal,
    required String eventDate,
  }) async {
    final url = Uri.parse('$baseUrl/save-invoice');
    final Map<String, dynamic> body = {
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

  // --- 8. FETCH INVOICES ---
  static Future<List<dynamic>> fetchInvoices() async {
    final url = Uri.parse('$baseUrl/get-invoices');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load invoices");
    }
  }

  // --- 9. ADD PAYMENT ---
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

  // --- 10. FETCH PAYMENTS FOR INVOICE ---
  static Future<List<dynamic>> fetchPaymentsForInvoice(int invoiceId) async {
    final url = Uri.parse('$baseUrl/get-payments/$invoiceId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load payments");
    }
  }

  // --- 11. UPDATE ORDER STATUS ---
  static Future<void> updateOrderStatus(int id, String status) async {
    final url =
        Uri.parse('$baseUrl/update-order-status?invoice_id=$id&status=$status');
    await http.post(url);
  }
}
