// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Only for Auth UID
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Added for Django

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AllMembersTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AllMembersTab({
    super.key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<AllMembersTab> createState() => _AllMembersTabState();
}

class _AllMembersTabState extends State<AllMembersTab> {
  // --- STATE VARIABLES ---
  final TextEditingController _searchController = TextEditingController();

  // Tithe Editing Controllers
  final TextEditingController week1Controller = TextEditingController();
  final TextEditingController week2Controller = TextEditingController();
  final TextEditingController week3Controller = TextEditingController();
  final TextEditingController week4Controller = TextEditingController();

  // Filter & Pagination State
  String? _filterDistrict;
  String? _filterCommunity;
  int _currentPage = 0;
  final int _rowsPerPage = 30;

  // Data State (Replaces Stream)
  List<dynamic> _allMembers = [];
  bool _isLoading = true;

  // Cache for filter dropdowns
  Future<Map<String, dynamic>?>? _overseerDataFuture;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _overseerDataFuture = _fetchOverseerHierarchy();

    // Reset pagination when searching
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    week1Controller.dispose();
    week2Controller.dispose();
    week3Controller.dispose();
    week4Controller.dispose();
    super.dispose();
  }

  // --- 1. FETCH MEMBERS FROM DJANGO ---
  Future<void> _fetchMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);

      // FIXED: Fetch the ID token to prevent 403 Forbidden
      final String? token = await user.getIdToken();

      // URL: /api/users/?overseer_uid=UID
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=${user.uid}',
      );
      
      // FIXED: Injected Authorization header
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _allMembers = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        print("Error fetching members: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Network error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. FETCH OVERSEER HIERARCHY (FILTERS) ---
  Future<Map<String, dynamic>?> _fetchOverseerHierarchy() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // FIXED: Fetch the ID token to prevent 403 Forbidden
      final String? token = await user.getIdToken();

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

  // --- NEUMORPHIC INPUT HELPER ---
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: theme.scaffoldBackgroundColor,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: theme.hintColor),
          icon: prefixIcon != null
              ? Icon(prefixIcon, color: theme.hintColor)
              : null,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    return Column(
      children: [
        // --- SEARCH & FILTER SECTION ---
        NeumorphicContainer(
          borderRadius: 0,
          padding: const EdgeInsets.all(16.0),
          color: baseColor,
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildNeumorphicTextField(
                  controller: _searchController,
                  placeholder: "Search by Name, Surname or Email",
                  prefixIcon: Icons.search,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterSection(),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // --- DATA LIST (Replaces StreamBuilder) ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Builder(
                  builder: (context) {
                    if (_allMembers.isEmpty) {
                      return Center(
                        child: Text(
                          "No members found",
                          style: TextStyle(color: theme.hintColor),
                        ),
                      );
                    }

                    final query = _searchController.text.toLowerCase();

                    // --- FILTERING LOGIC ---
                    final allFilteredMembers = _allMembers.where((data) {
                      // Normalize Search
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final surname = (data['surname'] ?? '')
                          .toString()
                          .toLowerCase();
                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();

                      final matchesSearch =
                          name.contains(query) ||
                          surname.contains(query) ||
                          email.contains(query);

                      // Normalize Dropdown Keys (Django snake_case vs previous CamelCase)
                      final distName =
                          data['district_elder_name'] ??
                          data['districtElderName'] ??
                          '';
                      final commName =
                          data['community_name'] ?? data['communityName'] ?? '';

                      final matchesDistrict =
                          _filterDistrict == null ||
                          distName == _filterDistrict;

                      final matchesCommunity =
                          _filterCommunity == null ||
                          commName == _filterCommunity;

                      return matchesSearch &&
                          matchesDistrict &&
                          matchesCommunity;
                    }).toList();

                    if (allFilteredMembers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_off,
                              size: 48,
                              color: theme.hintColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No members match current filters",
                              style: TextStyle(color: theme.hintColor),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => setState(() {
                                _filterDistrict = null;
                                _filterCommunity = null;
                                _searchController.clear();
                                _currentPage = 0;
                              }),
                              child: Text(
                                "Clear Filters",
                                style: TextStyle(color: theme.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // --- PAGINATION LOGIC ---
                    int totalItems = allFilteredMembers.length;
                    int totalPages = (totalItems / _rowsPerPage).ceil();

                    if (_currentPage >= totalPages) {
                      _currentPage = (totalPages > 0) ? totalPages - 1 : 0;
                    }

                    int startIndex = _currentPage * _rowsPerPage;
                    int endIndex = startIndex + _rowsPerPage;
                    if (endIndex > totalItems) endIndex = totalItems;

                    final paginatedMembers = allFilteredMembers.sublist(
                      startIndex,
                      endIndex,
                    );

                    return Column(
                      children: [
                        // THE LIST/TABLE
                        Expanded(
                          child: widget.isLargeScreen
                              ? _buildDesktopTable(paginatedMembers, theme)
                              : _buildMobileList(paginatedMembers, theme),
                        ),

                        // PAGINATION CONTROLS
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: baseColor,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Showing ${startIndex + 1}-$endIndex of $totalItems",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                child: NeumorphicContainer(
                                  isPressed: false,
                                  borderRadius: 30,
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: _currentPage > 0
                                        ? theme.primaryColor
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Text(
                                "Page ${_currentPage + 1} of $totalPages",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: _currentPage < totalPages - 1
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                child: NeumorphicContainer(
                                  isPressed: false,
                                  borderRadius: 30,
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: _currentPage < totalPages - 1
                                        ? theme.primaryColor
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- DESKTOP VIEW ---
  Widget _buildDesktopTable(List<dynamic> members, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: NeumorphicContainer(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              dividerThickness: 0.5,
              columns: const [
                DataColumn(
                  label: Text(
                    "Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Surname",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "District",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Contact",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Week 1",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Week 2",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Week 3",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Week 4",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Actions",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: members.map((data) {
                return DataRow(
                  cells: [
                    DataCell(Text(data['name'] ?? '')),
                    DataCell(Text(data['surname'] ?? '')),
                    DataCell(
                      Text(
                        "${data['district_elder_name'] ?? data['districtElderName'] ?? ''}",
                      ),
                    ),
                    DataCell(Text(data['phone'] ?? '')),
                    DataCell(Text("R${data['week1'] ?? 0}")),
                    DataCell(Text("R${data['week2'] ?? 0}")),
                    DataCell(Text("R${data['week3'] ?? 0}")),
                    DataCell(Text("R${data['week4'] ?? 0}")),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditTitheDialog(data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMember(data),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // --- MOBILE VIEW ---
  Widget _buildMobileList(List<dynamic> members, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final data = members[index];
        final dist =
            data['district_elder_name'] ?? data['districtElderName'] ?? '';
        final comm = data['community_name'] ?? data['communityName'] ?? '';

        final double w1 =
            double.tryParse(data['week1']?.toString() ?? '0') ?? 0;
        final double w2 =
            double.tryParse(data['week2']?.toString() ?? '0') ?? 0;
        final double w3 =
            double.tryParse(data['week3']?.toString() ?? '0') ?? 0;
        final double w4 =
            double.tryParse(data['week4']?.toString() ?? '0') ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: NeumorphicContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 50,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    (data['name'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${data['name']} ${data['surname']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dist | $comm",
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Total: R${(w1 + w2 + w3 + w4).toStringAsFixed(0)}",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditTitheDialog(data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMember(data),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HELPER METHODS ---

  Widget _buildFilterSection() {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _overseerDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox();

        var data = snapshot.data!;
        List districts = data['districts'] ?? [];

        List<String> elderNames = districts
            .map(
              (e) => (e['district_elder_name'] ?? e['districtElderName'])
                  .toString(),
            )
            .toList();

        List<String> communityNames = [];
        if (_filterDistrict != null) {
          var dist = districts.firstWhere(
            (e) =>
                (e['district_elder_name'] ?? e['districtElderName']) ==
                _filterDistrict,
            orElse: () => null,
          );
          if (dist != null) {
            communityNames = (dist['communities'] as List)
                .map(
                  (c) => (c['community_name'] ?? c['communityName']).toString(),
                )
                .toList();
          }
        }

        return Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            children: [
              Expanded(
                child: NeumorphicContainer(
                  isPressed: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: 12,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterDistrict,
                      hint: Text(
                        "Filter District",
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                      isExpanded: true,
                      dropdownColor: baseColor,
                      items: elderNames
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _filterDistrict = val;
                          _filterCommunity = null;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeumorphicContainer(
                  isPressed: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: 12,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterCommunity,
                      hint: Text(
                        "Filter Community",
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                      isExpanded: true,
                      dropdownColor: baseColor,
                      items: communityNames
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _filterCommunity = val;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filterDistrict = null;
                    _filterCommunity = null;
                    _searchController.clear();
                    _currentPage = 0;
                  });
                },
                child: NeumorphicContainer(
                  isPressed: false,
                  borderRadius: 12,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.clear, color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- EDIT DIALOG (DJANGO PATCH) ---
  void _showEditTitheDialog(Map<String, dynamic> data) {
    week1Controller.text = data['week1']?.toString() ?? '0';
    week2Controller.text = data['week2']?.toString() ?? '0';
    week3Controller.text = data['week3']?.toString() ?? '0';
    week4Controller.text = data['week4']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Edit Offering for ${data['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(week1Controller, "Week 1"),
            const SizedBox(height: 8),
            _buildDialogInput(week2Controller, "Week 2"),
            const SizedBox(height: 8),
            _buildDialogInput(week3Controller, "Week 3"),
            const SizedBox(height: 8),
            _buildDialogInput(week4Controller, "Week 4"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Api().showLoading(context);

              // 1. Prepare Update Logic
              // IMPORTANT: Django 'uid' is your string key. If using auto-increment ID, check your user model.
              // Assuming your ViewSet lookup field is 'uid' or 'pk'.
              // If your model uses 'uid' as primary key: /users/$uid/
              final userUid = data['uid'];

              final url = Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/users/$userUid/',
              );

              final body = jsonEncode({
                'week1': week1Controller.text,
                'week2': week2Controller.text,
                'week3': week3Controller.text,
                'week4': week4Controller.text,
              });

              try {
                // FIXED: Fetch token and inject Authorization header for PATCH request
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception("User not logged in");
                final String? token = await user.getIdToken();

                final response = await http.patch(
                  url,
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $token",
                  },
                  body: body,
                );

                if (response.statusCode == 200) {
                  // Success
                  if (mounted) Navigator.pop(context); // Close loading
                  if (mounted) Navigator.pop(ctx); // Close Dialog
                  _fetchMembers(); // Refresh List

                  OverseerAuditLogs.logAction(
                    action: "UPDATED",
                    details:
                        "Updated offerings for ${data['name']}' weekly tithe",
                    committeeMemberName: widget.committeeMemberName,
                    committeeMemberRole: widget.committeeMemberRole,
                  );
                } else {
                  if (mounted) Navigator.pop(context);
                  print("Update Error: ${response.body}");
                  Api().showMessage(
                    context,
                    "Update Failed: ${response.statusCode}",
                    "Error",
                    Colors.red,
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                Api().showMessage(
                  context,
                  "Network Error: $e",
                  "Error",
                  Colors.red,
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String hint) {
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: hint, border: InputBorder.none),
      ),
    );
  }

  // --- DELETE MEMBER (DJANGO DELETE) ---
  void _deleteMember(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this member?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // Assuming primary key is 'uid' or you have an 'id' field in Django response
              // Prefer using 'uid' if your Django route is /users/<str:uid>/
              final userUid = data['uid'];
              final url = Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/users/$userUid/',
              );

              try {
                // FIXED: Fetch token and inject Authorization header for DELETE request
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception("User not logged in");
                final String? token = await user.getIdToken();

                final response = await http.delete(
                  url,
                  headers: {'Authorization': 'Bearer $token'},
                );
                
                if (response.statusCode == 204) {
                  Navigator.pop(ctx);
                  _fetchMembers(); // Refresh

                  OverseerAuditLogs.logAction(
                    action: "DELETE",
                    details:
                        "Deleted member ${data['name']} ${data['surname']}",
                    committeeMemberName: widget.committeeMemberName,
                    committeeMemberRole: widget.committeeMemberRole,
                    universityCommitteeFace: widget.faceUrl,
                  );
                } else {
                  print("Delete failed: ${response.statusCode}");
                }
              } catch (e) {
                print("Delete network error: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}