// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/tactso_pages/applications.dart';
import 'package:ttact/Pages/tactso_pages/commitees.dart';
import 'package:ttact/Pages/tactso_pages/dashboard.dart';
import 'package:ttact/Pages/tactso_pages/spiritual_leading.dart';
import 'package:ttact/Components/NeuDesign.dart';

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

  Color get _primaryColor => Theme.of(context).primaryColor;

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
    final Color neumoBaseColor = _neumorphicBaseColor;

    if (_isLoadingUniversityData) {
      return Scaffold(
        backgroundColor: neumoBaseColor,
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
        backgroundColor: neumoBaseColor,
        body: Center(child: Text("Branch not found.")),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: _buildAppBar(context, neumoBaseColor),
      drawer: screenWidth < _desktopBreakpoint
          ? Drawer(
              backgroundColor: neumoBaseColor,
              child: _buildDrawerContent(
                context,
                color: theme.textTheme.bodyMedium!.color!,
              ),
            )
          : null,
      body: screenWidth >= _desktopBreakpoint
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 280,
                  color: neumoBaseColor,
                  child: _buildDrawerContent(
                    context,
                    color: theme.textTheme.bodyMedium!.color!,
                  ),
                ),
                Expanded(child: _buildBodyContent(neumoBaseColor)),
              ],
            )
          : _buildBodyContent(neumoBaseColor),
      bottomNavigationBar: screenWidth < _desktopBreakpoint
          ? _buildBottomNav(theme, neumoBaseColor)
          : null,
    );
  }

  Widget _buildBodyContent(Color neumoColor) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          top: -50,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.15),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.15),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: Column(
                  children: [Expanded(child: _getTabContent(neumoColor))],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getTabContent(Color neumoColor) {
    switch (_selectedIndex) {
      case 0:
        return DashboardTab(
          branchId: _branchId!,
          neumoColor: neumoColor,
          universityName: _universityName,
          loggedMemberName: _activeMemberName,
        );
      case 1:
        return ApplicationsTab(
          branchId: _branchId!,
          neumoColor: neumoColor,
          universityName: _universityName!,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          faceUrl: _activeMemberFace,
          universityLogoUrl: _universityLogoUrl,
        );
      case 2:
        return CommitteeTab(
          branchId: _branchId!,
          neumoColor: neumoColor,
          universityName: _universityName!,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          faceUrl: _activeMemberFace,
          universityLogoUrl: _universityLogoUrl,
        );
      case 3:
        return SpiritualManagementTab(
          branchId: _branchId!,
          overseerId: _overseerId,
          districtId: _districtId,
          universityName: _universityName!,
          neumoColor: neumoColor,
          loggedMemberName: _activeMemberName,
          loggedMemberRole: _activeMemberRole,
          universityLogoUrl: _universityLogoUrl,
        );
      default:
        return Center(child: Text("Tab not found"));
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Color bgColor) {
    String secureFace = _getSecureImageUrl(_activeMemberFace);
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _universityName ?? "Admin",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            _activeMemberName ?? "Connecting Identity...",
            style: TextStyle(
              fontSize: 12,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      actions: [
        IconButton(icon: Icon(Icons.logout_rounded), onPressed: _logout),
        SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: _primaryColor.withOpacity(0.1),
            backgroundImage: secureFace.isNotEmpty
                ? NetworkImage(secureFace)
                : null,
            child: secureFace.isEmpty
                ? Icon(Icons.person, color: _primaryColor)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerContent(BuildContext context, {required Color color}) {
    String secureFace = _getSecureImageUrl(_activeMemberFace);
    return Column(
      children: [
        SizedBox(height: 40),
        NeumorphicContainer(
          borderRadius: 50,
          padding: EdgeInsets.all(4),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: CircleAvatar(
            radius: 40,
            backgroundImage: secureFace.isNotEmpty
                ? NetworkImage(secureFace)
                : null,
            child: secureFace.isEmpty ? Icon(Icons.person, size: 40) : null,
          ),
        ),
        SizedBox(height: 15),
        Text(
          _activeMemberName ?? "Member",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          _activeMemberRole ?? "Portfolio",
          style: TextStyle(color: _primaryColor, fontSize: 12),
        ),
        SizedBox(height: 30),
        _drawerItem(Icons.dashboard_rounded, "Dashboard", 0, color),
        _drawerItem(Icons.table_chart_rounded, "Applications", 1, color),
        _drawerItem(Icons.groups_rounded, "Committee", 2, color),
        _drawerItem(Icons.church_rounded, "Spiritual Management", 3, color),
        Spacer(),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
          onTap: _logout,
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String title, int index, Color color) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive
            ? _primaryColor.withOpacity(0.1)
            : Colors.transparent,
        leading: Icon(icon, color: isActive ? _primaryColor : color),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? _primaryColor : color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Scaffold.of(context).hasDrawer &&
              Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme, Color neumoBaseColor) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: neumoBaseColor,
        indicatorColor: _primaryColor.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: theme.textTheme.bodyMedium!.color, fontSize: 12),
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
            icon: Icon(Icons.church_outlined),
            selectedIcon: Icon(Icons.church),
            label: 'Spiritual',
          ),
        ],
      ),
    );
  }
}
