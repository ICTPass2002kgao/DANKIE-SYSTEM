// FILE: communities_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class CommunitiesScreen extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;

  const CommunitiesScreen({
    super.key,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
  });

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<Map<String, dynamic>> _allCommunities = [];
  List<Map<String, dynamic>> _filteredCommunities = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Add community dialog
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _districtOptions = []; // id: String, name: String
  String? _selectedDistrictForAdd;
  bool _isSubmitting = false;

  // Filter state
  String? _filterDistrictId; // null = show all

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

      // 1. Fetch overseer profile (includes districts with communities)
      final profileResp = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${Uri.encodeComponent(user.email!)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResp.statusCode != 200) {
        throw Exception(
          "Failed to load profile (Status ${profileResp.statusCode})",
        );
      }

      final List overseers = json.decode(profileResp.body);
      if (overseers.isEmpty) throw Exception("Overseer not found.");
      final overseerData = overseers[0];

      // 2. Fetch all users for member counts + gender breakdown
      final usersResp = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (usersResp.statusCode != 200) {
        throw Exception(
          "Failed to load users (Status ${usersResp.statusCode})",
        );
      }

      final List<dynamic> users = json.decode(usersResp.body);

      Map<String, int> totalCounts = {};
      Map<String, int> maleCounts = {};
      Map<String, int> femaleCounts = {};

      for (var u in users) {
        String? commName = u['community_name'] ?? u['communityName'];
        if (commName != null && commName.isNotEmpty) {
          totalCounts[commName] = (totalCounts[commName] ?? 0) + 1;
          String gender = u['gender']?.toString().toLowerCase() ?? '';
          if (gender == 'male') {
            maleCounts[commName] = (maleCounts[commName] ?? 0) + 1;
          } else if (gender == 'female') {
            femaleCounts[commName] = (femaleCounts[commName] ?? 0) + 1;
          }
        }
      }

      // 3. Build communities list from nested districts
      final List districtsRaw = overseerData['districts'] ?? [];
      List<Map<String, dynamic>> tempDistrictOptions = [];
      List<Map<String, dynamic>> communitiesList = [];

      for (var dist in districtsRaw) {
        // ⭐️ All IDs are strings
        final String distId = dist['id'].toString();
        final String distName =
            dist['district_elder_name'] ?? 'District $distId';

        tempDistrictOptions.add({'id': distId, 'name': distName});

        final List communitiesRaw = dist['communities'] ?? [];
        for (var c in communitiesRaw) {
          final String commName =
              c['community_name'] ?? c['name'] ?? 'Community ${c['id']}';
          communitiesList.add({
            'id': c['id'].toString(),
            'name': commName,
            'district_elder_name': distName,
            'district_id': distId, // string
            'total': totalCounts[commName] ?? 0,
            'brothers': maleCounts[commName] ?? 0,
            'sisters': femaleCounts[commName] ?? 0,
          });
        }
      }

      // Sort by total members descending
      communitiesList.sort(
        (a, b) => (b['total'] as int).compareTo(a['total'] as int),
      );

      setState(() {
        _allCommunities = communitiesList;
        _districtOptions = tempDistrictOptions;
        _selectedDistrictForAdd = tempDistrictOptions.isNotEmpty
            ? tempDistrictOptions.first['id']
            : null;
        _filterDistrictId = null;
        _filteredCommunities = List.from(communitiesList);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Could not load communities: ${e.toString()}";
      });
      debugPrint("Error fetching communities: $e");
    }
  }

  void _applyFilter(String? districtId) {
    setState(() {
      _filterDistrictId = districtId;
      if (districtId == null) {
        _filteredCommunities = List.from(_allCommunities);
      } else {
        _filteredCommunities = _allCommunities
            .where((c) => c['district_id'] == districtId)
            .toList();
      }
    });
  }

  // --- ADD COMMUNITY DIALOG ---
  Future<void> _showAddCommunityDialog() async {
    _nameController.clear();
    _isSubmitting = false;
    if (_districtOptions.isNotEmpty &&
        !_districtOptions.any((d) => d['id'] == _selectedDistrictForAdd)) {
      _selectedDistrictForAdd = _districtOptions.first['id'];
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        final neumoBase = Api().neumoBaseColor(context);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
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
                    Text(
                      "Add New Community",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Community Name",
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: neumoBase,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // ⭐️ Dropdown uses String values
                    DropdownButtonFormField<String>(
                      value: _selectedDistrictForAdd,
                      decoration: InputDecoration(
                        labelText: "District Elder",
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: neumoBase,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _districtOptions.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'],
                          child: Text(d['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedDistrictForAdd = value;
                        });
                      },
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text("Cancel"),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (_nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Community name is required.",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  if (_selectedDistrictForAdd == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Please select a district elder.",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  setDialogState(() => _isSubmitting = true);
                                  bool success = await _addCommunity(
                                    _nameController.text.trim(),
                                    _selectedDistrictForAdd!,
                                  );
                                  setDialogState(() => _isSubmitting = false);
                                  if (success) {
                                    Navigator.pop(dialogContext);
                                    _fetchData();
                                  }
                                },
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text("Add Community"),
                        ),
                      ],
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

  Future<bool> _addCommunity(String name, String districtId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final token = await user.getIdToken();
      final overseerResp = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${Uri.encodeComponent(user.email!)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (overseerResp.statusCode != 200) return false;
      final overseers = json.decode(overseerResp.body);
      if (overseers.isEmpty) return false;
      final overseerId = overseers[0]['id'].toString();

      final response = await http.post(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'community_name': name,
          'district': districtId, // string
          'overseer': overseerId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Community added successfully."),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        String msg = 'Failed to add community.';
        try {
          final error = json.decode(response.body);
          msg = error['error'] ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Widget _buildLoading() {
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
          Api().buildAppBar(context, "Communities (Branches)")!,
          // District filter (uses String IDs)
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildDistrictFilter(theme, neumoBase),
            ),
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                ? _buildError(theme)
                : _filteredCommunities.isEmpty
                ? const Center(child: Text("No communities found."))
                : _buildList(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.primaryColor,
        onPressed: _showAddCommunityDialog,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDistrictFilter(ThemeData theme, Color neumoBase) {
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: neumoBase,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterDistrictId,
          isExpanded: true,
          dropdownColor: neumoBase,
          hint: Text(
            "All District Elders",
            style: TextStyle(color: Colors.grey[600]),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text("All District Elders"),
            ),
            ..._districtOptions.map((d) {
              return DropdownMenuItem<String?>(
                value: d['id'],
                child: Text(d['name']),
              );
            }),
          ],
          onChanged: (val) => _applyFilter(val),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
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
        itemCount: _filteredCommunities.length,
        itemBuilder: (context, index) {
          final comm = _filteredCommunities[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeumorphicContainer(
              borderRadius: 12,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comm['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "District Elder: ${comm['district_elder_name']}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Brothers: ${comm['brothers']}  |  Sisters: ${comm['sisters']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total count badge
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
                      "${comm['total']} members",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
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
