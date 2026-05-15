import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OverseerAuditLogs {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logAction({
    required String action,           // e.g., "ADD_COMMITTEE", "DELETE_COMMITTEE", "UPDATE_STATUS"
    required String details,          // Description: "Added John Doe as Treasurer"
    String? referenceId,              // ID of the doc being changed
    
    // --- CONTEXT: THE UNIVERSITY ---
      String? overseerName, 

    // --- CONTEXT: THE ACTOR (Who is currently logged in) ---
    required String? committeeMemberName, // The person who clicked the button
    required String? committeeMemberRole, // Their Portfolio (e.g., Chairperson) 

    // --- CONTEXT: THE TARGET (Who is being affected) ---
    String? memberName,              // If touching an Application
    String? targetMemberName,         // If Adding/Deleting a Committee Member
    String? targetMemberRole,         // The role of the person being added/deleted
    String? universityCommitteeFace, // Their Face URL
    String? expenseName,
    String? expenseAmount,
  }) async {
    final user = _auth.currentUser;

    try {
      await _firestore.collection('audit_logs').doc(user?.uid).collection('logs').add({
        // TIMING
        'timestamp': FieldValue.serverTimestamp(),
        'deviceTime': DateTime.now().toIso8601String(),

        // ACCOUNT INFO (The Branch Account)
        'uid': user?.uid ?? 'System/Guest',
        'overseerEmail': user?.email ?? 'Unknown',

        // ACTION
        'action': action,
        'details': details,
        'referenceId': referenceId ?? 'N/A',

        // THE ACTOR (The specific human verified via Face ID)
        'actorName': committeeMemberName ?? 'Unknown Member',
        'actorRole': committeeMemberRole ?? 'Unknown Portfolio',
        'actorFaceUrl': universityCommitteeFace ?? 'N/A',
        'expenseName': expenseName ?? 'N/A',
        'expenseAmount': expenseAmount ?? 'N/A',

        // ORGANIZATION
        'overseerName': overseerName ?? 'N/A', 

        // THE TARGET (Specifics of what was changed)
        'memberName': memberName ?? 'N/A',       // For Student Apps
        'targetMemberName': targetMemberName ?? 'N/A', // For Committee Mgmt
        'targetMemberRole': targetMemberRole ?? 'N/A', // For Committee Mgmt
      });
      print("Audit Logged: $action - $details");
    } catch (e) {
      print("Failed to write audit log: $e");
    }
  }
}