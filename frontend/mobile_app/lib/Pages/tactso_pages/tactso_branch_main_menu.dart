// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/memorandum_generator_page.dart';
import 'package:ttact/Pages/tactso_pages/applications.dart';
import 'package:ttact/Pages/tactso_pages/commitees.dart';
import 'package:ttact/Pages/tactso_pages/dashboard.dart';
import 'package:ttact/Pages/tactso_pages/spiritual_leading.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/tactso_pages/tactso_contitution.dart';
import 'package:ttact/Pages/tactso_pages/tactso_meeting_minutes_tab.dart';

const double _desktopBreakpoint = 1100.0;
const Color _neumorphicBaseColor = Color(0xFFF0F2F5);

class TactsoBranchesApplications extends StatefulWidget {
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;

  const TactsoBranchesApplications({
    super.key,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
  });

  @override
  State<TactsoBranchesApplications> createState() =>
      _TactsoBranchesApplicationsState();
}

class _TactsoBranchesApplicationsState
    extends State<TactsoBranchesApplications> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _universityName;
  String? _currentuid;
  String? _branchId;
  String? _overseerId;
  String? _districtId;
  String? _universityLogoUrl;

  String? _activeMemberName;
  String? _activeMemberRole;
  String? _activeMemberFace;

  bool _isLoadingUniversityData = true;
  int _selectedIndex = 0;

  bool _isApplicationOpen = false;
  bool _isTogglingStatus = false;

  Color get _primaryColor => Theme.of(context).primaryColor;

  final List<String> _pageTitles = [
    "Dashboard",
    "Applications",
    "Committee Management",
    "Constitution",
    "Memorandum Generator",
    "Spiritual Management",
    "Meeting Minutes",
  ];

  @override
  void initState() {
    super.initState();
    _loadUniversityData();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  Future<void> _checkAuthorization() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // --- ⭐️ PREMIUM NEUMORPHIC TERMS AGREEMENT DIALOG ---
  Future<bool> _showNeumorphicTermsDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: _neumorphicBaseColor,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-8, -8),
                      blurRadius: 15,
                    ),
                    BoxShadow(
                      color: Colors.grey.shade400,
                      offset: Offset(8, 8),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeumorphicContainer(
                      color: _neumorphicBaseColor,
                      borderRadius: 50,
                      padding: const EdgeInsets.all(20),
                      child: Icon(
                        Icons.security_outlined,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Audit & Privacy Agreement',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'As an appointed committee member, you must agree to our Terms of Use. By continuing, you consent that your actions within this portal are recorded in the system audit logs for security and tracking purposes.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(false),
                            child: NeumorphicContainer(
                              color: _neumorphicBaseColor,
                              borderRadius: 12,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Decline',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'I Agree',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
          ),
        ) ??
        false;
  }

  Future<void> _checkCommitteeTerms(dynamic memberId, String token) async {
    final agreed = await _showNeumorphicTermsDialog();
    if (agreed) {
      try {
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$memberId/',
        );
        final response = await http.patch(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'accepted_ts_and_cs': true}),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          await _logout();
        }
      } catch (e) {
        await _logout();
      }
    } else {
      await _logout();
    }
  }

  Future<void> _loadUniversityData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentuid = currentUser.uid;

      try {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _activeMemberName =
              widget.loggedMemberName ?? prefs.getString('active_session_name');
          _activeMemberRole =
              widget.loggedMemberRole ?? prefs.getString('active_session_role');
          _activeMemberFace =
              widget.faceUrl ?? prefs.getString('active_session_face');
        });

        String token = await currentUser.getIdToken() ?? "";

        final branchUrl = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/?uid=$_currentuid',
        );
        final response = await http.get(
          branchUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          var decoded = json.decode(response.body);
          List<dynamic> results = (decoded is Map)
              ? decoded['results']
              : decoded;

          if (results.isNotEmpty) {
            var data = results[0];
            _branchId = data['id'].toString();
            _universityName = data['university_name'] ?? 'University Admin';
            _overseerId = data['overseer']?.toString();
            _districtId = data['assigned_district']?.toString();
            _isApplicationOpen = data['is_application_open'] ?? false;

            _activeMemberName ??= data['education_officer_name'];
            _activeMemberRole ??= "Authorized Member";
            _activeMemberFace ??= data['education_officer_face_url'];

            var imgField = data['image_url'];
            if (imgField is List && imgField.isNotEmpty) {
              _universityLogoUrl = imgField[0].toString();
            } else if (imgField is String) {
              _universityLogoUrl = imgField;
            }

            if (_activeMemberFace != null) {
              final commUrl = Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/?branch=$_branchId&face_url=${Uri.encodeComponent(_activeMemberFace!)}',
              );
              final commRes = await http.get(
                commUrl,
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              );
              if (commRes.statusCode == 200) {
                var commData = json.decode(commRes.body);
                List commList = (commData is Map)
                    ? commData['results']
                    : commData;
                if (commList.isNotEmpty) {
                  var memberData = commList[0];
                  bool acceptedTsAndCs =
                      memberData['accepted_ts_and_cs'] ?? false;
                  if (!acceptedTsAndCs) {
                    await _checkCommitteeTerms(memberData['id'], token);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Data Load Error: $e");
      }
    }
    setState(() => _isLoadingUniversityData = false);
  }

  Future<void> _toggleApplicationStatus(bool newValue) async {
    if (_branchId == null) return;
    setState(() => _isTogglingStatus = true);

    try {
      User? currentUser = _auth.currentUser;
      String token = await currentUser?.getIdToken() ?? "";
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/$_branchId/',
      );

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'is_application_open': newValue}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _isApplicationOpen = newValue);
        Api().showMessage(
          context,
          "Applications are now ${newValue ? 'OPEN' : 'CLOSED'}",
          "Status Updated",
          Colors.green,
        );
      } else {
        Api().showMessage(
          context,
          "Failed to update application status.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      Api().showMessage(context, "An error occurred.", "Error", Colors.red);
    } finally {
      setState(() => _isTogglingStatus = false);
    }
  }

  String _getSecureImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return "";
    if (originalUrl.startsWith('http') && !originalUrl.contains('.enc'))
      return originalUrl;
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_name');
    await prefs.remove('active_session_role');
    await prefs.remove('active_session_face');
    await _auth.signOut();
    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= _desktopBreakpoint;

    if (_isLoadingUniversityData) {
      return Scaffold(
        backgroundColor: _neumorphicBaseColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 16),
              SizedBox(height: 16),
              Text(
                "Securing Session...",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_branchId == null) {
      return Scaffold(
        backgroundColor: _neumorphicBaseColor,
        body: Center(child: Text("Branch not found.")),
      );
    }

    return Scaffold(
      backgroundColor: _neumorphicBaseColor,
      appBar: isDesktop ? null : _buildMobileAppBar(context),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: _neumorphicBaseColor,
              child: _buildSidebarContent(),
            ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileBody(),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(theme),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT (PREMIUM UI)
  // ===========================================================================
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: Offset(5, 0),
              ),
            ],
          ),
          child: _buildSidebarContent(),
        ),
        // Main Content Area
        Expanded(
          child: Stack(
            children: [
              // Abstract Background Decorations
              Positioned(top: -100, left: -50, child: _buildBgCircle()),
              Positioned(bottom: -50, right: -100, child: _buildBgCircle()),

              Column(
                children: [
                  _buildDesktopTopHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          child: _getTabContent(
                            key: ValueKey<int>(_selectedIndex),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pageTitles[_selectedIndex],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[900],
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _universityName ?? "University Dashboard",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Action Controls
          Row(
            children: [
              // Premium Status Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      "Applications: ",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                    Text(
                      _isApplicationOpen ? "OPEN" : "CLOSED",
                      style: TextStyle(
                        fontSize: 13,
                        color: _isApplicationOpen
                            ? Colors.green
                            : Colors.redAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 12),
                    _isTogglingStatus
                        ? SizedBox(
                            width: 36,
                            child: Center(
                              child: CupertinoActivityIndicator(radius: 8),
                            ),
                          )
                        : SizedBox(
                            height: 24,
                            child: CupertinoSwitch(
                              value: _isApplicationOpen,
                              activeColor: Colors.green,
                              onChanged: (value) =>
                                  _toggleApplicationStatus(value),
                            ),
                          ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              // Logout Button
              InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SIDEBAR (Shared Desktop & Drawer)
  // ===========================================================================
  Widget _buildSidebarContent() {
    String secureFace = _getSecureImageUrl(_activeMemberFace);
    return Column(
      children: [
        SizedBox(height: 40),
        // User Profile Area
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_primaryColor.withOpacity(0.5), _primaryColor],
            ),
          ),
          child: CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 38,
              backgroundColor: _neumorphicBaseColor,
              backgroundImage: secureFace.isNotEmpty
                  ? NetworkImage(secureFace)
                  : null,
              child: secureFace.isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                  : null,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          _activeMemberName ?? "Member",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.blueGrey[900],
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _activeMemberRole ?? "Portfolio",
            style: TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 40),

        // Navigation Items
        Expanded(
          child: ListView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildPremiumSidebarItem(Icons.dashboard_rounded, "Dashboard", 0),
              _buildPremiumSidebarItem(
                Icons.table_chart_rounded,
                "Applications",
                1,
              ),
              _buildPremiumSidebarItem(Icons.groups_rounded, "Committee", 2),
              _buildPremiumSidebarItem(
                Icons.receipt_rounded,
                "Constitution",
                3,
              ),
              _buildPremiumSidebarItem(
                Icons.recent_actors_rounded,
                "Memorandum",
                4,
              ),
              _buildPremiumSidebarItem(
                Icons.church_rounded,
                "Attendance reg",
                5,
              ),
              _buildPremiumSidebarItem(
                Icons.edit_document,
                "Meeting Minutes",
                6,
              ),
            ],
          ),
        ),

        // Mobile Logout Fallback
        if (MediaQuery.of(context).size.width < _desktopBreakpoint)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Colors.redAccent.withOpacity(0.1),
              leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _logout,
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumSidebarItem(IconData icon, String title, int index) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Scaffold.of(context).hasDrawer &&
              Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? _primaryColor.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _primaryColor : Colors.grey[500],
                size: 22,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? _primaryColor : Colors.blueGrey[700],
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT
  // ===========================================================================
  Widget _buildMobileBody() {
    return Stack(
      children: [
        Positioned(top: -50, left: -50, child: _buildBgCircle()),
        Positioned(bottom: -50, right: -50, child: _buildBgCircle()),
        SafeArea(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _getTabContent(key: ValueKey<int>(_selectedIndex)),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    String secureFace = _getSecureImageUrl(_activeMemberFace);
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _universityName ?? "Admin",
            style: TextStyle(
              color: Colors.blueGrey[900],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            _activeMemberName ?? "Loading...",
            style: TextStyle(
              fontSize: 12,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: _neumorphicBaseColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.blueGrey[900]),
      actions: [
        Row(
          children: [
            Text(
              _isApplicationOpen ? "OPEN" : "CLOSED",
              style: TextStyle(
                fontSize: 11,
                color: _isApplicationOpen ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            _isTogglingStatus
                ? CupertinoActivityIndicator(radius: 8)
                : Transform.scale(
                    scale: 0.7,
                    child: CupertinoSwitch(
                      value: _isApplicationOpen,
                      activeColor: Colors.green,
                      onChanged: (value) => _toggleApplicationStatus(value),
                    ),
                  ),
          ],
        ),
        SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: _primaryColor.withOpacity(0.1),
            backgroundImage: secureFace.isNotEmpty
                ? NetworkImage(secureFace)
                : null,
            child: secureFace.isEmpty
                ? Icon(Icons.person, color: _primaryColor, size: 18)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav(ThemeData theme) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _primaryColor.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(
            color: Colors.blueGrey[800],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dash',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt_rounded),
            label: 'Const',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt_rounded),
            label: 'Memo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt_rounded),
            label: 'Reg',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_document),
            selectedIcon: Icon(Icons.edit_document),
            label: 'Meeting',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTENT ROUTER & HELPERS
  // ===========================================================================
  Widget _getTabContent({Key? key}) {
    // Wrapped in a container with the key to ensure AnimatedSwitcher detects the change
    return Container(key: key, child: _switchContent());
  }

  Widget _switchContent() {
    switch (_selectedIndex) {
      case 0:
        return DashboardTab(
          branchId: _branchId!,
          neumoColor: _neumorphicBaseColor,
          universityName: _universityName,
          loggedMemberName: _activeMemberName,
        );
      case 1:
        return ApplicationsTab(
          branchId: _branchId!,
          neumoColor: _neumorphicBaseColor,
          universityName: _universityName!,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          faceUrl: _activeMemberFace,
          universityLogoUrl: _universityLogoUrl,
        );
      case 2:
        return CommitteeTab(
          branchId: _branchId!,
          neumoColor: _neumorphicBaseColor,
          universityName: _universityName!,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          faceUrl: _activeMemberFace,
          universityLogoUrl: _universityLogoUrl,
        );
      case 3:
        return TactsoContitution();
      case 4:
        return CircularGeneratorPage(
          branchId: _branchId!,
          universityName: _universityName!,
          neumoColor: _neumorphicBaseColor,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          universityLogoUrl: _universityLogoUrl,
        );
      case 5:
        return SpiritualManagementTab(
          branchId: _branchId!,
          overseerId: _overseerId,
          districtId: _districtId,
          universityName: _universityName!,
          neumoColor: _neumorphicBaseColor,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          universityLogoUrl: _universityLogoUrl,
        );
      case 6:
        return TactsoMeetingMinutesTab(
          isLargeScreen:
              MediaQuery.of(context).size.width >= _desktopBreakpoint,
          branchId: _branchId!,
          universityName: _universityName!,
          committeeMemberName: _activeMemberName ?? 'Unknown Member',
          committeeMemberRole: _activeMemberRole ?? 'Committee',
          faceUrl: _activeMemberFace,
        );
      default:
        return Center(child: Text("Tab not found"));
    }
  }

  Widget _buildBgCircle() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primaryColor.withOpacity(0.05),
      ),
    );
  }
}
