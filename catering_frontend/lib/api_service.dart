import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android Emulator, or 127.0.0.1 for Web/iOS
  static const String baseUrl = "http://10.0.2.2:8000";
  // NOTE: If you are running on Web, change above to "http://127.0.0.1:8000"

  static Future<Map<String, dynamic>> generateMenu({
    required String eventType,
    required String cuisine,
    required int guestCount,
    required int budget,
    required String dietaryPreference,
  }) async {
    final url = Uri.parse('$baseUrl/generate-menu');

    // 1. Prepare the Data (The MenuRequest)
    final Map<String, dynamic> requestBody = {
      "event_type": eventType,
      "cuisine": cuisine,
      "guest_count": guestCount,
      "budget_per_plate": budget,
      "dietary_preference": dietaryPreference,
      "special_requirements": "None" // Default for now
    };

    try {
      // 2. Send POST Request
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // 3. Decode the Response
        // The backend returns: {"menu_data": "{...json string...}"}
        final decodedResponse = jsonDecode(response.body);

        // 4. Extract the inner JSON string
        String menuString = decodedResponse['menu_data'];

        // 5. Clean the string (Gemini sometimes adds ```json ... ```)
        menuString = menuString.replaceAll('```json', '').replaceAll('```', '');

        // 6. Decode the actual menu
        return jsonDecode(menuString);
      } else {
        throw Exception("Failed to load menu: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error connecting to backend: $e");
    }
  }
}
