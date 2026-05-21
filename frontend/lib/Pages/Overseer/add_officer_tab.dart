// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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

  // --- STATE VARIABLES ---
  bool _isReassignMode = false;
  bool _isLoadingHierarchy = true;

  // Cached data for dropdowns and exist-checks
  String? _overseerId;
  List<Map<String, dynamic>> _districtsList = [];
  List<Map<String, dynamic>> _communitiesList = [];

  // Dropdown selections
  String? _selectedCommunityId;
  String? _selectedDistrictId;

  @override
  void initState() {
    super.initState();
    _loadHierarchy();
  }

  @override
  void dispose() {
    officerNameController.dispose();
    communityOfficerController.dispose();
    super.dispose();
  }

  // --- 1. LOAD DATA HIERARCHY ---
  Future<void> _loadHierarchy() async {
    setState(() => _isLoadingHierarchy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final String? token = await user.getIdToken();

      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );

      final profileResp = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResp.statusCode == 200) {
        final List results = json.decode(profileResp.body);
        if (results.isNotEmpty) {
          final data = results[0];
          _overseerId = data['id']?.toString();

          List districtsData = data['districts'] ?? [];
          List<Map<String, dynamic>> tempDistricts = [];
          List<Map<String, dynamic>> tempCommunities = [];

          for (var dist in districtsData) {
            tempDistricts.add({
              'id': dist['id'].toString(),
              'name': dist['district_elder_name'].toString(),
            });

            List commsData = dist['communities'] ?? [];
            for (var comm in commsData) {
              tempCommunities.add({
                'id': comm['id'].toString(),
                'name': comm['community_name'].toString(),
                'current_district_id': dist['id'].toString(),
                'current_district_name': dist['district_elder_name'].toString(),
              });
            }
          }

          setState(() {
            _districtsList = tempDistricts;
            _communitiesList = tempCommunities;
          });
        }
      }
    } catch (e) {
      print("Error loading hierarchy: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHierarchy = false);
    }
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
        isPressed: true,
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

  // --- DROPDOWN HELPER ---
  Widget _buildNeumorphicDropdown(
    BuildContext context, {
    required String? value,
    required String placeholder,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: theme.scaffoldBackgroundColor,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: theme.scaffoldBackgroundColor,
            hint: Text(placeholder, style: TextStyle(color: theme.hintColor)),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['id'],
                child: Text(
                  item['name'],
                  style: TextStyle(color: Colors.black87),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Manage Officers & Communities",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),

            // ⭐️ MODE TOGGLE (Add New vs Reassign)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(
                  title: "Add / Create",
                  isActive: !_isReassignMode,
                  onTap: () => setState(() => _isReassignMode = false),
                ),
                const SizedBox(width: 15),
                _buildModeButton(
                  title: "Reassign",
                  isActive: _isReassignMode,
                  onTap: () => setState(() => _isReassignMode = true),
                ),
              ],
            ),
            const SizedBox(height: 30),

            _isLoadingHierarchy
                ? const Center(child: CircularProgressIndicator())
                : NeumorphicContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(30),
                    color: baseColor,
                    child: _isReassignMode
                        ? _buildReassignForm()
                        : _buildAddNewForm(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        isPressed: isActive, // Sunken if active, popped if inactive
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: theme.scaffoldBackgroundColor,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? theme.primaryColor : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- FORM 1: ADD NEW (With auto-reassign logic) ---
  Widget _buildAddNewForm() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Create a new officer or assign an existing community to a typed name.",
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _saveOrReassignOfficerByName,
          child: NeumorphicContainer(
            isPressed: false,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Text(
                "Save",
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- FORM 2: REASSIGN EXISTING ---
  Widget _buildReassignForm() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Move an existing community to a different District Elder.",
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildNeumorphicDropdown(
          context,
          value: _selectedCommunityId,
          placeholder: "Select Community",
          items: _communitiesList,
          onChanged: (val) => setState(() => _selectedCommunityId = val),
        ),
        _buildNeumorphicDropdown(
          context,
          value: _selectedDistrictId,
          placeholder: "Select Target District Elder",
          items: _districtsList,
          onChanged: (val) => setState(() => _selectedDistrictId = val),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _reassignCommunityByDropdown,
          child: NeumorphicContainer(
            isPressed: false,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Text(
                "Reassign Community",
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CORE LOGIC 1: ADD NEW (Or Auto-Reassign if Typed Name Exists)
  // ===========================================================================
  Future<void> _saveOrReassignOfficerByName() async {
    final districtName = officerNameController.text.trim();
    final communityName = communityOfficerController.text.trim();

    if (districtName.isEmpty || communityName.isEmpty) {
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
      if (user == null || _overseerId == null)
        throw Exception("User not initialized properly");
      final String? token = await user.getIdToken();

      // 1. Check if the typed District exists globally for this overseer
      String? targetDistrictId;
      var existingDist = _districtsList
          .where(
            (d) =>
                d['name'].toString().toLowerCase() ==
                districtName.toLowerCase(),
          )
          .toList();

      if (existingDist.isNotEmpty) {
        targetDistrictId = existingDist[0]['id'];
      } else {
        // Create New District
        final createDistResp = await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/districts/'),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            'overseer': _overseerId,
            'district_elder_name': districtName,
          }),
        );
        if (createDistResp.statusCode == 201) {
          targetDistrictId = json.decode(createDistResp.body)['id'].toString();
        } else {
          throw Exception("Failed to create district");
        }
      }

      // 2. Check if the typed Community already exists anywhere for this overseer
      var existingComm = _communitiesList
          .where(
            (c) =>
                c['name'].toString().toLowerCase() ==
                communityName.toLowerCase(),
          )
          .toList();

      if (existingComm.isNotEmpty) {
        // COMMUNITY EXISTS -> REASSIGN IT
        String communityId = existingComm[0]['id'];
        await _executeReassignment(
          token: token!,
          communityId: communityId,
          communityName: communityName,
          newDistrictId: targetDistrictId!,
          newDistrictName: districtName,
          userUid: user.uid,
        );
      } else {
        // COMMUNITY DOES NOT EXIST -> CREATE IT
        final createCommResp = await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/'),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            'district': targetDistrictId,
            'community_name': communityName,
            'district_elder_name': districtName,
          }),
        );
        if (createCommResp.statusCode != 201)
          throw Exception("Failed to create community");
      }

      if (mounted) Navigator.pop(context); // Close loading

      OverseerAuditLogs.logAction(
        action: "CREATED/ASSIGNED",
        details: "Assigned community $communityName to district $districtName",
        committeeMemberName: widget.committeeMemberName,
        committeeMemberRole: widget.committeeMemberRole,
        universityCommitteeFace: widget.faceUrl,
      );

      Api().showMessage(
        context,
        "Saved Successfully!",
        "Success",
        Colors.green,
      );
      officerNameController.clear();
      communityOfficerController.clear();
      _loadHierarchy(); // Refresh Dropdowns
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  // ===========================================================================
  // CORE LOGIC 2: REASSIGN FROM DROPDOWNS
  // ===========================================================================
  Future<void> _reassignCommunityByDropdown() async {
    if (_selectedCommunityId == null || _selectedDistrictId == null) {
      Api().showMessage(
        context,
        "Please select both a community and a district.",
        "Error",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      final String? token = await user.getIdToken();

      // Find names for the logs and user updates
      final commData = _communitiesList.firstWhere(
        (c) => c['id'] == _selectedCommunityId,
      );
      final distData = _districtsList.firstWhere(
        (d) => d['id'] == _selectedDistrictId,
      );

      await _executeReassignment(
        token: token!,
        communityId: commData['id'],
        communityName: commData['name'],
        newDistrictId: distData['id'],
        newDistrictName: distData['name'],
        userUid: user.uid,
      );

      if (mounted) Navigator.pop(context);

      OverseerAuditLogs.logAction(
        action: "REASSIGNED",
        details:
            "Moved community ${commData['name']} to district ${distData['name']}",
        committeeMemberName: widget.committeeMemberName,
        committeeMemberRole: widget.committeeMemberRole,
        universityCommitteeFace: widget.faceUrl,
      );

      Api().showMessage(
        context,
        "Reassigned Successfully!",
        "Success",
        Colors.green,
      );

      setState(() {
        _selectedCommunityId = null;
        _selectedDistrictId = null;
      });
      _loadHierarchy();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  // ===========================================================================
  // THE ENGINE: Updates Community & Patches all related Users
  // ===========================================================================
  Future<void> _executeReassignment({
    required String token,
    required String communityId,
    required String communityName,
    required String newDistrictId,
    required String newDistrictName,
    required String userUid,
  }) async {
    // 1. Update Community in Django
    final commPatchResp = await http.patch(
      Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/$communityId/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'district': newDistrictId,
        'district_elder_name': newDistrictName,
      }),
    );
    if (commPatchResp.statusCode != 200)
      throw Exception("Failed to update Community record");

    // 2. Fetch all users belonging to this community
    // Because communityName could have spaces, encode it for the URL
    final String encCommName = Uri.encodeComponent(communityName);
    final usersResp = await http.get(
      Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$userUid&community_name=$encCommName',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (usersResp.statusCode == 200) {
      List users = json.decode(usersResp.body);

      // 3. Patch all users in parallel to update their district elder
      List<Future> patchTasks = [];
      for (var u in users) {
        String uId = u['uid'];
        patchTasks.add(
          http.patch(
            Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/$uId/'),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({'district_elder_name': newDistrictName}),
          ),
        );
      }

      // Wait for all users to be updated simultaneously
      await Future.wait(patchTasks);
    }
  }
}
