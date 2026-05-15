// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SpiritualManagementTab extends StatefulWidget {
  final String branchId;
  final String? overseerId;
  final String? districtId;
  final String universityName;
  final Color neumoColor;
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? universityLogoUrl;

  const SpiritualManagementTab({
    Key? key,
    required this.branchId,
    this.overseerId,
    this.districtId,
    required this.universityName,
    required this.neumoColor,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.universityLogoUrl,
  }) : super(key: key);

  @override
  State<SpiritualManagementTab> createState() => _SpiritualManagementTabState();
}

class _SpiritualManagementTabState extends State<SpiritualManagementTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _overseerData;
  Map<String, dynamic>? _districtData;
  List<dynamic> _usersList = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Pagination state
  int _currentPage = 0;
  final int _rowsPerPage = 50;

  Color get _primaryColor => Theme.of(context).primaryColor;

  int get totalMembers => _usersList.length;
  int get presentMembers =>
      _usersList.where((u) => u['isPresent'] == true).length;
  int get absentMembers => totalMembers - presentMembers;
  double get attendancePercentage =>
      totalMembers == 0 ? 0.0 : presentMembers / totalMembers;

  // New Data Getters for Charts
  int get totalTestifies => _usersList
      .where(
        (u) =>
            (u['isVisitor'] == true || u['is_visitor'] == true) &&
            u['visitor_category'] != 'Mother' &&
            u['visitor_category'] != 'Father',
      )
      .length;

  int get readyTestifies => _usersList
      .where(
        (u) =>
            (u['isVisitor'] == true || u['is_visitor'] == true) &&
            u['visitor_category'] != 'Mother' &&
            u['visitor_category'] != 'Father' &&
            (u['ready_for_membership'] == true ||
                u['ready_for_membership'] == 'true'),
      )
      .length;

  int get brothersTotal => _usersList
      .where((u) => u['gender']?.toString().toLowerCase() == 'male')
      .length;
  int get brothersPresent => _usersList
      .where(
        (u) =>
            u['isPresent'] == true &&
            u['gender']?.toString().toLowerCase() == 'male',
      )
      .length;

  int get sistersTotal => _usersList
      .where((u) => u['gender']?.toString().toLowerCase() == 'female')
      .length;
  int get sistersPresent => _usersList
      .where(
        (u) =>
            u['isPresent'] == true &&
            u['gender']?.toString().toLowerCase() == 'female',
      )
      .length;

  List<dynamic> get _filteredUsers {
    List<dynamic> baseList = _usersList;

    if (_searchQuery.isNotEmpty) {
      baseList = _usersList.where((user) {
        final name = "${user['name'] ?? ''} ${user['surname'] ?? ''}"
            .toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    baseList.sort((a, b) {
      bool aIsParent =
          a['visitor_category'] == 'Mother' ||
          a['visitor_category'] == 'Father';
      bool bIsParent =
          b['visitor_category'] == 'Mother' ||
          b['visitor_category'] == 'Father';

      if (aIsParent && !bIsParent) return -1;
      if (!aIsParent && bIsParent) return 1;

      final nameA = "${a['name'] ?? ''} ${a['surname'] ?? ''}".toLowerCase();
      final nameB = "${b['name'] ?? ''} ${b['surname'] ?? ''}".toLowerCase();
      return nameA.compareTo(nameB);
    });

    return baseList;
  }

  @override
  void initState() {
    super.initState();
    _fetchSpiritualData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpiritualData() async {
    setState(() => _isLoading = true);

    // Cache current attendance states so we don't wipe out the toggles
    Map<String, bool> previousAttendanceState = {};
    for (var user in _usersList) {
      if (user['ui_id'] != null) {
        previousAttendanceState[user['ui_id']] = user['isPresent'] ?? false;
      }
    }

    try {
      final baseUrl = Api().BACKEND_BASE_URL_DEBUG;
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (widget.overseerId != null) {
        final oRes = await http.get(
          Uri.parse('$baseUrl/overseers/${widget.overseerId}/'),
          headers: headers,
        );
        if (oRes.statusCode == 200) {
          _overseerData = Map<String, dynamic>.from(json.decode(oRes.body));
        }
      }

      if (widget.districtId != null) {
        final dRes = await http.get(
          Uri.parse('$baseUrl/districts/${widget.districtId}/'),
          headers: headers,
        );
        if (dRes.statusCode == 200) {
          _districtData = Map<String, dynamic>.from(json.decode(dRes.body));
        }
      }

      final uRes = await http.get(
        Uri.parse('$baseUrl/users/?community_name=${widget.universityName}'),
        headers: headers,
      );
      List<Map<String, dynamic>> members = [];
      if (uRes.statusCode == 200) {
        final decoded = json.decode(uRes.body);
        final rawList = (decoded is Map && decoded.containsKey('results'))
            ? decoded['results'] as List
            : decoded as List;
        members = rawList.map((m) {
          final map = Map<String, dynamic>.from(m as Map);
          map['isVisitor'] = false;
          map['visitor_category'] = 'Registered';
          map['ui_id'] = map['uid'];
          map['isPresent'] = previousAttendanceState[map['uid']] ?? false;
          return map;
        }).toList();
      }

      final vRes = await http.get(
        Uri.parse('$baseUrl/visitors/?community_name=${widget.universityName}'),
        headers: headers,
      );
      List<Map<String, dynamic>> visitors = [];
      if (vRes.statusCode == 200) {
        final decoded = json.decode(vRes.body);
        final rawList = (decoded is Map && decoded.containsKey('results'))
            ? decoded['results'] as List
            : decoded as List;
        visitors = rawList.map((v) {
          final map = Map<String, dynamic>.from(v as Map);
          map['isVisitor'] = true;
          map['visitor_category'] = map['visitor_category'] ?? 'Testify';
          map['ui_id'] = map['id'];
          map['isPresent'] = previousAttendanceState[map['id']] ?? false;
          return map;
        }).toList();
      }

      _usersList = [...members, ...visitors];
    } catch (e) {
      debugPrint("Error fetching spiritual data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUserAttendance(
    String uiId,
    bool isPresent,
    bool isVisitor,
  ) async {
    final index = _usersList.indexWhere((u) => u['ui_id'] == uiId);
    if (index == -1) return;

    setState(() {
      _usersList[index]['isPresent'] = isPresent;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      final endpoint = isVisitor ? '/visitors/$uiId/' : '/users/$uiId/';

      await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'attendance_status': isPresent ? 'Present' : 'Absent',
        }),
      );
    } catch (e) {
      debugPrint("Error saving attendance: $e");
    }
  }

  Future<void> _updateMemberDetails(
    String uiId,
    bool isVisitor,
    Map<String, dynamic> updatedData,
  ) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      final endpoint = isVisitor ? '/visitors/$uiId/' : '/users/$uiId/';

      final res = await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode(updatedData),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        Api().showMessage(
          context,
          "Record updated successfully.",
          "Success",
          Colors.green,
        );
        await _fetchSpiritualData(); // Refresh the list
      } else {
        Api().showMessage(
          context,
          "Failed to update record.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      Api().showMessage(context, "An error occurred.", "Error", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditMemberDialog(Map<String, dynamic> userMap, bool isVisitor) {
    final nameCtrl = TextEditingController(text: userMap['name'] ?? '');
    final surnameCtrl = TextEditingController(text: userMap['surname'] ?? '');
    final phoneCtrl = TextEditingController(text: userMap['phone'] ?? '');

    bool isReadyForMembership = false;
    if (userMap['ready_for_membership'] != null) {
      isReadyForMembership =
          userMap['ready_for_membership'] == true ||
          userMap['ready_for_membership'] == 'true';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 400,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.neumoColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-10, -10),
                      blurRadius: 20,
                    ),
                    BoxShadow(
                      color: Colors.grey.shade400,
                      offset: Offset(10, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.pencil_circle_fill,
                            color: _primaryColor,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Edit Record",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Update testifier/visitor details.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 24),

                      _buildNeuInput(
                        "First Name",
                        nameCtrl,
                        CupertinoIcons.person_fill,
                      ),
                      _buildNeuInput("Surname", surnameCtrl),
                      _buildNeuInput(
                        "Contact Number",
                        phoneCtrl,
                        CupertinoIcons.phone_fill,
                      ),

                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isReadyForMembership
                              ? Colors.green.withOpacity(0.1)
                              : widget.neumoColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isReadyForMembership
                                ? Colors.green
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Ready for Membership",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isReadyForMembership
                                          ? Colors.green[800]
                                          : Colors.blueGrey[800],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Has met the Priest & approved.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: isReadyForMembership,
                              activeColor: Colors.green,
                              onChanged: (val) {
                                setDialogState(
                                  () => isReadyForMembership = val,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (nameCtrl.text.isEmpty ||
                                  surnameCtrl.text.isEmpty) {
                                Api().showMessage(
                                  context,
                                  "Name and Surname are required.",
                                  "Warning",
                                  Colors.orange,
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              Map<String, dynamic> updatePayload = {
                                "name": nameCtrl.text,
                                "surname": surnameCtrl.text,
                                "phone": phoneCtrl.text,
                                "ready_for_membership": isReadyForMembership,
                              };
                              _updateMemberDetails(
                                userMap['ui_id'],
                                isVisitor,
                                updatePayload,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                "Save Changes",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNeuInput(
    String hint,
    TextEditingController controller, [
    IconData? icon,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NeumorphicContainer(
        color: widget.neumoColor,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey[800],
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            icon: icon != null
                ? Icon(icon, color: _primaryColor, size: 20)
                : null,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showAddVisitingMemberDialog() {
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    String selectedCategory = 'Mother';
    String selectedRole = 'Deacon';
    final List<String> categories = ['Mother', 'Father', 'Brother', 'Sister'];
    final List<String> roles = [
      'None',
      'Deacon',
      'Priest',
      'Community Elder',
      'District Elder',
      'Overseer',
      'Apostle',
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isParent =
                selectedCategory == 'Mother' || selectedCategory == 'Father';

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 400,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.neumoColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-10, -10),
                      blurRadius: 20,
                    ),
                    BoxShadow(
                      color: Colors.grey.shade400,
                      offset: Offset(10, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.person_2_fill,
                            color: _primaryColor,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Add Guest Member",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Register a visiting relative to this community.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 24),

                      Text(
                        "RELATIONSHIP",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 8),
                      NeumorphicContainer(
                        color: widget.neumoColor,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedCategory,
                            items: categories.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      if (isParent) ...[
                        Text(
                          "SPIRITUAL RANK (Optional)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(height: 8),
                        NeumorphicContainer(
                          color: widget.neumoColor,
                          borderRadius: 12,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedRole,
                              items: roles.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey[800],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setDialogState(() => selectedRole = val);
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      Text(
                        "PERSONAL INFO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 12),

                      _buildNeuInput(
                        "First Name",
                        nameCtrl,
                        CupertinoIcons.person_fill,
                      ),
                      _buildNeuInput("Surname", surnameCtrl),
                      _buildNeuInput(
                        "Contact Number",
                        phoneCtrl,
                        CupertinoIcons.phone_fill,
                      ),
                      _buildNeuInput(
                        "Home Address",
                        addressCtrl,
                        CupertinoIcons.map_pin_ellipse,
                      ),

                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          GestureDetector(
                            onTap: () async {
                              if (nameCtrl.text.isEmpty ||
                                  surnameCtrl.text.isEmpty) {
                                Api().showMessage(
                                  context,
                                  "Name and Surname are required.",
                                  "Warning",
                                  Colors.orange,
                                );
                                return;
                              }
                              Navigator.pop(ctx);

                              String deducedGender =
                                  (selectedCategory == 'Mother' ||
                                      selectedCategory == 'Sister')
                                  ? 'Female'
                                  : 'Male';

                              await _submitNewVisitor(
                                nameCtrl.text,
                                surnameCtrl.text,
                                phoneCtrl.text,
                                addressCtrl.text,
                                deducedGender,
                                visitorCategory: selectedCategory,
                                visitorRole: isParent ? selectedRole : null,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                "Save Guest",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddVisitorDialog() {
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String selectedGender = 'Male';

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 400,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.neumoColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-10, -10),
                      blurRadius: 20,
                    ),
                    BoxShadow(
                      color: Colors.grey.shade400,
                      offset: Offset(10, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.person_badge_plus_fill,
                            color: Colors.orange,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Add Testify",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Assign a new testify to ${widget.universityName}.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 24),

                      Text(
                        "PERSONAL INFO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 12),

                      _buildNeuInput(
                        "First Name",
                        nameCtrl,
                        CupertinoIcons.person_fill,
                      ),
                      _buildNeuInput("Surname", surnameCtrl),
                      _buildNeuInput(
                        "Contact Number",
                        phoneCtrl,
                        CupertinoIcons.phone_fill,
                      ),
                      _buildNeuInput(
                        "Home Address",
                        addressCtrl,
                        CupertinoIcons.map_pin_ellipse,
                      ),

                      NeumorphicContainer(
                        color: widget.neumoColor,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedGender,
                            items: ['Male', 'Female'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => selectedGender = val);
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          GestureDetector(
                            onTap: () async {
                              if (nameCtrl.text.isEmpty ||
                                  surnameCtrl.text.isEmpty) {
                                Api().showMessage(
                                  context,
                                  "Name and Surname are required.",
                                  "Warning",
                                  Colors.orange,
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              await _submitNewVisitor(
                                nameCtrl.text,
                                surnameCtrl.text,
                                phoneCtrl.text,
                                addressCtrl.text,
                                selectedGender,
                                visitorCategory: 'Testify',
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                "Save Testify",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitNewVisitor(
    String name,
    String surname,
    String phone,
    String address,
    String gender, {
    String visitorCategory = 'Testify',
    String? visitorRole,
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      String? districtName =
          _districtData?['district_elder_name'] ??
          _districtData?['districtElderName'];

      final payload = {
        "name": name,
        "surname": surname,
        "phone": phone,
        "address": address,
        "gender": gender,
        "community_name": widget.universityName,
        "district_elder_name": districtName,
        "overseer_uid": widget.overseerId,
        "visitor_category": visitorCategory,
        "visitor_role": visitorRole,
      };

      final res = await http.post(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/visitors/'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        Api().showMessage(
          context,
          "$visitorCategory added successfully.",
          "Success",
          Colors.green,
        );
        _fetchSpiritualData();
      } else {
        Api().showMessage(
          context,
          "Failed to add $visitorCategory.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("Add Visitor Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PDF WIDGET GENERATOR FOR DASHBOARD ---
  pw.Widget _buildPDFDashboardWidget() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16, top: 4),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Overall Attendance
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "ATTENDANCE OVERVIEW",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 6),

                pw.SizedBox(height: 4),
                pw.Text(
                  "Total: $totalMembers | Present: $presentMembers | Absent: $absentMembers",
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 40,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),

          // Guests & Testifies
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "GUESTS & TESTIFIES",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  "Total: $totalTestifies",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Ready for Sealing: $readyTestifies",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 40,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),

          // Gender Attendance
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "GENDER ATTENDANCE",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Brothers", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      "$brothersPresent / $brothersTotal",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Sisters", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      "$sistersPresent / $sistersTotal",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.pink700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPickerForReport() {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: widget.neumoColor,
              title: Row(
                children: [
                  Icon(
                    CupertinoIcons.calendar_circle_fill,
                    color: _primaryColor,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Select Month",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (index) => index + 1).map((
                            m,
                          ) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(
                                DateFormat('MMMM').format(DateTime(2024, m)),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setDialogState(() => selectedMonth = val!),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          items:
                              [
                                DateTime.now().year - 1,
                                DateTime.now().year,
                                DateTime.now().year + 1,
                              ].map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    y.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) =>
                              setDialogState(() => selectedYear = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateMonthlyReportPDF(selectedMonth, selectedYear);
                  },
                  child: Text(
                    "Generate Ledger",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateMonthlyReportPDF(int month, int year) async {
    Api().showMessage(
      context,
      "Fetching monthly ledger...",
      "Processing",
      Colors.blue,
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      final res = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=${widget.universityName}&month=$month&year=$year',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to load data: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final int numDays = data['num_days'];
      List<dynamic> members = data['data'];

      // Helpers
      bool isParent(dynamic u) =>
          u['visitor_category'] == 'Mother' ||
          u['visitor_category'] == 'Father';
      bool isMale(dynamic u) =>
          u['gender'] != null && u['gender'].toString().toLowerCase() == 'male';
      bool isFemale(dynamic u) =>
          u['gender'] != null &&
          u['gender'].toString().toLowerCase() == 'female';
      bool isTestify(dynamic u) => u['is_visitor'] == true && !isParent(u);

      // Extract Lists
      final spiritualParents = members.where((u) => isParent(u)).toList();

      final brothersMembers = members
          .where((u) => !isParent(u) && !isTestify(u) && isMale(u))
          .toList();
      final sistersMembers = members
          .where((u) => !isParent(u) && !isTestify(u) && isFemale(u))
          .toList();
      final unassignedMembers = members
          .where(
            (u) => !isParent(u) && !isTestify(u) && !isMale(u) && !isFemale(u),
          )
          .toList();

      final brothersTestifies = members
          .where((u) => isTestify(u) && isMale(u))
          .toList();
      final sistersTestifies = members
          .where((u) => isTestify(u) && isFemale(u))
          .toList();
      final unassignedTestifies = members
          .where((u) => isTestify(u) && !isMale(u) && !isFemale(u))
          .toList();

      // Sort Alphabetically
      void sortList(List<dynamic> list) => list.sort(
        (a, b) => "${a['name']} ${a['surname']}".compareTo(
          "${b['name']} ${b['surname']}",
        ),
      );
      sortList(spiritualParents);
      sortList(brothersMembers);
      sortList(sistersMembers);
      sortList(unassignedMembers);
      sortList(brothersTestifies);
      sortList(sistersTestifies);
      sortList(unassignedTestifies);

      // Assets
      pw.MemoryImage? localLogoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}

      pw.ImageProvider? uniLogoImage;
      if (widget.universityLogoUrl != null &&
          widget.universityLogoUrl!.isNotEmpty) {
        try {
          uniLogoImage = await networkImage(widget.universityLogoUrl!);
        } catch (_) {}
      }

      final pdf = pw.Document();
      final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

      // Build Headers with Date AND Day of the Week
      List<String> tableHeaders = ['Member Names'];
      for (int i = 1; i <= numDays; i++) {
        String weekday = DateFormat('E').format(DateTime(year, month, i));
        tableHeaders.add("$i\n$weekday");
      }
      tableHeaders.addAll(['P', 'A', '%']);

      // Calculate column flex widths
      Map<int, pw.TableColumnWidth> columnWidths = {
        0: const pw.FlexColumnWidth(3.0),
      };
      for (int i = 1; i <= numDays; i++) {
        columnWidths[i] = const pw.FlexColumnWidth(1.1);
      }
      columnWidths[numDays + 1] = const pw.FlexColumnWidth(1.2);
      columnWidths[numDays + 2] = const pw.FlexColumnWidth(1.2);
      columnWidths[numDays + 3] = const pw.FlexColumnWidth(1.2);

      // Extracted helper for rendering table sections
      pw.Widget _buildLedgerSection(
        String title,
        List<dynamic> sectionMembers,
        PdfColor headerColor,
      ) {
        if (sectionMembers.isEmpty) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 8),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: headerColor,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              columnWidths: columnWidths,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: headerColor),
              headerHeight: 24,
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 1.5,
                horizontal: 1.0,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 4.5,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.center,
              headers: tableHeaders,
              data: sectionMembers.map((m) {
                String nameDisplay = "${m['name']} ${m['surname']}";
                bool isPar = isParent(m);
                bool isVis = m['is_visitor'] == true;

                // Smart fallback check for 'ready_for_membership' if backend doesn't supply it
                bool isReady =
                    m['ready_for_membership'] == true ||
                    m['ready_for_membership'] == 'true';
                if (!isReady) {
                  try {
                    final match = _usersList.firstWhere(
                      (u) =>
                          u['name'] == m['name'] &&
                          u['surname'] == m['surname'],
                    );
                    isReady =
                        match['ready_for_membership'] == true ||
                        match['ready_for_membership'] == 'true';
                  } catch (_) {}
                }

                if (isPar) {
                  String role =
                      m['visitor_role'] != null && m['visitor_role'] != 'None'
                      ? " - ${m['visitor_role']}"
                      : "";
                  nameDisplay += "\n[${m['visitor_category']}$role]";
                }

                List<pw.InlineSpan> spans = [
                  pw.TextSpan(
                    text: nameDisplay,
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: isPar
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: isPar ? PdfColors.purple800 : PdfColors.black,
                    ),
                  ),
                ];

                if (isVis && !isPar) {
                  if (isReady) {
                    spans.add(
                      pw.TextSpan(
                        text: "\n(Awaiting Sealing)",
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    );
                  } else {
                    spans.add(
                      pw.TextSpan(
                        text: "\nTestify",
                        style: const pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.black,
                        ),
                      ),
                    );
                  }
                }

                List<dynamic> rowData = [];
                rowData.add(
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.RichText(text: pw.TextSpan(children: spans)),
                  ),
                );

                Map<String, dynamic> attendance = m['attendance'];
                for (int day = 1; day <= numDays; day++) {
                  bool isPresent = attendance[day.toString()] ?? false;
                  rowData.add(
                    pw.Text(
                      isPresent ? "P" : "A",
                      style: pw.TextStyle(
                        color: isPresent
                            ? PdfColors.green700
                            : PdfColors.red700,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 6,
                      ),
                    ),
                  );
                }

                rowData.add(
                  pw.Text(
                    m['total_present'].toString(),
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                );
                rowData.add(
                  pw.Text(
                    m['total_absent'].toString(),
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                );
                rowData.add(
                  pw.Text(
                    "${m['percentage']}%",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 6,
                    ),
                  ),
                );

                return rowData;
              }).toList(),
            ),
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (localLogoImage != null)
                    pw.Image(localLogoImage, width: 45, height: 45),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "TTACTSO ${widget.universityName.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "MONTHLY ATTENDANCE LEDGER: ${monthName.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      // EXPLICIT KEY
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            "KEY: ",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "P = PRESENT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.green700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "   |   ",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey500,
                            ),
                          ),
                          pw.Text(
                            "A = ABSENT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (uniLogoImage != null)
                    pw.Image(uniLogoImage, width: 45, height: 45)
                  else
                    pw.SizedBox(width: 45),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 6),

              // Sub-header details
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "OVERSEER: ${_overseerData?['overseer_initials_surname'] ?? 'Unassigned'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "DISTRICT: ${_districtData?['district_elder_name'] ?? 'Unassigned'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "RECORDER: ${widget.loggedMemberName ?? 'Unknown'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "DESIGNATION: ${widget.loggedMemberRole ?? 'Authorized Officer'}",
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Clarification row before the table headers
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(
                  "DAYS OF THE MONTH: ${monthName.toUpperCase()}",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),

              _buildPDFDashboardWidget(),

              // CATEGORIZED TABLES
              _buildLedgerSection(
                "SPIRITUAL PARENTS (MOTHERS & FATHERS)",
                spiritualParents,
                PdfColors.purple800,
              ),

              _buildLedgerSection(
                "BROTHERS (MEMBERS)",
                brothersMembers,
                PdfColors.blue800,
              ),
              _buildLedgerSection(
                "SISTERS (MEMBERS)",
                sistersMembers,
                PdfColors.pink700,
              ),
              _buildLedgerSection(
                "MEMBERS (GENDER UNSPECIFIED)",
                unassignedMembers,
                PdfColors.blueGrey600,
              ),

              _buildLedgerSection(
                "BROTHERS (TESTIFIES)",
                brothersTestifies,
                PdfColors.lightBlue700,
              ),
              _buildLedgerSection(
                "SISTERS (TESTIFIES)",
                sistersTestifies,
                PdfColors.pink400,
              ),
              _buildLedgerSection(
                "TESTIFIES (GENDER UNSPECIFIED)",
                unassignedTestifies,
                PdfColors.grey600,
              ),

              pw.SizedBox(height: 20),
              pw.Text(
                "Report Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final String fileName =
          'MONTHLY_${widget.universityName}_$year\_$month.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint(e.toString());
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  Future<void> _exportRegisterToPDF(String filterType) async {
    bool isParent(dynamic u) =>
        u['visitor_category'] == 'Mother' || u['visitor_category'] == 'Father';
    bool isMale(dynamic g) => g != null && g.toString().toLowerCase() == 'male';
    bool isFemale(dynamic g) =>
        g != null && g.toString().toLowerCase() == 'female';

    List<dynamic> targetList;
    String reportStatusLabel = "All Members";

    if (filterType == 'BrothersAndParents') {
      targetList = _usersList
          .where((u) => isParent(u) || isMale(u['gender']))
          .toList();
      reportStatusLabel = "Brothers & Spiritual Parents";
    } else if (filterType == 'SistersAndParents') {
      targetList = _usersList
          .where((u) => isParent(u) || isFemale(u['gender']))
          .toList();
      reportStatusLabel = "Sisters & Spiritual Parents";
    } else {
      targetList = _usersList;
      reportStatusLabel = "All Members";
    }

    if (targetList.isEmpty) {
      Api().showMessage(
        context,
        "No members found in this category.",
        "Empty Register",
        Colors.orange,
      );
      return;
    }

    final spiritualParents = targetList.where((u) => isParent(u)).toList();

    final regularMembers = targetList
        .where((u) => !isParent(u) && u['isVisitor'] == false)
        .toList();
    final maleMembers = regularMembers
        .where((u) => isMale(u['gender']))
        .toList();
    final femaleMembers = regularMembers
        .where((u) => isFemale(u['gender']))
        .toList();
    final unassignedMembers = regularMembers
        .where((u) => !isMale(u['gender']) && !isFemale(u['gender']))
        .toList();

    final regularVisitors = targetList
        .where((u) => !isParent(u) && u['isVisitor'] == true)
        .toList();
    final maleTestifies = regularVisitors
        .where((u) => isMale(u['gender']))
        .toList();
    final femaleTestifies = regularVisitors
        .where((u) => isFemale(u['gender']))
        .toList();
    final unassignedTestifies = regularVisitors
        .where((u) => !isMale(u['gender']) && !isFemale(u['gender']))
        .toList();

    pw.MemoryImage? localLogoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Local logo error: $e");
    }

    pw.ImageProvider? uniLogoImage;
    if (widget.universityLogoUrl != null &&
        widget.universityLogoUrl!.isNotEmpty) {
      try {
        uniLogoImage = await networkImage(widget.universityLogoUrl!);
      } catch (e) {}
    }

    final pdf = pw.Document();
    final String fullDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(DateTime.now());
    final String timestamp = DateFormat('HH:mm').format(DateTime.now());
    final recordedBy = widget.loggedMemberName ?? 'Unknown User';
    final recorderRole = widget.loggedMemberRole ?? 'Authorized Officer';

    pw.Widget _buildCategoryTable(
      String title,
      List<dynamic> data,
      PdfColor headerColor,
    ) {
      if (data.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: headerColor,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: pw.BoxDecoration(color: headerColor),
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 2,
              horizontal: 4,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: [
              'First Name',
              'Last Name & Rank',
              'Contact No.',
              'Status',
            ],
            data: data.map((user) {
              String lastNameDisplay = user['surname'] ?? 'N/A';
              bool isVis = user['isVisitor'] == true;
              bool isReady =
                  user['ready_for_membership'] == true ||
                  user['ready_for_membership'] == 'true';

              if (isParent(user)) {
                String role = user['visitor_role'] ?? '';
                String cat = user['visitor_category'] ?? '';
                if (role.isNotEmpty && role != 'None') {
                  lastNameDisplay += ' ($cat - $role)';
                } else {
                  lastNameDisplay += ' ($cat)';
                }
              }

              pw.Widget lastNameWidget;
              if (isVis && !isParent(user)) {
                if (isReady) {
                  lastNameWidget = pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: lastNameDisplay,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.TextSpan(
                          text: '\n(Awaiting Sealing)',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  lastNameWidget = pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: lastNameDisplay,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.TextSpan(
                          text: '\n(Testify)',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                lastNameWidget = pw.Text(
                  lastNameDisplay,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.black,
                  ),
                );
              }

              return [
                user['name'] ?? 'N/A',
                lastNameWidget,
                user['phone'] ?? 'N/A',
                (user['isPresent'] == true) ? 'PRESENT' : 'ABSENT',
              ];
            }).toList(),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (localLogoImage != null)
                  pw.Image(localLogoImage, width: 45, height: 45),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "TTACTSO ${widget.universityName.toUpperCase()}",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "OFFICIAL ATTENDANCE REGISTER",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                ),
                if (uniLogoImage != null)
                  pw.Image(uniLogoImage, width: 45, height: 45)
                else
                  pw.SizedBox(width: 45),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 6),

            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "REPORT STATUS: $reportStatusLabel",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "GENERATED ON: $fullDate at $timestamp",
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "RECORDER: $recordedBy",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "DESIGNATION: $recorderRole",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildPDFDashboardWidget(),

            _buildCategoryTable(
              "SPIRITUAL PARENTS (MOTHERS & FATHERS)",
              spiritualParents,
              PdfColors.purple800,
            ),

            _buildCategoryTable(
              "BROTHERS (MEMBERS)",
              maleMembers,
              PdfColors.blue800,
            ),
            _buildCategoryTable(
              "SISTERS (MEMBERS)",
              femaleMembers,
              PdfColors.pink700,
            ),
            _buildCategoryTable(
              "MEMBERS (GENDER UNSPECIFIED)",
              unassignedMembers,
              PdfColors.blueGrey600,
            ),

            _buildCategoryTable(
              "BROTHERS (TESTIFIES)",
              maleTestifies,
              PdfColors.lightBlue600,
            ),
            _buildCategoryTable(
              "SISTERS (TESTIFIES)",
              femaleTestifies,
              PdfColors.pink400,
            ),
            _buildCategoryTable(
              "TESTIFIES (GENDER UNSPECIFIED)",
              unassignedTestifies,
              PdfColors.grey600,
            ),

            pw.SizedBox(height: 20),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 120,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1)),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Official Branch Signature",
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    try {
      final Uint8List bytes = await pdf.save();
      final String fileName =
          'REGISTER_${widget.universityName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'testifyBtn',
            onPressed: _showAddVisitorDialog,
            backgroundColor: Colors.orange,
            icon: Icon(
              CupertinoIcons.person_badge_plus,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              "Add Testify",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'guestBtn',
            onPressed: _showAddVisitingMemberDialog,
            backgroundColor: _primaryColor,
            icon: Icon(
              CupertinoIcons.person_3_fill,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              "Add Guest Member",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        "Spiritual Leadership",
                        CupertinoIcons.person_3_fill,
                      ),
                      const SizedBox(height: 16),
                      _buildResponsiveLeadershipCards(constraints.maxWidth),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        "Attendance Overview",
                        CupertinoIcons.chart_pie_fill,
                      ),
                      const SizedBox(height: 16),
                      _buildDashboardChart(),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildSectionHeader(
                              "Digital Register",
                              CupertinoIcons.list_bullet,
                            ),
                          ),
                          _buildDownloadMenu(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 24),

                      _filteredUsers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? "No members registered."
                                      : "No matching results.",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          : _buildPaginatedTable(),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: Colors.blueGrey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'Monthly') {
          _showMonthPickerForReport();
        } else {
          _exportRegisterToPDF(value);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              "PDF EXPORT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'All',
          child: Text(
            'Export Daily Register (All)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuItem(
          value: 'BrothersAndParents',
          child: Text(
            'Daily: Brothers & Parents',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuItem(
          value: 'SistersAndParents',
          child: Text(
            'Daily: Sisters & Parents',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'Monthly',
          child: Row(
            children: [
              Icon(CupertinoIcons.calendar, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Export Monthly Ledger',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.blueGrey[900],
        ),
        decoration: InputDecoration(
          icon: Icon(CupertinoIcons.search, color: _primaryColor),
          hintText: "Search members & visitors...",
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLeadershipCards(double maxWidth) {
    bool isWide = maxWidth > 600;
    return Flex(
      direction: isWide ? Axis.horizontal : Axis.vertical,
      children: [
        Expanded(
          flex: isWide ? 1 : 0,
          child: _buildLeadershipCard(
            "Lead Overseer",
            _overseerData?['overseer_initials_surname'] ?? 'Unassigned',
            CupertinoIcons.person_crop_circle_fill_badge_checkmark,
          ),
        ),
        SizedBox(height: isWide ? 0 : 16, width: isWide ? 16 : 0),
        Expanded(
          flex: isWide ? 1 : 0,
          child: _buildLeadershipCard(
            "District Elder",
            _districtData?['district_elder_name'] ?? 'Unassigned',
            CupertinoIcons.building_2_fill,
          ),
        ),
      ],
    );
  }

  Widget _buildLeadershipCard(String title, String name, IconData icon) {
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Icon(icon, color: _primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardChart() {
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          // TOP SECTION: Overall Attendance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      color: Colors.grey.shade200,
                    ),
                    CircularProgressIndicator(
                      value: attendancePercentage,
                      strokeWidth: 12,
                      color: _primaryColor,
                      backgroundColor: Colors.transparent,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(attendancePercentage * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          Text(
                            "Present",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 100, width: 1, color: Colors.grey.shade300),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatRow(
                    "Total",
                    totalMembers.toString(),
                    Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    "Present",
                    presentMembers.toString(),
                    _primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    "Absent",
                    absentMembers.toString(),
                    Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 20),

          // BOTTOM SECTION: Details & Comparisons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GUESTS & TESTIFIES",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      "Total",
                      totalTestifies.toString(),
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      "Ready for Sealing",
                      readyTestifies.toString(),
                      Colors.green,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 70, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GENDER ATTENDANCE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildGenderBar(
                      "Brothers",
                      brothersPresent,
                      brothersTotal,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildGenderBar(
                      "Sisters",
                      sistersPresent,
                      sistersTotal,
                      Colors.pink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.blueGrey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderBar(String label, int present, int total, Color color) {
    double pct = total == 0 ? 0.0 : present / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            Text(
              "$present / $total",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPaginatedTable() {
    int totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0)
      _currentPage = totalPages - 1;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = (startIndex + _rowsPerPage > _filteredUsers.length)
        ? _filteredUsers.length
        : startIndex + _rowsPerPage;

    List<dynamic> paginatedData = _filteredUsers.sublist(startIndex, endIndex);

    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 20,
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("MEMBER INFO", style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 2,
                  child: Text("CONTACT", style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("ATTENDANCE", style: _tableHeaderStyle()),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text("ACTION", style: _tableHeaderStyle()),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedData.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              return _buildTableRow(paginatedData[index]);
            },
          ),

          // Pagination Footer
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Showing ${startIndex + 1} - $endIndex of ${_filteredUsers.length}",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.chevron_left_circle_fill,
                          color: _currentPage > 0
                              ? _primaryColor
                              : Colors.grey.shade300,
                        ),
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      Text(
                        "Page ${_currentPage + 1} of $totalPages",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.chevron_right_circle_fill,
                          color: _currentPage < totalPages - 1
                              ? _primaryColor
                              : Colors.grey.shade300,
                        ),
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Colors.grey.shade500,
      letterSpacing: 1.0,
    );
  }

  Widget _buildTableRow(Map<String, dynamic> user) {
    final fullName = "${user['name'] ?? ''} ${user['surname'] ?? ''}".trim();
    final isPresent = user['isPresent'] ?? false;
    final isVisitor = user['isVisitor'] ?? false;
    final visitorCategory = user['visitor_category'] ?? 'Testify';
    final visitorRole = user['visitor_role'];
    final isReady =
        user['ready_for_membership'] == true ||
        user['ready_for_membership'] == 'true';

    String tagLabel = "";
    Color tagColor = Colors.transparent;
    bool isParent = visitorCategory == 'Mother' || visitorCategory == 'Father';

    // The core logic requested: only visitors who are NOT parents get the edit icon.
    bool canEdit = isVisitor && !isParent;

    if (isParent) {
      tagLabel = visitorRole != null && visitorRole != 'None'
          ? "${visitorCategory.toUpperCase()} - ${visitorRole.toUpperCase()}"
          : visitorCategory.toUpperCase();
      tagColor = Colors.purple;
    } else if (visitorCategory == 'Brother' || visitorCategory == 'Sister') {
      tagLabel = visitorCategory.toUpperCase();
      tagColor = Colors.teal;
    } else if (isVisitor) {
      tagLabel = "VISITOR";
      tagColor = Colors.orange;
    }

    BoxDecoration rowDecoration = BoxDecoration(color: Colors.transparent);
    if (isParent) {
      rowDecoration = BoxDecoration(
        color: Colors.purple.withOpacity(0.04),
        border: Border(
          left: BorderSide(color: Colors.purple.shade300, width: 4),
        ),
      );
    }

    return Container(
      decoration: rowDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Member Info (Flex 3)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: isParent
                        ? Colors.purple.withOpacity(0.15)
                        : (isVisitor
                              ? Colors.orange.withOpacity(0.1)
                              : _primaryColor.withOpacity(0.1)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isParent
                          ? Colors.purple.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: isParent
                        ? Icon(
                            CupertinoIcons.star_fill,
                            color: Colors.purple,
                            size: 18,
                          )
                        : Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              color: isVisitor ? Colors.orange : _primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blueGrey[900],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Visual Badge if they met the Priest
                          if (isVisitor && isReady) ...[
                            SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: Colors.green,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      if (tagLabel.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tagLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contact (Flex 2)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.phone_fill,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user['phone'] ?? user['email'] ?? 'N/A',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Attendance Switch (Flex 1)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isPresent ? "PRESENT" : "ABSENT",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isPresent
                        ? _primaryColor
                        : Colors.redAccent.shade200,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: Transform.scale(
                    scale: 0.8,
                    alignment: Alignment.center,
                    child: CupertinoSwitch(
                      value: isPresent,
                      activeColor: _primaryColor,
                      trackColor: Colors.grey.shade300,
                      onChanged: (val) =>
                          _toggleUserAttendance(user['ui_id'], val, isVisitor),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Column (Flex 1) - ONLY for eligible visitors
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: canEdit
                  ? IconButton(
                      icon: Icon(
                        CupertinoIcons.pencil_ellipsis_rectangle,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      onPressed: () => _showEditMemberDialog(user, isVisitor),
                      tooltip: "Update Record",
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
