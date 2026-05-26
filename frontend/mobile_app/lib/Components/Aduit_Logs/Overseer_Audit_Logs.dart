// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';

class OverseerAuditLogs {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logAction({
    required String action,
    required String details,
    String? referenceId,

    // --- CONTEXT: THE ACTOR ---
    required String? committeeMemberName,
    required String? committeeMemberRole,
    required String? universityCommitteeFace,

    // --- CONTEXT: THE AREA/UNIVERSITY ---
    String? universityName, // Maps to 'overseerName' or 'university_name'
    String? universityLogo, // Maps to 'university_logo'

    // --- CONTEXT: THE TARGET ---
    String? studentName,
    String? targetMemberName,
    String? targetMemberRole,
    
    // --- CONTEXT: EXPENSES (Merged into details if model doesn't support them explicitly) ---
    String? expenseName,
    String? expenseAmount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // ⭐️ Merge expense details into the main details field if they exist
    String finalDetails = details;
    if (expenseName != null) finalDetails += " | Expense: $expenseName";
    if (expenseAmount != null) finalDetails += " | Amount: R$expenseAmount";

    final Map<String, dynamic> payload = {
      'timestamp': DateTime.now().toIso8601String(),
      'device_time': DateTime.now().toIso8601String(),

      // ACCOUNT INFO
      'uid': user.uid,
      'branch_email': user.email ?? 'Unknown',

      // ACTION
      'action': action,
      'details': finalDetails,

      // THE ACTOR
      'actor_name': committeeMemberName ?? 'Unknown',
      'actor_role': committeeMemberRole ?? 'Unknown',
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
      final String? token = await user.getIdToken();
      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/audit_logs/');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ⭐️ Mandatory: Secure your logs
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        print("✅ Audit Logged to Django: $action");
      } else {
        print("❌ Failed to log audit: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ Exception logging audit: $e");
    }
  }
}