// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart'; // 🔥 ADDED FOR QR SCANNER
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/tactso_pages/components/dialogs.dart';
import 'package:ttact/Pages/tactso_pages/components/full_attendance_reports.dart';
import 'package:ttact/Pages/tactso_pages/components/spiritual_pdf_generated.dart';
import 'package:ttact/Pages/tactso_pages/components/utilis.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  // Date filter state
  DateTime _selectedDate = DateTime.now();

  // Tracks which user's attendance is being saved (to show loading spinner)
  Set<String> _savingUserIds = {};

  Color get _primaryColor => Theme.of(context).primaryColor;

  bool get _isEditableDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return !selected.isBefore(today);
  }

  int get totalMembers => _usersList.length;
  int get presentMembers =>
      _usersList.where((u) => u['isPresent'] == true).length;
  int get absentMembers => totalMembers - presentMembers;
  double get attendancePercentage =>
      totalMembers == 0 ? 0.0 : presentMembers / totalMembers;

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

  // ----------------- DATA FETCHING -----------------
  Future<void> _fetchSpiritualData() async {
    setState(() => _isLoading = true);

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

      // Fetch members
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
          map['uid'] = map['uid'];
          map['isPresent'] = false;
          return map;
        }).toList();
      }

      // Fetch visitors
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
          map['uid'] = map['id'];
          map['isPresent'] = false;
          return map;
        }).toList();
      }

      _usersList = [...members, ...visitors];

      // Fetch attendance for selected date
      await _fetchAttendanceForSelectedDate(token);
    } catch (e) {
      debugPrint("Error fetching spiritual data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendanceForSelectedDate(String token) async {
    try {
      // Reset all to absent first
      for (var u in _usersList) {
        u['isPresent'] = false;
      }

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=${widget.universityName}&month=${_selectedDate.month}&year=${_selectedDate.year}',
      );
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        List data = decoded['data'] ?? [];
        for (var item in data) {
          String uiId = item['uid'].toString();
          Map<String, dynamic> attMap = item['attendance'] ?? {};
          bool isPresentOnDay = attMap[_selectedDate.day.toString()] == true;

          int idx = _usersList.indexWhere((u) => u['uid'].toString() == uiId);
          if (idx != -1) {
            _usersList[idx]['isPresent'] = isPresentOnDay;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching daily attendance: $e");
    }
  }

  Future<void> _onDateChanged(DateTime newDate) async {
    setState(() {
      _selectedDate = newDate;
      _isLoading = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    String token = user != null ? await user.getIdToken() ?? "" : "";
    await _fetchAttendanceForSelectedDate(token);
    if (mounted) setState(() => _isLoading = false);
  }

  // ----------------- ATTENDANCE TOGGLE (with revert on error) -----------------
  Future<void> _toggleUserAttendance(
    String uiId,
    bool newValue,
    bool isVisitor,
  ) async {
    if (!_isEditableDay) return;

    // Store previous state in case the API call fails
    final index = _usersList.indexWhere((u) => u['uid'] == uiId);
    if (index == -1) return;
    final bool oldValue = _usersList[index]['isPresent'] ?? false;

    // Optimistically update UI
    setState(() {
      _usersList[index]['isPresent'] = newValue;
      _savingUserIds.add(uiId); // show loading spinner
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";
      final endpoint = isVisitor ? '/visitors/$uiId/' : '/users/$uiId/';

      String formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final response = await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'attendance_status': newValue ? 'Present' : 'Absent',
          'date': formattedDate,
        }),
      );

      if (response.statusCode >= 400) {
        // API error – revert the switch
        setState(() {
          _usersList[index]['isPresent'] = oldValue;
        });
        Api().showMessage(
          context,
          "Failed to update attendance. Please try again.",
          "Error",
          Colors.red,
        );
      } else {
        // Success – keep the new state
        // (no extra action needed)
      }
    } catch (e) {
      // Network / other error – revert
      setState(() {
        _usersList[index]['isPresent'] = oldValue;
      });
      debugPrint("Error saving attendance: $e");
      Api().showMessage(
        context,
        "Network error. Please check your connection.",
        "Error",
        Colors.red,
      );
    } finally {
      setState(() {
        _savingUserIds.remove(uiId);
      });
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
        await _fetchSpiritualData();
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


  // ----------------- NEW: EXPORT MEMBER LIST -----------------
  void _exportMemberList(bool includeSignature) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() ?? "" : "";

    // Fetch overseer signature (optional footer)
    Uint8List? signatureBytes;
    if (widget.overseerId != null) {
      try {
        final res = await http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/overseers/${widget.overseerId}/',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final sigStr = data['signature_base64'];
          if (sigStr != null && sigStr.isNotEmpty) {
            signatureBytes = base64Decode(sigStr);
          }
        }
      } catch (e) {
        print("Error fetching signature: $e");
      }
    }

    // Load logo from assets
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/tact_logo.PNG');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    SpiritualPdfGenerator.exportMemberListPDF(
      context: context,
      members: _filteredUsers,
      includeSignature: includeSignature,
      universityName: widget.universityName,
      universityLogoUrl: widget.universityLogoUrl,
      loggedMemberName: widget.loggedMemberName ?? 'Authorized Officer',
      loggedMemberRole: widget.loggedMemberRole ?? '',
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );
  }
  // -----------------------------------------------------------

  // ----------------- UI BUILD -----------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isEditableDay
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'testifyBtn',
                  onPressed: () => showAddVisitorDialog(
                    context,
                    widget.universityName,
                    widget.neumoColor,
                    _primaryColor,
                    _submitNewVisitor,
                  ),
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
                  onPressed: () => showAddVisitingMemberDialog(
                    context,
                    widget.neumoColor,
                    _primaryColor,
                    _submitNewVisitor,
                  ),
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
            )
          : const SizedBox.shrink(),
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
                      buildSectionHeader(
                        "Spiritual Leadership",
                        CupertinoIcons.person_3_fill,
                        _primaryColor,
                      ),
                      const SizedBox(height: 16),
                      buildResponsiveLeadershipCards(
                        constraints.maxWidth,
                        widget.neumoColor,
                        _primaryColor,
                        _overseerData,
                        _districtData,
                      ),
                      const SizedBox(height: 32),

                      // --- 🔥 SINGLE COMMUNITY FILTER (Matches Overseer Layout) ---
                      _buildSingleCommunityFilters(),
                      const SizedBox(height: 16),

                      if (!_isEditableDay)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.lock_fill,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Archived Record (Read-Only): You are viewing attendance for a past date. Changes are locked.",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildSectionHeader(
                            "Attendance Overview",
                            CupertinoIcons.chart_pie_fill,
                            _primaryColor,
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullAttendanceReports(
                                    usersList: _usersList,
                                    universityName: widget.universityName,
                                    neumoColor: widget.neumoColor,
                                    primaryColor: _primaryColor,
                                    selectedDate: _selectedDate,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              CupertinoIcons.graph_square,
                              color: _primaryColor,
                            ),
                            label: Text(
                              "View Full",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDashboardChart(constraints.maxWidth),
                      const SizedBox(height: 32),

                      // --- 🔥 DIGITAL REGISTER HEADER WITH QR SCANNER ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: buildSectionHeader(
                              "Register",
                              CupertinoIcons.list_bullet,
                              _primaryColor,
                            ),
                          ),
                          _buildQrScanButton(), // QR SCANNER
                          SizedBox(width: 10),
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
                          : _buildPaginatedTable(), // Now matches Overseer styling exactly
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

  // --- 🔥 SINGLE COMMUNITY FILTERS (Matches Overseer 3-col layout) ---
  Widget _buildSingleCommunityFilters() {
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Picker
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Community Name (Static)
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  widget.universityName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey[800],
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Status (Static)
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  "Active Branch",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      _onDateChanged(picked);
    }
  }

  // ----------------- QR SCANNER FEATURES -----------------
  // QR SCANNER BUTTON WIDGET
  Widget _buildQrScanButton() {
    return GestureDetector(
      onTap: _openQRScanner,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.purple,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              "SCAN QR",
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
    );
  }

  // QR SCANNER LOGIC
  void _openQRScanner() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 300,
              height: 300,
              child: MobileScanner(
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.noDuplicates,
                  facing: CameraFacing.back,
                ),
                onDetect: (capture) async {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null) {
                      _processScannedQR(code);
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // LOGIC TO PROCESS SCANNED QR DATA
  void _processScannedQR(String code) async {
    final userIndex = _usersList.indexWhere(
      (u) => u['uid']?.toString() == code,
    );
    if (userIndex == -1) {
      if (mounted) {
        Api().showMessage(
          context,
          "User with this ID not found in the register.",
          "Not Found",
          Colors.orange,
        );
      }
      return;
    }

    final user = _usersList[userIndex];
    final bool isVisitor = user['isVisitor'] ?? false;
    final bool isPresent = user['isPresent'] ?? false;

    if (isPresent) {
      if (mounted) {
        Api().showMessage(
          context,
          "${user['name'] ?? 'User'} is already marked present.",
          "Already Scanned",
          Colors.yellow,
        );
      }
    } else {
      _toggleUserAttendance(user['uid'], true, isVisitor);
      if (mounted) {
        Api().showMessage(
          context,
          "${user['name'] ?? 'User'} marked present successfully!",
          "Checked In",
          Colors.green,
        );
      }
    }
  }

  // ----------------- DOWNLOAD MENU -----------------
  Widget _buildDownloadMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'Monthly') {
          showMonthPickerForReport(context, widget.neumoColor, _primaryColor, (
            month,
            year,
          ) {
            showSignatureDialog(context, widget.neumoColor, _primaryColor, (
              signatureBytes,
            ) {
              SpiritualPdfGenerator.generateMonthlyReportPDF(
                context: context,
                universityName: widget.universityName,
                month: month,
                year: year,
                universityLogoUrl: widget.universityLogoUrl,
                loggedMemberName: widget.loggedMemberName,
                loggedMemberRole: widget.loggedMemberRole,
                overseerData: _overseerData,
                districtData: _districtData,
                usersList: _usersList,
                totalMembers: totalMembers,
                presentMembers: presentMembers,
                absentMembers: absentMembers,
                totalTestifies: totalTestifies,
                readyTestifies: readyTestifies,
                brothersPresent: brothersPresent,
                brothersTotal: brothersTotal,
                sistersPresent: sistersPresent,
                sistersTotal: sistersTotal,
                signatureBytes: signatureBytes,
              );
            });
          });
        } else if (value == 'MemberList') {
          // NEW: Show dialog with signature toggle
          bool includeSignature = false;
          await showDialog(
            context: context,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          CupertinoIcons.person_2_fill,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 10),
                        const Text('Export Member List'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'This will export the current filtered members list as a PDF.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Include Signature Column',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            CupertinoSwitch(
                              value: includeSignature,
                              activeColor: _primaryColor,
                              onChanged: (val) {
                                setState(() => includeSignature = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(CupertinoIcons.doc_text_fill),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _exportMemberList(includeSignature);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        } else {
          showSignatureDialog(context, widget.neumoColor, _primaryColor, (
            signatureBytes,
          ) {
            SpiritualPdfGenerator.exportRegisterToPDF(
              context: context,
              filterType: value,
              universityName: widget.universityName,
              universityLogoUrl: widget.universityLogoUrl,
              loggedMemberName: widget.loggedMemberName,
              loggedMemberRole: widget.loggedMemberRole,
              usersList: _usersList,
              totalMembers: totalMembers,
              presentMembers: presentMembers,
              absentMembers: absentMembers,
              totalTestifies: totalTestifies,
              readyTestifies: readyTestifies,
              brothersPresent: brothersPresent,
              brothersTotal: brothersTotal,
              sistersPresent: sistersPresent,
              sistersTotal: sistersTotal,
              signatureBytes: signatureBytes,
            );
          });
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
        const PopupMenuDivider(),
        // NEW: Member List option
        const PopupMenuItem(
          value: 'MemberList',
          child: Row(
            children: [
              Icon(CupertinoIcons.list_bullet, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Export Member List',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
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

  Widget _buildDashboardChart(double screenWidth) {
    final double circleSize = screenWidth < 400 ? 100 : 120;
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: circleSize,
                width: circleSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: circleSize * 0.1,
                      color: Colors.grey.shade200,
                    ),
                    CircularProgressIndicator(
                      value: attendancePercentage,
                      strokeWidth: circleSize * 0.1,
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
                              fontSize: circleSize * 0.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          Text(
                            "Present",
                            style: TextStyle(
                              fontSize: circleSize * 0.09,
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
                  buildStatRow(
                    "Total",
                    totalMembers.toString(),
                    Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  buildStatRow(
                    "Present",
                    presentMembers.toString(),
                    _primaryColor,
                  ),
                  const SizedBox(height: 16),
                  buildStatRow(
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
                    buildStatRow(
                      "Total",
                      totalTestifies.toString(),
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    buildStatRow(
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
                    buildGenderBar(
                      "Brothers",
                      brothersPresent,
                      brothersTotal,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    buildGenderBar(
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

  // --- 🔥 PAGINATED TABLE (Matches Overseer Flex Layout exactly) ---
  Widget _buildPaginatedTable() {
    int totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

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
                  flex: 4,
                  child: Text("MEMBER INFO", style: _tableHeaderStyle()),
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedData.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            itemBuilder: (_, index) => _buildTableRow(paginatedData[index]),
          ),
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

  // --- 🔥 TABLE ROW (Matches Overseer Row Code completely) ---
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

    final bool isSaving = _savingUserIds.contains(user['uid']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isEditableDay
            ? () => _toggleUserAttendance(user['uid'], !isPresent, isVisitor)
            : null,
        splashColor: _primaryColor.withOpacity(0.1),
        highlightColor: _primaryColor.withOpacity(0.05),
        child: Container(
          decoration: rowDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // MEMBER INFO (flex 4)
              Expanded(
                flex: 4,
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
                                  color: isVisitor
                                      ? Colors.orange
                                      : _primaryColor,
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
                                  color: tagColor == Colors.white
                                      ? Colors.black
                                      : Colors.white,
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
              // ATTENDANCE (flex 1)
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
                    SizedBox(height: 4),
                    if (isSaving)
                      SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      )
                    else
                      SizedBox(
                        height: 20,
                        child: Transform.scale(
                          scale: 0.8,
                          alignment: Alignment.center,
                          child: CupertinoSwitch(
                            value: isPresent,
                            activeColor: _primaryColor,
                            trackColor: Colors.grey.shade300,
                            onChanged: _isEditableDay
                                ? (val) => _toggleUserAttendance(
                                    user['uid'],
                                    val,
                                    isVisitor,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ACTION (flex 1)
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
                          onPressed: () {
                            showEditMemberDialog(
                              context,
                              user,
                              isVisitor,
                              widget.neumoColor,
                              _primaryColor,
                              _updateMemberDetails,
                            );
                          },
                          tooltip: "Update Record",
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
