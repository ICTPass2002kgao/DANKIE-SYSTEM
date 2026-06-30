// FILE: districts_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';

class DistrictsScreen extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;

  const DistrictsScreen({
    super.key,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
  });

  @override
  State<DistrictsScreen> createState() => _DistrictsScreenState();
}

class _DistrictsScreenState extends State<DistrictsScreen> {
  List<Map<String, dynamic>> _districts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Not logged in.";
      });
      return;
    }

    try {
      final token = await user.getIdToken();
      final uid = user.uid;

      // Fetch districts and users in parallel
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/districts/?overseer_uid=$uid',
          ),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);

      final distResp = results[0];
      final usersResp = results[1];

      if (distResp.statusCode == 200 && usersResp.statusCode == 200) {
        final List<dynamic> districtsRaw = json.decode(distResp.body);
        final List<dynamic> users = json.decode(usersResp.body);

        // Count members per district
        Map<String, int> memberCounts = {};
        for (var u in users) {
          String districtName =
              u['district_elder_name'] ??
              u['districtElderName'] ??
              'Unassigned';
          memberCounts[districtName] = (memberCounts[districtName] ?? 0) + 1;
        }

        final List<Map<String, dynamic>> districts = [];
        for (var d in districtsRaw) {
          String name =
              d['district_elder_name'] ??
              d['districtElderName'] ??
              'District ${d['id']}';
          districts.add({
            'name': name,
            'count': memberCounts[name] ?? 0,
            'id': d['id'],
          });
        }

        setState(() {
          _districts = districts;
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load data.");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Could not load districts. Check your connection.";
      });
      debugPrint("Error fetching districts: $e");
    }
  }

  // --- DELETE CONFIRMATION + ACTION ---
  Future<void> _confirmDeleteDistrict(Map<String, dynamic> district) async {
    final districtName = district['name'];
    final districtId = district['id'];

    final theme = Theme.of(context);
    final neumoBase = Api().neumoBaseColor(context);

    // Show a neumorphic confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: neumoBase,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: Offset(8, 8),
                blurRadius: 20,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                offset: Offset(-8, -8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                "Delete District",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Are you sure you want to delete $districtName?\nThis action cannot be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[800]),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    // Perform deletion
    await _deleteDistrict(districtId, districtName);
  }

  Future<void> _deleteDistrict(dynamic districtId, String districtName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/districts/$districtId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) Navigator.pop(context); // close loading

      if (response.statusCode == 204 || response.statusCode == 200) {
        // Log the action
        OverseerAuditLogs.logAction(
          action: "DELETE_DISTRICT",
          details: "Deleted district: $districtName (ID: $districtId)",
          committeeMemberName: widget
              .committeeMemberName, // Note: We don't have these in this widget yet; we'll pass them as parameters if needed
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );
        // Refresh list
        _fetchData();
      } else {
        String errorMsg = "Deletion failed.";
        try {
          final body = json.decode(response.body);
          errorMsg = body['error'] ?? body['detail'] ?? errorMsg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLoading() {
    // ... unchanged
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Api().neumoBaseColor(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(3, 3),
              blurRadius: 15,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(-3, -3),
              blurRadius: 15,
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neumoBase = Api().neumoBaseColor(context);

    return Scaffold(
      backgroundColor: neumoBase,
      body: Column(
        children: [
          Api().buildAppBar(context, "Districts")!,
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                ? _buildError(theme)
                : _districts.isEmpty
                ? const Center(child: Text("No districts found."))
                : _buildList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    // ... unchanged
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _districts.length,
        itemBuilder: (context, index) {
          final district = _districts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeumorphicContainer(
              borderRadius: 12,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      district['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  // Member count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${district['count']} members",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  // ⭐️ DELETE BUTTON
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                    onPressed: () => _confirmDeleteDistrict(district),
                    tooltip: "Delete District",
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
