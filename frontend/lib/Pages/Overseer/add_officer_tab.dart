// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // For Auth UID only
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class AddOfficerTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AddOfficerTab({
    super.key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<AddOfficerTab> createState() => _AddOfficerTabState();
}

class _AddOfficerTabState extends State<AddOfficerTab> {
  // --- CONTROLLERS ---
  final TextEditingController officerNameController = TextEditingController();
  final TextEditingController communityOfficerController =
      TextEditingController();

  @override
  void dispose() {
    officerNameController.dispose();
    communityOfficerController.dispose();
    super.dispose();
  }

  // --- NEUMORPHIC INPUT HELPER ---
  Widget _buildNeumorphicTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String placeholder,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: NeumorphicContainer(
        isPressed: true, // Inset (Sunken) look for inputs
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: theme.scaffoldBackgroundColor,
        child: TextField(
          controller: controller,
          style: TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: theme.hintColor),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Add District Officer",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 30),

            // ⭐️ MAIN FORM CONTAINER (Popped Out)
            NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(30),
              color: baseColor,
              child: Column(
                children: [
                  _buildNeumorphicTextField(
                    context,
                    controller: officerNameController,
                    placeholder: "District Elder Name",
                  ),

                  _buildNeumorphicTextField(
                    context,
                    controller: communityOfficerController,
                    placeholder: "Community Name",
                  ),

                  const SizedBox(height: 20),

                  // ⭐️ SAVE BUTTON (Popped Out)
                  GestureDetector(
                    onTap: _saveOfficer,
                    child: NeumorphicContainer(
                      isPressed: false, // Popped
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: baseColor,
                      child: Center(
                        child: Text(
                          "Save Officer",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC (MIGRATED TO DJANGO) ---
  Future<void> _saveOfficer() async {
    if (officerNameController.text.isEmpty ||
        communityOfficerController.text.isEmpty) {
      Api().showMessage(
        context,
        "Please fill in both fields.",
        "Missing Info",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      // FIXED: Fetch the ID token to prevent 403 Forbidden
      final String? token = await user.getIdToken();

      // 1. Get Overseer ID from Django
      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      
      // FIXED: Injected Authorization header
      final profileResp = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResp.statusCode != 200)
        throw Exception("Failed to fetch profile");
      final List results = json.decode(profileResp.body);
      if (results.isEmpty) throw Exception("Overseer profile not found");

      final overseerId = results[0]['id'];
      final districtName = officerNameController.text.trim();
      final communityName = communityOfficerController.text.trim();

      // 2. Check if District already exists for this Overseer
      // URL: /api/districts/?overseer=ID&district_elder_name=NAME
      final districtCheckUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/districts/?overseer=$overseerId&district_elder_name=$districtName',
      );
      
      // FIXED: Injected Authorization header
      final distCheckResp = await http.get(
        districtCheckUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      int districtId;

      if (distCheckResp.statusCode == 200 &&
          json.decode(distCheckResp.body).isNotEmpty) {
        // District Exists -> Use ID
        final distData = json.decode(distCheckResp.body)[0];
        districtId = distData['id'];
        print("Found existing district ID: $districtId");
      } else {
        // District Does Not Exist -> Create It
        final createDistUrl = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/districts/',
        );
        
        // FIXED: Injected Authorization header
        final createDistResp = await http.post(
          createDistUrl,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            'overseer': overseerId,
            'district_elder_name': districtName,
          }),
        );

        if (createDistResp.statusCode == 201) {
          final newDistData = json.decode(createDistResp.body);
          districtId = newDistData['id'];
          print("Created new district ID: $districtId");
        } else {
          throw Exception("Failed to create district: ${createDistResp.body}");
        }
      }

      // 3. Create Community linked to District
      final createCommUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/communities/',
      );
      
      // FIXED: Injected Authorization header
      final createCommResp = await http.post(
        createCommUrl,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          'district': districtId,
          'community_name': communityName,
          // 'district_elder_name' is optional in your model, but helpful for flat lookups
          'district_elder_name': districtName,
        }),
      );

      if (mounted) Navigator.pop(context); // Close Loading

      if (createCommResp.statusCode == 201) {
        OverseerAuditLogs.logAction(
          action: "CREATED",
          details: "Created officer $districtName for community $communityName",
          committeeMemberName: widget.committeeMemberName,
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );

        if (mounted) {
          Api().showMessage(
            context,
            "Officer and Community Added Successfully",
            "Success",
            Colors.green,
          );
        }

        // Clear inputs
        officerNameController.clear();
        communityOfficerController.clear();
      } else {
        throw Exception("Failed to create community: ${createCommResp.body}");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close Loading
      if (mounted) {
        Api().showMessage(
          context,
          "Error saving officer: $e",
          "Error",
          Colors.red,
        );
      }
    }
  }
}