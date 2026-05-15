// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'dart:convert'; // Added for JSON decoding
import 'package:http/http.dart' as http; // Added for API calls
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Admin/Overseer_BalanceSheet_Global.dart';

// --- IMPORT YOUR EXISTING PAGES ---
import 'package:ttact/Pages/Admin/add_career_opportunities.dart';
import 'package:ttact/Pages/Admin/add_committee_member.dart'; 
import 'package:ttact/Pages/Admin/add_songs.dart';
import 'package:ttact/Pages/Admin/add_tactso_org.dart';
import 'package:ttact/Pages/Admin/admin_add_overseer.dart';
import 'package:ttact/Pages/Admin/admin_add_product.dart';
import 'package:ttact/Pages/Admin/admin_dashboard.dart';
import 'package:ttact/Pages/Admin/Admin_Verify_Seller.dart';
import 'package:ttact/Pages/Admin/annual_report_page.dart';
import 'package:ttact/Pages/Admin/assign_overseer_to_university.dart';
import 'package:ttact/Pages/Admin/audit_page.dart';
import 'package:ttact/Pages/Admin/Staff_Members.dart';
import 'package:ttact/Pages/Admin/admin_add_Feed.dart';
import 'package:ttact/Pages/Admin/admin_legal_page.dart';
import 'package:ttact/Pages/Admin/diary_of_events.dart';
import 'package:ttact/Pages/Admin/upload_apostle_greetings.dart';

// --- UTILITIES ---
const double _desktopBreakpoint = 1000.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class AdminPortal extends StatefulWidget {
  final String? faceUrl;
  final String? fullName;
  final String? portfolio;
  final String? province;
  final String? uid;

  const AdminPortal({
    super.key,
    this.faceUrl,
    this.fullName,
    this.portfolio,
    this.province,
    this.uid,
  });

  @override
  _AdminPortalState createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _currentIndex = 0;
  bool _isAuthorized = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String faceUrl = '';
  String fullName = '';
  String portfolio = '';
  String province = '';

  late List<Map<String, dynamic>> _adminNavItems;

  @override
  void initState() {
    super.initState();
    // Use initial widget data if available while checking authorization
    faceUrl = widget.faceUrl ?? '';
    fullName = widget.fullName ?? '';
    portfolio = widget.portfolio ?? '';
    province = widget.province ?? '';

    _initNavItems();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  void _initNavItems() {
    _adminNavItems = [
      {
        'label': 'Dashboard',
        'icon': Ionicons.grid_outline,
        'page': ProfessionalDashboard(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Products',
        'icon': Icons.shopping_bag_outlined,
        'page': AdminAddProduct(),
      },
      {
        'label': 'Songs',
        'icon': Ionicons.musical_notes_outline,
        'page': AddMusic(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Branches',
        'icon': Icons.business_outlined,
        'page': AddTactsoBranch(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Add Apostles Greetings',
        'icon': Icons.church_outlined,
        'page': AdminGreetingsManager(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Overseers',
        'icon': Icons.people_outline,
        'page': AdminAddOverseer(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Global Balance',
        'icon': Icons.history,
        'page': OverseerBalancesheetGlobal(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Sellers',
        'icon': Icons.storefront_outlined,
        'page': AdminVerifySeller(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Careers',
        'icon': Icons.work_outline,
        'page': AddCareerOpportunities(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Committees',
        'icon': Icons.person_add_alt,
        'page': AddCommitteeMember(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Legal',
        'icon': Icons.file_present_outlined,
        'page': AdminLegalBroadcastPage(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Staff',
        'icon': Icons.person_3_outlined,
        'page': StaffMembers(
          faceUrl: faceUrl,
          name: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Audit Logs',
        'icon': Icons.receipt_long_outlined,
        'page': TactsoBranchAudit(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Feeds',
        'icon': Icons.rss_feed,
        'page': PortalAddFeed(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Diary Of event',
        'icon': Icons.rss_feed,
        'page': AdminAddEventDiaryPage(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province,
        ),
      },
      {
        'label': 'Annual Report',
        'icon': Icons.report_outlined,
        'page': AnnualReportPage(
          uid: widget.uid,
          fullName: fullName,
          portfolio: portfolio,
          province: province, 
        ),
      },
    ];
  }

  // ⭐️ SECURED AUTHORIZATION CHECK ⭐️
  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      // 1. Get Security Token
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      // 2. Fetch Staff Profile securely
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/staff/?uid=${user.uid}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final data = results[0];
          final String role = data['role'] ?? '';

          if (mounted) {
            setState(() {
              faceUrl = data['face_url'] ?? '';
              fullName = data['full_name'] ?? '';
              portfolio = data['portfolio'] ?? '';
              province = data['province'] ?? '';
              _isAuthorized = (role == 'Admin');

              // Refresh nav items with retrieved data
              _initNavItems();
            });

            if (!_isAuthorized) {
              Navigator.of(context).pushReplacementNamed('/main-menu');
            }
          }
        } else {
          // Record not found in Django Staff table
          if (mounted) setState(() => _isAuthorized = false);
        }
      } else {
        print("Auth Rejected: ${response.statusCode} - ${response.body}");
        if (mounted) setState(() => _isAuthorized = false);
      }
    } catch (e) {
      print("System Auth Error: $e");
      // Prevent indefinite loading on error
      if (mounted) {
        setState(() => _isAuthorized = false);
        Navigator.of(context).pushReplacementNamed('/main-menu');
      }
    }
  }

  Future<void> _handleLogout() async {
    Api().showLoading(context);
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: neumoBaseColor,
        body: Center(
          child: Api().isIOSPlatform
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );
    }

    final isDesktop = isLargeScreen(context);
    final currentPage = _adminNavItems[_currentIndex]['page'];

    if (isDesktop) {
      return _buildDesktopLayout(theme, neumoBaseColor, currentPage);
    } else {
      return _buildMobileLayout(theme, neumoBaseColor, currentPage);
    }
  }

  // ===========================================================================
  // 🖥️ DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    ThemeData theme,
    Color neumoBaseColor,
    Widget content,
  ) {
    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: neumoBaseColor,
            child: Column(
              children: [
                _buildProfileSection(theme, neumoBaseColor),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: _adminNavItems.asMap().entries.map((entry) {
                      return _buildNavItem(
                        entry.key,
                        entry.value,
                        theme,
                        neumoBaseColor,
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildLogoutButton(theme, neumoBaseColor),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 80,
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _adminNavItems[_currentIndex]['label'],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      isPressed: true,
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Scaffold(
                          backgroundColor: Colors.transparent,
                          body: content,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📱 MOBILE LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout(
    ThemeData theme,
    Color neumoBaseColor,
    Widget content,
  ) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: neumoBaseColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: neumoBaseColor,
        foregroundColor: theme.primaryColor,
        centerTitle: true,
        leadingWidth: 70,
        leading: Center(
          child: GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: NeumorphicContainer(
              color: neumoBaseColor,
              padding: const EdgeInsets.all(10),
              borderRadius: 12,
              child: Icon(Icons.menu, color: Colors.grey[700]),
            ),
          ),
        ),
        title: Text(
          _adminNavItems[_currentIndex]['label'],
          style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Roboto'),
        ),
      ),
      drawer: Drawer(
        backgroundColor: neumoBaseColor,
        child: Column(
          children: [
            SizedBox(height: 40),
            _buildProfileSection(theme, neumoBaseColor),
            Divider(color: theme.hintColor.withOpacity(0.1)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: _adminNavItems.asMap().entries.map((entry) {
                  return _buildNavItem(
                    entry.key,
                    entry.value,
                    theme,
                    neumoBaseColor,
                    isMobile: true,
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildLogoutButton(theme, neumoBaseColor),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
      body: content,
    );
  }

  // ===========================================================================
  // 🧩 WIDGET COMPONENTS
  // ===========================================================================

  Widget _buildProfileSection(ThemeData theme, Color neumoBaseColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          NeumorphicContainer(
            color: neumoBaseColor,
            borderRadius: 100,
            padding: EdgeInsets.all(5),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: faceUrl.isNotEmpty
                  ? NetworkImage(faceUrl)
                  : null,
              child: faceUrl.isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          SizedBox(height: 15),
          Text(
            fullName.isNotEmpty ? fullName : "Admin Profile",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 5),
          Text(
            '$portfolio | $province',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    Map<String, dynamic> item,
    ThemeData theme,
    Color baseColor, {
    bool isMobile = false,
  }) {
    bool isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = index);
          if (isMobile) Navigator.pop(context);
        },
        child: NeumorphicContainer(
          color: isSelected ? theme.primaryColor : baseColor,
          isPressed: false,
          borderRadius: 12,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Icon(
                item['icon'],
                color: isSelected ? Colors.white : theme.hintColor,
                size: 20,
              ),
              SizedBox(width: 15),
              Text(
                item['label'],
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.hintColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme, Color baseColor) {
    return GestureDetector(
      onTap: _handleLogout,
      child: NeumorphicContainer(
        color: baseColor,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              "Logout",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
