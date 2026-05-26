import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';

class PaystackService {
  // UPDATE THIS with your actual deployed Cloud Function URL
  static String backendUrl =
      "${Api().BACKEND_BASE_URL_DEBUG}/initialize-subscription/";

  static const String planTier1 = "PLN_46b9pjpmkuni447"; // 50 - 299 members
  static const String planTier2 = "PLN_ror17qu33rhb5qp"; // 300 - 499 members
  static const String planTier3 = "PLN_p0euzaur4kkurpr"; // 500+ members

  /// Logic: Returns the specific Paystack Plan Code required.
  /// Returns NULL if they are in the Free Tier (< 50 members).
  static String? getRequiredPlan(int memberCount) {
    if (memberCount >= 400) return planTier3;
    if (memberCount >= 200) return planTier2;
    if (memberCount >= 50) return planTier1;
    return null; // Free Tier
  }

  static Future<String?> initializeSubscription({
    required String email,
    required String planCode,
    required int memberCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'email': email,
          'uid': user.uid,
          'plan_code': planCode, // <--- IMPORTANT: Sending Plan Code
          'member_count': memberCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['authorization_url'];
      } else {
        print('Backend Error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception: $e');
      return null;
    }
  }
}
