// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:ttact/Components/PaystackWebView.dart';
// import 'package:ttact/Components/paystack_service.dart'; 

// class SubscriptionController {
  
//   /// Call this function when the Overseer opens the app
//   static Future<void> checkAndEnforceSubscription(BuildContext context) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     // 1. Get Current Member Count
//     int memberCount = await _getTotalOverseerMemberCount(user.uid);
//     print("DEBUG: Member Count for ${user.uid}: $memberCount"); // Debug print
    
//     // 2. Determine which Paystack Plan they SHOULD be on
//     String? requiredPlan = PaystackService.getRequiredPlan(memberCount);

//     // 3. Get their CURRENT status from Firestore
//     // FIX: Query by the 'uid' field, as the document ID is auto-generated
//     final overseerQuery = await FirebaseFirestore.instance
//         .collection('overseers')
//         .where('uid', isEqualTo: user.uid)
//         .limit(1)
//         .get();

//     if (overseerQuery.docs.isEmpty) {
//       print("DEBUG: No overseer profile found for this user.");
//       return;
//     }

//     final overseerDoc = overseerQuery.docs.first; // The actual document
//     final docRef = overseerDoc.reference;         // Reference for updates

//     String? currentPlan = overseerDoc.data()['currentPlan'];
//     String status = overseerDoc.data()['subscriptionStatus'] ?? 'inactive';

//     print("DEBUG: Required: $requiredPlan | Current: $currentPlan | Status: $status");

//     // --- LOGIC TREE ---

//     // SCENARIO A: Free Tier (0-49 members)
//     if (requiredPlan == null) {
//       if (status != 'active' || currentPlan != 'free_tier') {
//         // Automatically set them to active free tier
//         await docRef.set({
//           'subscriptionStatus': 'active',
//           'currentPlan': 'free_tier',
//         }, SetOptions(merge: true));
//       }
//       return; // Stop here, they are fine.
//     }

//     // SCENARIO B: Paid Tier - Check if they match the requirement
//     // If they are Inactive OR on the wrong plan (e.g. moved from Tier 1 to Tier 2)
//     if (status != 'active' || currentPlan != requiredPlan) {
//       if (context.mounted) {
//         _showSubscriptionLockedScreen(context, requiredPlan, memberCount);
//       }
//     }
//   }

//   static Future<int> _getTotalOverseerMemberCount(String uid) async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('users')
//         .where('overseerUid', isEqualTo: uid)
//         .get();
//     return snapshot.docs.length;
//   }

//   static void _showSubscriptionLockedScreen(BuildContext context, String planCode, int count) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // LOCK THE SCREEN
//       builder: (context) => AlertDialog(
//         title: const Text("Subscription Update Required"),
//         content: Text(
//           "You currently have $count members.\n\n"
//           "To manage this number of members, you must subscribe to our "
//           "${_getTierName(planCode)} plan."
//         ),
//         actions: [
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context); // Close dialog temporarily to show WebView
//               await _startPaystackPayment(context, planCode, count); 
//             },
//             child: const Text("Subscribe Now"),
//           ),
//         ],
//       ),
//     );
//   }

//   static String _getTierName(String code) {
//     if (code == PaystackService.planTier3) return "Tier 3 (500+)";
//     if (code == PaystackService.planTier2) return "Tier 2 (300-499)";
//     return "Tier 1 (50+)";
//   }

//   static Future<void> _startPaystackPayment(BuildContext context, String planCode, int memberCount) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null || user.email == null) return;

//     // 1. Get Paystack URL via Service
//     String? authUrl = await PaystackService.initializeSubscription(
//       email: user.email!,
//       planCode: planCode,
//       memberCount: memberCount,
//     );

//     if (authUrl != null && context.mounted) {
//       // 2. Open WebView
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PaystackWebView(
//             authUrl: authUrl,
//             onSuccess: () async {
//               // 3. Update Firestore on Success
//               // FIX: We must query for the doc again to get the correct reference
//                final overseerQuery = await FirebaseFirestore.instance
//                   .collection('overseers')
//                   .where('uid', isEqualTo: user.uid)
//                   .limit(1)
//                   .get();

//               if (overseerQuery.docs.isNotEmpty) {
//                 await overseerQuery.docs.first.reference.set({
//                   'subscriptionStatus': 'active',
//                   'currentPlan': planCode,
//                   'lastPaymentDate': FieldValue.serverTimestamp(),
//                 }, SetOptions(merge: true));
//               }

//               // 4. Re-check to ensure app unlocks
//               if(context.mounted) {
//                  checkAndEnforceSubscription(context);
//               }
//             },
//           ),
//         ),
//       );
//     } else {
//        ScaffoldMessenger.of(context).showSnackBar(
//          const SnackBar(content: Text("Failed to initialize payment. Please try again."))
//        );
//     }
//   }
// }