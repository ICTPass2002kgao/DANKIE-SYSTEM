// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Only used for Auth UID
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Added for Django

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AddMemberTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AddMemberTab({
    super.key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<AddMemberTab> createState() => _AddMemberTabState();
}

class _AddMemberTabState extends State<AddMemberTab> {
  // --- CONTROLLERS ---
  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();

  // --- DROPDOWN STATE ---
  String? selectedDistrictElder;
  String? selectedCommunityName;
  String selectedProvince = '';

  // Cache for the overseer data to prevent refetching on every setstate
  Future<Map<String, dynamic>?>? _overseerDataFuture;

  @override
  void initState() {
    super.initState();
    _overseerDataFuture = _fetchOverseerHierarchy();
  }

  @override
  void dispose() {
    memberNameController.dispose();
    memberSurnameController.dispose();
    memberEmailController.dispose();
    memberAddressController.dispose();
    memberContactController.dispose();
    super.dispose();
  }

  // --- 1. FETCH OVERSEER HIERARCHY (DJANGO) ---
  Future<Map<String, dynamic>?> _fetchOverseerHierarchy() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // FIXED: Fetch the ID token to prevent 403 Forbidden
      final String? token = await user.getIdToken();

      // Fetch using Email to find the specific Overseer profile
      final identifier = user.email ?? "";
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=$identifier',
      );

      // FIXED: Injected Authorization header
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          return results[0] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("Error fetching hierarchy: $e");
    }
    return null;
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _buildNeumorphicTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: theme.scaffoldBackgroundColor,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
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
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Register New Member",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),

              // MAIN FORM CONTAINER
              NeumorphicContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(24),
                color: baseColor,
                child: Column(
                  children: [
                    _buildNeumorphicTextField(
                      context,
                      controller: memberNameController,
                      placeholder: "First Name",
                    ),
                    _buildNeumorphicTextField(
                      context,
                      controller: memberSurnameController,
                      placeholder: "Surname",
                    ),
                    _buildNeumorphicTextField(
                      context,
                      controller: memberEmailController,
                      placeholder: "Email (Optional)",
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildNeumorphicTextField(
                      context,
                      controller: memberAddressController,
                      placeholder: "Address",
                    ),
                    _buildNeumorphicTextField(
                      context,
                      controller: memberContactController,
                      placeholder: "Phone Number",
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 10),

                    // Dropdowns for Organization (API Powered)
                    _buildOrgDropdowns(context),

                    const SizedBox(height: 30),

                    // SAVE BUTTON
                    GestureDetector(
                      onTap: _registerMember,
                      child: NeumorphicContainer(
                        isPressed: false,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: baseColor,
                        child: Center(
                          child: Text(
                            "Save Member",
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
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. UPDATED DROPDOWN BUILDER ---
  Widget _buildOrgDropdowns(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    final hintColor = Theme.of(context).hintColor;
    final primaryColor = Theme.of(context).primaryColor;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _overseerDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Text(
            "Overseer profile not found (Check Internet).",
            style: TextStyle(color: hintColor),
          );
        }

        var data = snapshot.data!;
        // Assuming Django returns 'province' and 'districts' nested
        selectedProvince = data['province'] ?? '';

        // Django Serializer returns 'districts' list
        List districts = data['districts'] ?? [];

        // Extract District Elders (Map snake_case if needed)
        List<String> elders = districts
            .map(
              (e) => (e['district_elder_name'] ?? e['districtElderName'])
                  .toString(),
            )
            .toList();

        // Extract Communities based on selected District Elder
        List<String> communities = [];
        if (selectedDistrictElder != null) {
          var dist = districts.firstWhere(
            (e) =>
                (e['district_elder_name'] ?? e['districtElderName']) ==
                selectedDistrictElder,
            orElse: () => null,
          );

          if (dist != null) {
            // Django Serializer usually nests 'communities' inside 'districts'
            communities = (dist['communities'] as List)
                .map(
                  (c) => (c['community_name'] ?? c['communityName']).toString(),
                )
                .toList();
          }
        }

        return Column(
          children: [
            // DISTRICT ELDER DROPDOWN
            NeumorphicContainer(
              isPressed: true,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: baseColor,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDistrictElder,
                  hint: Text(
                    "Select District Elder",
                    style: TextStyle(color: hintColor),
                  ),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  dropdownColor: baseColor,
                  items: elders
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedDistrictElder = val;
                    selectedCommunityName = null; // Reset community
                  }),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // COMMUNITY DROPDOWN
            NeumorphicContainer(
              isPressed: true,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: baseColor,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCommunityName,
                  hint: Text(
                    "Select Community",
                    style: TextStyle(color: hintColor),
                  ),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  dropdownColor: baseColor,
                  items: communities
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedCommunityName = val;
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 3. UPDATED REGISTRATION LOGIC (DJANGO API) ---
  Future<void> _registerMember() async {
    if (memberNameController.text.isEmpty ||
        memberSurnameController.text.isEmpty ||
        selectedDistrictElder == null) {
      Api().showMessage(
        context,
        "Please fill required fields (Name, Surname, District)",
        "Error",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final uid = user.uid;
      // FIXED: Fetch the ID token to prevent 403 Forbidden
      final String? token = await user.getIdToken();

      // Construct the payload for Django UserSerializer
      final Map<String, dynamic> payload = {
        'uid': DateTime.now().millisecondsSinceEpoch
            .toString(), // Temp UID or let Django gen UUID
        'name': memberNameController.text.trim(),
        'surname': memberSurnameController.text.trim(),
        'email': memberEmailController.text.trim(),
        'address': memberAddressController.text.trim(),
        'phone': memberContactController.text.trim(),
        'overseer_uid': uid, // Ensure field matches Django Model (overseer_uid)
        'role': 'Member',
        'province': selectedProvince,
        'district_elder_name': selectedDistrictElder,
        'community_name': selectedCommunityName,
        'week1': "0.0",
        'week2': "0.0",
        'week3': "0.0",
        'week4': "0.0",
        // 'createdAt': is handled by auto_now_add in Django
      };

      // Send POST request
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/');
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer $token", // FIXED: Injected Authorization header
        },
        body: jsonEncode(payload),
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Api().showMessage(
            context,
            "Member added successfully",
            "Success",
            Colors.green,
          );
        }

        // Keep Audit Log (Assuming Audit class handles backend, or needs similar update)
        OverseerAuditLogs.logAction(
          action: "CREATED",
          details: "Created member ${memberNameController.text.trim()}",
          committeeMemberName: widget.committeeMemberName,
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );

        _clearMemberInputs();
      } else {
        // Handle Server Errors
        print("Server Error: ${response.body}");
        if (mounted) {
          Api().showMessage(
            context,
            "Failed to add member. Status: ${response.statusCode}",
            "Error",
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) {
        Api().showMessage(context, "Network Error: $e", "Error", Colors.red);
      }
    }
  }

  void _clearMemberInputs() {
    memberNameController.clear();
    memberSurnameController.clear();
    memberEmailController.clear();
    memberAddressController.clear();
    memberContactController.clear();
    setState(() {
      selectedDistrictElder = null;
      selectedCommunityName = null;
    });
  }
}
