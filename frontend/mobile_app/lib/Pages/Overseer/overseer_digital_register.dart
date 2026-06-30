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
import 'package:ttact/Pages/Overseer/components/overseer_dialog.dart';
import 'package:ttact/Pages/Overseer/components/overseer_reports_full_page.dart';
import 'package:ttact/Pages/Overseer/components/overseer_utilities.dart';
import 'package:ttact/Pages/Overseer/components/pdf_generator_register.dart';

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

  int _currentPage = 0;
  final int _rowsPerPage = 50;

  Color get _primaryColor => Theme.of(context).primaryColor;

  // Editable Date Check
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

  // Stats now use _filteredUsers to ensure dynamic dashboard updates
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

  List<dynamic> get _filteredUsers {
    List<dynamic> baseList = _usersList;

    // Apply District Filter
    if (_selectedDistrict != 'All') {
      baseList = baseList.where((u) {
        String d =
            u['district_elder_name'] ??
            u['districtElderName'] ??
            'Unassigned District';
        return d == _selectedDistrict;
      }).toList();
    }

    // Apply Community Filter
    if (_selectedCommunity != 'All') {
      baseList = baseList.where((u) {
        String c =
            u['community_name'] ?? u['communityName'] ?? 'Unassigned Community';
        return c == _selectedCommunity;
      }).toList();
    }

    // Apply Search Query
    if (_searchQuery.isNotEmpty) {
      baseList = baseList.where((user) {
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

  Map<String, List<dynamic>> get _groupedUsersByDistrict {
    Map<String, List<dynamic>> grouped = {};
    for (var user in _filteredUsers) {
      String districtName =
          user['district_elder_name'] ??
          user['districtElderName'] ??
          'Unassigned District';
      if (!grouped.containsKey(districtName)) {
        grouped[districtName] = [];
      }
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

      // 2. Fetch Users strictly filtering by `overseer_uid`
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
          String mOverseer = (map['overseer_uid'] ?? '').toString();

          if (mOverseer == uid) {
            map['isVisitor'] = false;
            map['visitor_category'] = 'Registered';
            map['ui_id'] = map['uid'];
            map['isPresent'] = false; // Default, will override below
            members.add(map);
          }
        }
      }

      // 3. Fetch Visitors strictly filtering by `overseer_uid`
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
          String vOverseer = (map['overseer_uid'] ?? '').toString();

          if (vOverseer == uid) {
            map['isVisitor'] = true;
            map['visitor_category'] = map['visitor_category'] ?? 'Testify';
            map['ui_id'] = map['id'];
            map['isPresent'] = false; // Default, will override below
            visitors.add(map);
          }
        }
      }

      _usersList = [...members, ...visitors];

      // Re-map communities just in case new ones were added outside hierarchy
      for (var u in _usersList) {
        String dName =
            u['district_elder_name'] ??
            u['districtElderName'] ??
            'Unassigned District';
        String cName =
            u['community_name'] ?? u['communityName'] ?? 'Unassigned Community';

        if (cName.isNotEmpty) {
          if (!_officialHierarchy.containsKey(dName)) {
            _officialHierarchy[dName] = [];
          }
          if (!_officialHierarchy[dName]!.contains(cName)) {
            _officialHierarchy[dName]!.add(cName);
          }
        }
      }

      // Fetch historical attendance for the selected date
      await _fetchAttendanceForSelectedDate(token);
    } catch (e) {
      print("Network error fetching spiritual data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Uses Monthly Report to accurately extract attendance for the _selectedDate
  Future<void> _fetchAttendanceForSelectedDate(String token) async {
    try {
      // 1. Reset all local states to absent (Critical for new days to reset naturally)
      for (var u in _usersList) {
        u['isPresent'] = false;
      }

      // 2. Gather unique communities
      Set<String> allCommunities = {};
      for (var comms in _officialHierarchy.values) {
        allCommunities.addAll(comms);
      }

      // 3. Batch process requests in parallel
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

      // 4. Map true/false statuses based on selected day
      for (var res in responses) {
        if (res.statusCode == 200) {
          final decoded = json.decode(res.body);
          List data = decoded['data'] ?? [];
          for (var item in data) {
            String uiId = item['ui_id'].toString();
            Map<String, dynamic> attMap = item['attendance'] ?? {};

            bool isPresentOnDay = attMap[_selectedDate.day.toString()] == true;

            int idx = _usersList.indexWhere(
              (u) => u['ui_id'].toString() == uiId,
            );
            if (idx != -1) {
              _usersList[idx]['isPresent'] = isPresentOnDay;
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching daily historical attendance: $e");
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
    if (!_isEditableDay) return; // Failsafe for past days

    final index = _usersList.indexWhere((u) => u['ui_id'] == uiId);
    if (index == -1) return;

    setState(() {
      _usersList[index]['isPresent'] = isPresent;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      final endpoint = isVisitor ? '/visitors/$uiId/' : '/users/$uiId/';

      String formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'attendance_status': isPresent ? 'Present' : 'Absent',
          'date': formattedDate,
        }),
      );
    } catch (e) {
      print("Error saving attendance: $e");
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isEditableDay
          ? Padding(
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
                    heroTag: 'guestBtn',
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
            )
          : const SizedBox.shrink(),
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

                        // --- DYNAMIC FILTER SECTION ---
                        _buildFilterSection(),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: buildSectionHeader(
                                "Digital Register",
                                CupertinoIcons.list_bullet,
                                _primaryColor,
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

  // --- UI WIDGETS BOUND TO STATE ---

  Widget _buildFilterSection() {
    List<String> distOptions = ['All', ..._officialHierarchy.keys];
    List<String> commOptions = ['All'];

    if (_selectedDistrict != 'All' &&
        _officialHierarchy.containsKey(_selectedDistrict)) {
      commOptions.addAll(_officialHierarchy[_selectedDistrict]!);
    } else {
      Set<String> allComms = {};
      for (var list in _officialHierarchy.values) {
        allComms.addAll(list);
      }
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
                    if (picked != null && picked != _selectedDate) {
                      _onDateChanged(picked);
                    }
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
                          _selectedCommunity =
                              'All'; // Reset community on district change
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

  Widget _buildDownloadMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
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
                usersList: _filteredUsers, // Passes filtered data to generator
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
              );
            });
          });
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

    final commName =
        user['community_name'] ?? user['communityName'] ?? 'Unassigned';
    final elderName =
        user['district_elder_name'] ??
        user['districtElderName'] ??
        'Unknown Elder';

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isEditableDay
            ? () => _toggleUserAttendance(user['ui_id'], !isPresent, isVisitor)
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
                                  color: Colors.white,
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
                                  user['ui_id'],
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

// =========================================================================
// NEW PAGE: FULL REPORTS VIEW WITH NATIVE FLUTTER GRAPHS & FILTERS
// =========================================================================
