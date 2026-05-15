import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Kept for current user info
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:ttact/Components/API.dart'; // Ensure this import points to your API class

class TactsoAuditLogs {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logAction({
    required String action, // e.g., "ADD_COMMITTEE", "DELETE_COMMITTEE"
    required String details, // Description: "Added John Doe as Treasurer"
    String? referenceId, // ID of the doc being changed
    // --- CONTEXT: THE UNIVERSITY ---
    required String? universityName,
    required String? universityLogo,

    // --- CONTEXT: THE ACTOR (Who is currently logged in) ---
    required String? committeeMemberName, // The person who clicked the button
    required String? committeeMemberRole,  
    required String? universityCommitteeFace, 
    String? studentName,  
    String? targetMemberName, 
    String? targetMemberRole,  
  }) async {
    final user = _auth.currentUser;
 
    final Map<String, dynamic> payload = { 
      'timestamp': DateTime.now().toIso8601String(), 
      'device_time': DateTime.now().toIso8601String(),

      // ACCOUNT INFO (The Branch Account)
      'uid': user?.uid ?? 'System/Guest',
      'branch_email': user?.email ?? 'Unknown',

      // ACTION
      'action': action,
      'details': details,
      // 'reference_id': referenceId, // Uncomment if you add reference_id to Django model

      // THE ACTOR
      'actor_name': committeeMemberName ?? 'Unknown Member',
      'actor_role': committeeMemberRole ?? 'Unknown Portfolio',
      'actor_face_url': universityCommitteeFace ?? '',

      // ORGANIZATION
      'university_name': universityName ?? 'N/A',
      'university_logo': universityLogo ?? '',

      // THE TARGET
      'student_name': studentName ?? 'N/A',
      'target_member_name': targetMemberName ?? '',
      'target_member_role': targetMemberRole ?? '',
    };

    try {
      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/audit_logs/');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // Add Authorization header if your API requires it
          // 'Authorization': 'Bearer ...',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        if (kDebugMode) {
          print("✅ Audit Logged to Django: $action");
        }
      } else {
        if (kDebugMode) {
          print(
            "❌ Failed to log audit: ${response.statusCode} - ${response.body}",
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Exception logging audit: $e");
      }
    }
  }
}
