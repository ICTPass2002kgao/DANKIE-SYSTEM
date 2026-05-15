// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class UniversityAssignmentScreen extends StatefulWidget {
  final String? uid;
  final String? fullName;
  final String? portfolio;
  final String? province;
  const UniversityAssignmentScreen({
    super.key,
    this.uid,
    this.fullName,
    this.portfolio,
    this.province,
  });

  @override
  State<UniversityAssignmentScreen> createState() =>
      _UniversityAssignmentScreenState();
}

class _UniversityAssignmentScreenState
    extends State<UniversityAssignmentScreen> {
  final Color _baseColor = const Color(0xFFEFF4F9);
  bool _isLoading = true;

  List<dynamic> _allBranches = [];
  List<dynamic> _allOverseers = [];
  List<dynamic> _allDistricts = [];

  String _universitySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final baseUrl = Api().BACKEND_BASE_URL_DEBUG;
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String token = await user.getIdToken() ?? '';
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/tactso_branches/'), headers: headers),
        http.get(Uri.parse('$baseUrl/overseers/'), headers: headers),
        http.get(Uri.parse('$baseUrl/districts/'), headers: headers),
      ]);

      setState(() {
        _allBranches = _parseJson(responses[0]);
        _allOverseers = _parseJson(responses[1]);
        _allDistricts = _parseJson(responses[2]);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _parseJson(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return (decoded is Map && decoded.containsKey('results'))
          ? decoded['results']
          : decoded;
    }
    return [];
  }

  Future<void> _assignUniversity(
    String branchId,
    String overseerId,
    String districtId,
  ) async {
    final baseUrl = Api().BACKEND_BASE_URL_DEBUG;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String token = await user.getIdToken() ?? '';

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/tactso_branches/$branchId/'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "overseer": overseerId,
          "assigned_district": districtId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Assignment Successful")));
        _fetchData();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to assign university")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving assignment")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBranches = _allBranches.where((b) {
      final name = (b['university_name'] ?? '').toString().toLowerCase();
      return name.contains(_universitySearchQuery.toLowerCase());
    }).toList();

    final unassigned = filteredBranches
        .where((b) => b['overseer'] == null)
        .toList();
    final assigned = filteredBranches
        .where((b) => b['overseer'] != null)
        .toList();

    return Scaffold(
      backgroundColor: _baseColor,
      appBar: AppBar(
        title: Text(
          "University Branch Assignments",
          style: TextStyle(
            color: Colors.blueGrey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _baseColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Neumorphic Search Bar for Universities
                  NeumorphicContainer(
                    isPressed: true,
                    color: _baseColor,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _universitySearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search Universities...",
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.blueGrey),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                  _buildSectionHeader(
                    "Unassigned Universities",
                    unassigned.length,
                    Colors.orange,
                  ),
                  SizedBox(height: 15),
                  ...unassigned.map(
                    (b) => _buildUniversityCard(b, isAssigned: false),
                  ),

                  SizedBox(height: 40),

                  _buildSectionHeader(
                    "Managed Universities",
                    assigned.length,
                    Colors.green,
                  ),
                  SizedBox(height: 15),
                  ...assigned.map(
                    (b) => _buildUniversityCard(b, isAssigned: true),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey[800],
          ),
        ),
      ],
    );
  } 
  Widget _buildUniversityCard(dynamic branch, {required bool isAssigned}) {
    String? currentOverseerId = branch['overseer']?.toString();
    String? currentDistrictId = branch['assigned_district']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: NeumorphicContainer(
        borderRadius: 16,
        color: _baseColor,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    branch['university_name'] ?? "Unknown University",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  isAssigned ? Icons.verified : Icons.warning_amber_rounded,
                  color: isAssigned ? Colors.green : Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              branch['address'] ?? "No address provided",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Divider(height: 30),
            _buildAssignmentSelectors(
              branch['id'].toString(),
              currentOverseerId,
              currentDistrictId,
            ),
          ],
        ),
      ),
    );
  } 
  Widget _buildAssignmentSelectors(
    String branchId,
    String? selectedOverseer,
    String? selectedDistrict,
  ) {
    String? localOverseer = selectedOverseer;
    String? localDistrict = selectedDistrict;

    return StatefulBuilder(
      builder: (context, setCardState) {
        List<dynamic> filteredDistricts = _allDistricts
            .where((d) => d['overseer'].toString() == localOverseer)
            .toList();

        return Column(
          children: [
            _dropdownLabel("Lead Overseer"),
            _buildSearchableSelector(
              currentValue: localOverseer,
              hint: "Search Overseer...",
              items: _allOverseers,
              displayKey: 'overseer_initials_surname',
              onChanged: (val) {
                setCardState(() {
                  localOverseer = val;
                  localDistrict = null; // Reset district when overseer changes
                });
              },
            ),
            SizedBox(height: 15),
            _dropdownLabel("Assigned District"),
            _buildSearchableSelector(
              currentValue: localDistrict,
              hint: localOverseer == null
                  ? "Select Overseer First"
                  : "Search District...",
              items: filteredDistricts,
              displayKey: 'district_elder_name',
              onChanged: localOverseer == null
                  ? null
                  : (val) => setCardState(() => localDistrict = val),
            ),
            if (localDistrict != null && localOverseer != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: NeumorphicContainer(
                    isPressed: false,
                    borderRadius: 10,
                    color: Colors.blueGrey[800]!,
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => _assignUniversity(
                        branchId,
                        localOverseer!,
                        localDistrict!,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Center(
                          child: Text(
                            "Confirm & Assign",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dropdownLabel(String text) => Container(
    alignment: Alignment.centerLeft,
    padding: EdgeInsets.only(bottom: 8, left: 5),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
      ),
    ),
  ); 
  Widget _buildSearchableSelector({
    required String? currentValue,
    required String hint,
    required List<dynamic> items,
    required String displayKey,
    required Function(String?)? onChanged,
  }) {
    String displayString = hint;
    if (currentValue != null) {
      final match = items.firstWhere(
        (i) => i['id'].toString() == currentValue,
        orElse: () => null,
      );
      if (match != null) displayString = match[displayKey] ?? hint;
    }

    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              _showSearchableDialog(
                context: context,
                title: "Select Data",
                items: items,
                displayKey: displayKey,
                onSelected: (id) => onChanged(id),
              );
            },
      child: NeumorphicContainer(
        isPressed: false,
        borderRadius: 12,
        color: _baseColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayString,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: currentValue == null
                      ? FontWeight.normal
                      : FontWeight.w600,
                  color: currentValue == null
                      ? Colors.grey[500]
                      : Colors.blueGrey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search,
              size: 18,
              color: onChanged == null ? Colors.grey[300] : Colors.blueGrey,
            ),
          ],
        ),
      ),
    );
  }
  void _showSearchableDialog({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    required String displayKey,
    required Function(String) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items.where((item) {
              final name = (item[displayKey] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Dialog(
              backgroundColor: _baseColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  children: [
                    NeumorphicContainer(
                      isPressed: true,
                      color: _baseColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Type to search...",
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.blueGrey),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                "No results found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.grey.withOpacity(0.2),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  title: Text(
                                    item[displayKey] ?? 'Unknown',
                                    style: TextStyle(
                                      color: Colors.blueGrey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () {
                                    onSelected(item['id'].toString());
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
