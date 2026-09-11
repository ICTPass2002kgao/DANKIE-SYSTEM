// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Overseer/components/overseer_dialog.dart';
import 'package:ttact/Pages/Overseer/components/overseer_reports_full_page.dart';
import 'package:ttact/Pages/Overseer/components/overseer_utilities.dart';
import 'package:ttact/Pages/Overseer/components/pdf_generator_register.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class OverseerDigitalRegisterTab extends StatefulWidget {
  final String? loggerName;
  final String? loggerRole;
  final Color neumoColor;
  final String? regionName;
  final String? organizationLogoUrl;
  final String? faceUrl;
  final bool isLargeScreen;

  const OverseerDigitalRegisterTab({
    Key? key,
    required this.neumoColor,
    this.regionName,
    this.organizationLogoUrl,
    required this.loggerName,
    required this.loggerRole,
    required this.isLargeScreen,
    this.faceUrl,
  }) : super(key: key);

  @override
  State<OverseerDigitalRegisterTab> createState() =>
      _OverseerDigitalRegisterTabState();
}

class _OverseerDigitalRegisterTabState
    extends State<OverseerDigitalRegisterTab> {
  bool _isLoading = true;
  List<dynamic> _usersList = [];
  Map<String, List<String>> _officialHierarchy = {};
  Map<String, dynamic>? _overseerData;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Filters & Date States
  DateTime _selectedDate = DateTime.now();
  String _selectedDistrict = 'All';
  String _selectedCommunity = 'All';

  // NEW: Branch selector – choose a specific community or All
  String _selectedBranch = 'All';

  int _currentPage = 0;
  final int _rowsPerPage = 50;

  // Debouncer map for attendance toggles
  final Map<String, Timer> _toggleDebouncers = {};

  Color get _primaryColor => Theme.of(context).primaryColor;

  bool get _isEditableDay => true;

  // Stats now use _filteredUsers
  int get totalMembers => _filteredUsers.length;
  int get presentMembers =>
      _filteredUsers.where((u) => u['isPresent'] == true).length;
  int get absentMembers => totalMembers - presentMembers;
  double get attendancePercentage =>
      totalMembers == 0 ? 0.0 : presentMembers / totalMembers;

  int get totalTestifies => _filteredUsers
      .where(
        (u) =>
            (u['isVisitor'] == true || u['is_visitor'] == true) &&
            u['visitor_category'] != 'Mother' &&
            u['visitor_category'] != 'Father',
      )
      .length;

  int get readyTestifies => _filteredUsers
      .where(
        (u) =>
            (u['isVisitor'] == true || u['is_visitor'] == true) &&
            u['visitor_category'] != 'Mother' &&
            u['visitor_category'] != 'Father' &&
            (u['ready_for_membership'] == true ||
                u['ready_for_membership'] == 'true'),
      )
      .length;

  int get brothersTotal => _filteredUsers
      .where((u) => u['gender']?.toString().toLowerCase() == 'male')
      .length;
  int get brothersPresent => _filteredUsers
      .where(
        (u) =>
            u['isPresent'] == true &&
            u['gender']?.toString().toLowerCase() == 'male',
      )
      .length;

  int get sistersTotal => _filteredUsers
      .where((u) => u['gender']?.toString().toLowerCase() == 'female')
      .length;
  int get sistersPresent => _filteredUsers
      .where(
        (u) =>
            u['isPresent'] == true &&
            u['gender']?.toString().toLowerCase() == 'female',
      )
      .length;

  // --- PRIORITY ORDER FOR SPIRITUAL PARENTS ---
  final List<String> _spiritualRoleOrder = [
    'Apostle',
    'Overseer',
    'District Elder',
    'Community Elder',
    'Priest',
    'Deacon',
  ];

  // --- ROLE TO COLOR MAPPING ---
  final Map<String, Color> _roleTagColors = {
    'Apostle': Colors.blue,
    'Overseer': Colors.white,
    'District Elder': const Color(0xFF800000),
    'Community Elder': Colors.red,
    'Priest': Colors.green,
    'Deacon': Colors.yellow,
  };

  int _getParentPriority(Map<String, dynamic> user) {
    final String category = user['visitor_category'] ?? '';
    final String role = user['visitor_role'] ?? 'None';
    if (category != 'Mother' && category != 'Father') return 999;
    for (int i = 0; i < _spiritualRoleOrder.length; i++) {
      if (role.contains(_spiritualRoleOrder[i])) return i;
    }
    return _spiritualRoleOrder.length;
  }

  List<dynamic> get _filteredUsers {
    List<dynamic> baseList = _usersList;

    // NEW: Branch filter (community)
    if (_selectedBranch != 'All') {
      baseList = baseList.where((u) {
        final c = u['community_name'] ?? u['communityName'] ?? '';
        return c == _selectedBranch;
      }).toList();
    }

    // District filter
    if (_selectedDistrict != 'All') {
      baseList = baseList.where((u) {
        String d = u['district_elder_name'] ?? u['districtElderName'] ?? '';
        return d == _selectedDistrict;
      }).toList();
    }

    // Community filter (if not already filtered by branch)
    if (_selectedCommunity != 'All' && _selectedBranch == 'All') {
      baseList = baseList.where((u) {
        String c = u['community_name'] ?? u['communityName'] ?? '';
        return c == _selectedCommunity;
      }).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      baseList = baseList.where((user) {
        final name = "${user['name'] ?? ''} ${user['surname'] ?? ''}"
            .toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sorting: Parents first (by hierarchy), then Visitors, then Members
    baseList.sort((a, b) {
      bool aIsParent =
          a['visitor_category'] == 'Mother' ||
          a['visitor_category'] == 'Father';
      bool bIsParent =
          b['visitor_category'] == 'Mother' ||
          b['visitor_category'] == 'Father';
      if (aIsParent && bIsParent) {
        int aPriority = _getParentPriority(a);
        int bPriority = _getParentPriority(b);
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        return "${a['name']} ${a['surname']}".compareTo(
          "${b['name']} ${b['surname']}",
        );
      }
      if (aIsParent && !bIsParent) return -1;
      if (!aIsParent && bIsParent) return 1;
      bool aIsVisitor = a['isVisitor'] == true;
      bool bIsVisitor = b['isVisitor'] == true;
      if (aIsVisitor && !bIsVisitor) return -1;
      if (!aIsVisitor && bIsVisitor) return 1;
      final nameA = "${a['name'] ?? ''} ${a['surname'] ?? ''}".toLowerCase();
      final nameB = "${b['name'] ?? ''} ${b['surname'] ?? ''}".toLowerCase();
      return nameA.compareTo(nameB);
    });

    return baseList;
  }

  Map<String, List<dynamic>> get _groupedUsersByDistrict {
    Map<String, List<dynamic>> grouped = {};
    for (var user in _filteredUsers) {
      String districtName =
          user['district_elder_name'] ??
          user['districtElderName'] ??
          'Unassigned District';
      if (!grouped.containsKey(districtName)) grouped[districtName] = [];
      grouped[districtName]!.add(user);
    }
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    _fetchOverseerDataAndMembers();
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
    _toggleDebouncers.values.forEach((t) => t.cancel());
    _toggleDebouncers.clear();
    super.dispose();
  }

  Future<void> _fetchOverseerDataAndMembers() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // 1. Fetch Overseer Hierarchy
      final oRes = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/overseers/?uid=$uid'),
        headers: headers,
      );
      if (oRes.statusCode == 200) {
        final decoded = json.decode(oRes.body);
        final results = (decoded is Map && decoded.containsKey('results'))
            ? decoded['results']
            : decoded;
        if (results is List && results.isNotEmpty) {
          _overseerData = results[0];
          final List districts = _overseerData!['districts'] ?? [];
          Map<String, List<String>> mapping = {};
          for (var d in districts) {
            String dName = d['district_elder_name'] ?? 'Unknown District';
            List communities = d['communities'] ?? [];
            mapping[dName] = communities
                .map((c) => c['community_name'].toString())
                .toList();
          }
          _officialHierarchy = mapping;
        }
      }

      // 2. Fetch Users
      final uRes = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid'),
        headers: headers,
      );
      List<Map<String, dynamic>> members = [];
      if (uRes.statusCode == 200) {
        final decoded = json.decode(uRes.body);
        final rawList = (decoded is Map && decoded.containsKey('results'))
            ? decoded['results'] as List
            : decoded as List;
        for (var m in rawList) {
          final map = Map<String, dynamic>.from(m as Map);
          if ((map['overseer_uid'] ?? '').toString() == uid) {
            map['isVisitor'] = false;
            map['visitor_category'] = 'Registered';
            map['uid'] = map['uid'];
            map['isPresent'] = false;
            members.add(map);
          }
        }
      }

      // 3. Fetch Visitors
      final vRes = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/visitors/?overseer_uid=$uid',
        ),
        headers: headers,
      );
      List<Map<String, dynamic>> visitors = [];
      if (vRes.statusCode == 200) {
        final decoded = json.decode(vRes.body);
        final rawList = (decoded is Map && decoded.containsKey('results'))
            ? decoded['results'] as List
            : decoded as List;
        for (var v in rawList) {
          final map = Map<String, dynamic>.from(v as Map);
          if ((map['overseer_uid'] ?? '').toString() == uid) {
            map['isVisitor'] = true;
            map['visitor_category'] = map['visitor_category'] ?? 'Testify';
            map['uid'] = map['id'];
            map['isPresent'] = false;
            visitors.add(map);
          }
        }
      }

      _usersList = [...members, ...visitors];

      // Update hierarchy with any new communities
      for (var u in _usersList) {
        String dName =
            u['district_elder_name'] ??
            u['districtElderName'] ??
            'Unassigned District';
        String cName =
            u['community_name'] ?? u['communityName'] ?? 'Unassigned Community';
        if (cName.isNotEmpty) {
          if (!_officialHierarchy.containsKey(dName))
            _officialHierarchy[dName] = [];
          if (!_officialHierarchy[dName]!.contains(cName))
            _officialHierarchy[dName]!.add(cName);
        }
      }

      await _fetchAttendanceForSelectedDate(token);
    } catch (e) {
      print("Network error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendanceForSelectedDate(String token) async {
    try {
      for (var u in _usersList) u['isPresent'] = false;
      Set<String> allCommunities = {};
      for (var comms in _officialHierarchy.values) allCommunities.addAll(comms);
      List<Future<http.Response>> requests = [];
      for (String comm in allCommunities) {
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=$comm&month=${_selectedDate.month}&year=${_selectedDate.year}',
        );
        requests.add(
          http.get(url, headers: {'Authorization': 'Bearer $token'}),
        );
      }
      final responses = await Future.wait(requests);
      for (var res in responses) {
        if (res.statusCode == 200) {
          final decoded = json.decode(res.body);
          List data = decoded['data'] ?? [];
          for (var item in data) {
            String uiId = item['uid'].toString();
            bool isPresentOnDay =
                (item['attendance'] ?? {})[_selectedDate.day.toString()] ==
                true;
            int idx = _usersList.indexWhere((u) => u['uid'].toString() == uiId);
            if (idx != -1) _usersList[idx]['isPresent'] = isPresentOnDay;
          }
        }
      }
    } catch (e) {
      print("Error fetching attendance: $e");
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

  Future<void> _toggleUserAttendance(
    String uiId,
    bool isPresent,
    bool isVisitor,
  ) async {
    if (_toggleDebouncers.containsKey(uiId)) {
      _toggleDebouncers[uiId]!.cancel();
      _toggleDebouncers.remove(uiId);
    }
    final index = _usersList.indexWhere((u) => u['uid'] == uiId);
    if (index == -1) return;
    setState(() {
      _usersList[index]['isPresent'] = isPresent;
    });
    _toggleDebouncers[uiId] = Timer(
      const Duration(milliseconds: 300),
      () async {
        _toggleDebouncers.remove(uiId);
        final currentIndex = _usersList.indexWhere((u) => u['uid'] == uiId);
        if (currentIndex == -1) return;
        final currentIsPresent = _usersList[currentIndex]['isPresent'] as bool;
        await _sendAttendanceUpdate(uiId, currentIsPresent, isVisitor);
      },
    );
  }

  Future<void> _sendAttendanceUpdate(
    String uiId,
    bool isPresent,
    bool isVisitor,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() ?? "" : "";
      final endpoint = isVisitor ? '/visitors/$uiId/' : '/users/$uiId/';
      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final response = await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'attendance_status': isPresent ? 'Present' : 'Absent',
          'date': formattedDate,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        final index = _usersList.indexWhere((u) => u['uid'] == uiId);
        if (index != -1)
          setState(() => _usersList[index]['isPresent'] = !isPresent);
        Api().showMessage(
          context,
          "Failed to update attendance.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      final index = _usersList.indexWhere((u) => u['uid'] == uiId);
      if (index != -1)
        setState(() => _usersList[index]['isPresent'] = !isPresent);
      Api().showMessage(
        context,
        "Network error updating attendance.",
        "Error",
        Colors.red,
      );
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
        await _fetchOverseerDataAndMembers();
      } else {
        Api().showMessage(
          context,
          "Failed to update record.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      print("Update Error: $e");
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
    String gender,
    String district,
    String community, {
    String visitorCategory = 'Testify',
    String? visitorRole,
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";
      final uid = user?.uid;
      final payload = {
        "name": name,
        "surname": surname,
        "phone": phone,
        "address": address,
        "gender": gender,
        "community_name": community,
        "district_elder_name": district,
        "overseer_uid": uid,
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
        _fetchOverseerDataAndMembers();
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

  String _capitaliseName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _exportMemberList() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() ?? "" : "";
    Uint8List? signatureBytes;
    try {
      final res = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?uid=${user?.uid}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty) {
          final sigStr = data[0]['signature_base64'];
          if (sigStr != null && sigStr.isNotEmpty)
            signatureBytes = base64Decode(sigStr);
        }
      }
    } catch (e) {
      print("Error fetching signature: $e");
    }
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}
    OverseerPdfGenerator.exportMemberListPDF(
      context: context,
      members: _filteredUsers,
      overseerName:
          _overseerData?['overseer_initials_surname'] ??
          widget.loggerName ??
          'Unknown',
      regionName: _overseerData?['region'] ?? widget.regionName ?? 'Unknown',
      loggerName: widget.loggerName ?? 'Authorized Officer',
      loggerRole: widget.loggerRole ?? '',
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'testifyBtn',
              onPressed: () {
                showAddVisitorDialog(
                  context,
                  widget.neumoColor,
                  _primaryColor,
                  _officialHierarchy,
                  _submitNewVisitor,
                );
              },
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
              heroTag: 'parentBtn',
              onPressed: () {
                showAddVisitingMemberDialog(
                  context,
                  widget.neumoColor,
                  _primaryColor,
                  _officialHierarchy,
                  _submitNewVisitor,
                );
              },
              backgroundColor: _primaryColor,
              icon: Icon(
                CupertinoIcons.person_3_fill,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                "Add Parents",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomScrollView(
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
                          _overseerData?['overseer_initials_surname'] ??
                              widget.loggerName ??
                              'Unassigned',
                          _overseerData?['region'] ??
                              widget.regionName ??
                              'Unassigned',
                        ),
                        const SizedBox(height: 32),

                        // --- NEW BRANCH SELECTOR ---
                        _buildBranchSelector(),
                        const SizedBox(height: 16),

                        // --- FILTER SECTION ---
                        _buildFilterSection(),
                        const SizedBox(height: 16),

                        // --- ATTENDANCE OVERVIEW ---
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
                                    builder: (context) =>
                                        OverseerFullReportsPage(
                                          usersList: _usersList,
                                          hierarchy: _officialHierarchy,
                                          selectedDate: _selectedDate,
                                          neumoColor: widget.neumoColor,
                                          primaryColor: _primaryColor,
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
                        _buildDashboardChart(),
                        const SizedBox(height: 32),

                        // --- REGISTER LIST HEADER ---
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
                            _buildQrScanButton(),
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
                                        ? "No members found for this criteria."
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
            ),
          );
        },
      ),
    );
  }

  // --- NEW BRANCH SELECTOR ---
  Widget _buildBranchSelector() {
    // Collect all unique communities from hierarchy
    Set<String> allCommunities = {};
    for (var list in _officialHierarchy.values) allCommunities.addAll(list);
    List<String> branchOptions = ['All', ...allCommunities];

    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                "Select Branch (Community)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBranch,
                icon: Icon(CupertinoIcons.chevron_down, size: 14),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[800],
                  fontSize: 13,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBranch = newValue!;
                    _selectedCommunity = 'All'; // Reset community filter
                    _selectedDistrict = 'All';
                    _currentPage = 0;
                  });
                },
                items: branchOptions.map<DropdownMenuItem<String>>((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_selectedBranch != 'All')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Showing members from: $_selectedBranch",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    List<String> distOptions = ['All', ..._officialHierarchy.keys];
    List<String> commOptions = ['All'];
    if (_selectedDistrict != 'All' &&
        _officialHierarchy.containsKey(_selectedDistrict)) {
      commOptions.addAll(_officialHierarchy[_selectedDistrict]!);
    } else {
      Set<String> allComms = {};
      for (var list in _officialHierarchy.values) allComms.addAll(list);
      commOptions.addAll(allComms);
    }

    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.calendar, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                "Filter & Date Selection",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // Date Picker
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: _primaryColor,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedDate)
                      _onDateChanged(picked);
                  },
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
              // District Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedDistrict,
                      icon: Icon(CupertinoIcons.chevron_down, size: 14),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800],
                        fontSize: 13,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDistrict = newValue!;
                          _selectedCommunity = 'All';
                          _currentPage = 0;
                        });
                      },
                      items: distOptions.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Community Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCommunity,
                      icon: Icon(CupertinoIcons.chevron_down, size: 14),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800],
                        fontSize: 13,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCommunity = newValue!;
                          _currentPage = 0;
                        });
                      },
                      items: commOptions.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                    if (code != null) _processScannedQR(code);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _processScannedQR(String code) {
    final userIndex = _usersList.indexWhere(
      (u) => u['uid']?.toString() == code,
    );
    if (userIndex == -1) {
      Api().showMessage(
        context,
        "User with this ID not found.",
        "Not Found",
        Colors.orange,
      );
      return;
    }
    final user = _usersList[userIndex];
    final bool isVisitor = user['isVisitor'] ?? false;
    final bool isPresent = user['isPresent'] ?? false;
    if (isPresent) {
      Api().showMessage(
        context,
        "${user['name'] ?? 'User'} is already marked present.",
        "Already Scanned",
        Colors.yellow,
      );
    } else {
      _toggleUserAttendance(user['uid'], true, isVisitor);
      Api().showMessage(
        context,
        "${user['name'] ?? 'User'} marked present!",
        "Checked In",
        Colors.green,
      );
    }
  }

  Widget _buildDownloadMenu() {
    return PopupMenuButton<String>(
      // In _buildDownloadMenu, replace the onSelected handler with:
      onSelected: (value) async {
        // Determine branch display name
        String branchDisplay = _selectedBranch == 'All'
            ? 'All Branches'
            : _selectedBranch;

        if (value == 'Monthly') {
          showMonthPickerForReport(context, widget.neumoColor, _primaryColor, (
            month,
            year,
          ) {
            showSignatureDialog(context, widget.neumoColor, _primaryColor, (
              signatureBytes,
            ) {
              OverseerPdfGenerator.generateMonthlyReportPDF(
                context: context,
                month: month,
                year: year,
                officialHierarchy: _officialHierarchy,
                usersList: _filteredUsers,
                overseerName:
                    _overseerData?['overseer_initials_surname'] ??
                    'Unknown Overseer',
                regionName: _overseerData?['region'] ?? 'Unknown Region',
                loggerName: widget.loggerName ?? 'Unknown User',
                loggerRole: widget.loggerRole ?? 'Authorized Officer',
                signatureBytes: signatureBytes,
                totalMembers: totalMembers,
                presentMembers: presentMembers,
                absentMembers: absentMembers,
                totalTestifies: totalTestifies,
                readyTestifies: readyTestifies,
                brothersPresent: brothersPresent,
                brothersTotal: brothersTotal,
                sistersPresent: sistersPresent,
                sistersTotal: sistersTotal,
                branchName: branchDisplay, // NEW
              );
            });
          });
        } else if (value == 'MemberList') {
          _exportMemberList(); // You may also add branchName to this function if desired
        } else {
          showSignatureDialog(context, widget.neumoColor, _primaryColor, (
            signatureBytes,
          ) {
            OverseerPdfGenerator.exportRegisterToPDF(
              context: context,
              filterType: value,
              groupedUsersByDistrict: _groupedUsersByDistrict,
              overseerName:
                  _overseerData?['overseer_initials_surname'] ??
                  'Unknown Overseer',
              regionName: _overseerData?['region'] ?? 'Unknown Region',
              loggerName: widget.loggerName ?? 'Unknown User',
              loggerRole: widget.loggerRole ?? 'Authorized Officer',
              signatureBytes: signatureBytes,
              totalMembers: totalMembers,
              presentMembers: presentMembers,
              absentMembers: absentMembers,
              totalTestifies: totalTestifies,
              readyTestifies: readyTestifies,
              brothersPresent: brothersPresent,
              brothersTotal: brothersTotal,
              sistersPresent: sistersPresent,
              sistersTotal: sistersTotal,
              branchName: branchDisplay, // NEW
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

  Widget _buildDashboardChart() {
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
            separatorBuilder: (context, index) =>
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) =>
                _buildTableRow(paginatedData[index]),
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

  Widget _buildTableRow(Map<String, dynamic> user) {
    final name = _capitaliseName(user['name']);
    final surname = _capitaliseName(user['surname']);
    final fullName = "$name $surname".trim();
    final isPresent = user['isPresent'] ?? false;
    final isVisitor = user['isVisitor'] ?? false;
    final visitorCategory = user['visitor_category'] ?? 'Testify';
    final visitorRole = user['visitor_role'];
    final isReady =
        user['ready_for_membership'] == true ||
        user['ready_for_membership'] == 'true';
    final commName =
        user['community_name'] ?? user['communityName'] ?? 'Unassigned';
    final elderName =
        user['district_elder_name'] ??
        user['districtElderName'] ??
        'Unknown Elder';

    String tagLabel = "";
    Color tagColor = Colors.transparent;
    bool isParent = visitorCategory == 'Mother' || visitorCategory == 'Father';

    if (isParent) {
      String roleForTag = visitorRole ?? 'None';
      String? matchedRole;
      for (String role in _spiritualRoleOrder) {
        if (roleForTag.contains(role)) {
          matchedRole = role;
          break;
        }
      }
      if (matchedRole != null) {
        tagLabel = matchedRole;
        tagColor = _roleTagColors[matchedRole] ?? Colors.grey;
      } else {
        tagLabel = visitorCategory.toUpperCase();
        tagColor = Colors.purple;
      }
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
                          SizedBox(height: 4),
                          Text(
                            "$commName | Elder: $elderName",
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
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
                    tooltip: "Edit Record",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
