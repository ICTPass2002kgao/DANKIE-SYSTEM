// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Overseer/dashboard_tab.dart';
import 'package:ttact/Pages/Overseer/music_contract.dart';
import 'package:ttact/Pages/Overseer/overseer_audit_page.dart';
import 'package:ttact/Pages/Overseer/Subscription_Info.dart';
import 'package:ttact/Pages/Overseer/add_committee_member.dart';
import 'package:ttact/Pages/Overseer/overseer_digital_register.dart';
import 'package:ttact/Pages/Overseer/signatures.dart';

import 'add_member_tab.dart';
import 'all_members_tab.dart';
import 'add_officer_tab.dart';
import 'reports_tab.dart';

const double _desktopBreakpoint = 1100.0;
const Color _neumorphicBaseColor = Color(0xFFF0F2F5);

class OverseerPage extends StatefulWidget {
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;

  const OverseerPage({
    super.key,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
  });

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _TabDefinition {
  final String title;
  final IconData icon;
  final Widget widget;
  _TabDefinition(this.title, this.icon, this.widget);
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  Uint8List? _logoBytes;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _displayName = "Loading...";
  String _displayRole = "Overseer";
  String? faceUrl;
  bool _isLoadingProfile = true;

  String committeeMemberName = '';
  String committeeMemberRole = '';
  bool has_agreed_to_privacy = false;

  @override
  void initState() {
    super.initState();
    _loadLogoBytes();
    _initializeProfileData();
  }

  @override
  void dispose() {
    if (!_isLoadingProfile) {
      _tabController.dispose();
    }
    super.dispose();
  }

  bool get _isChairperson => committeeMemberRole.toLowerCase() == 'chairperson';

  bool get _isSignatory {
    final r = committeeMemberRole.toLowerCase().trim();
    return r == 'overseer' ||
        r == 'main overseer' ||
        r == 'district elder' ||
        r == 'treasurer' ||
        r == 'secretary';
  }

  void _initTabController() {
    int tabCount = 7; // Base tabs
    if (_isChairperson) tabCount++; // Songs Agreement
    if (_isSignatory) tabCount++; // Signatures
    tabCount += 2; // Audit, Billing

    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  List<_TabDefinition> _getTabs(bool isLargeScreen, String? secureFaceUrl) {
    final tabs = <_TabDefinition>[
      _TabDefinition(
        "Dashboard",
        Icons.dashboard,
        DashboardTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
      _TabDefinition(
        "Add Member",
        Icons.person_add,
        AddMemberTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
      _TabDefinition(
        "All Members",
        Icons.people,
        AllMembersTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
      _TabDefinition(
        "Digital Register",
        Icons.receipt_long,
        OverseerDigitalRegisterTab(
          isLargeScreen: isLargeScreen,
          loggerName: committeeMemberName,
          loggerRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
          neumoColor: _neumorphicBaseColor,
        ),
      ),
      _TabDefinition(
        "Add Committee",
        Icons.groups,
        AddCommitteeMemberTab(
          isLargeScreen: isLargeScreen,
          currentUserName: committeeMemberName,
          currentUserPortfolio: committeeMemberRole,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
      _TabDefinition(
        "Add Officer",
        Icons.admin_panel_settings,
        AddOfficerTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
      _TabDefinition(
        "Reports",
        Icons.receipt_long,
        ReportsTab(
          isLargeScreen: isLargeScreen,
          logoBytes: _logoBytes,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        ),
      ),
    ];

    if (_isChairperson) {
      tabs.add(
        _TabDefinition(
          "Songs Agreement",
          Icons.library_music,
          MusicContract(
            committeeMemberName: committeeMemberName,
            committeeMemberRole: committeeMemberRole,
            faceUrl: secureFaceUrl,
          ),
        ),
      );
    }

    if (_isSignatory) {
      tabs.add(
        _TabDefinition(
          "Signatures",
          Icons.draw,
          Signatures(
            isLargeScreen: isLargeScreen,
            committeeMemberName: committeeMemberName,
            committeeMemberRole: committeeMemberRole,
            faceUrl: secureFaceUrl,
          ),
        ),
      );
    }

    tabs.add(_TabDefinition("Audit Logs", Icons.security, OverseerAuditpage()));
    tabs.add(
      _TabDefinition(
        "Billing",
        Icons.subscriptions_outlined,
        SubscriptionInfo(),
      ),
    );

    return tabs;
  }

  String _getSecureImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  Future<bool> _showNeumorphicTermsDialog({required bool isCommittee}) async {
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
                      isCommittee
                          ? 'Audit & Privacy Agreement'
                          : 'Terms & Privacy',
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
                      isCommittee
                          ? 'As an appointed committee member, you must agree to our Terms of Use. By continuing, you consent that your actions within this portal are recorded in the system audit logs for security and tracking purposes.'
                          : 'As an overseer on Tact, you are required to agree to our Terms of Use and Privacy Policy to continue using the app. Please review and accept the terms to proceed.',
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

  Future<void> check_terms_of_use(dynamic overseerId) async {
    final agreed = await _showNeumorphicTermsDialog(isCommittee: false);
    if (agreed) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _handleLogout();
          return;
        }
        final String token = await user.getIdToken() ?? '';
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/$overseerId/',
        );

        final response = await http.patch(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'has_agreed_to_privacy': true}),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() => has_agreed_to_privacy = true);
        } else {
          await _handleLogout();
        }
      } catch (e) {
        await _handleLogout();
      }
    } else {
      await _handleLogout();
    }
  }

  Future<void> _checkCommitteeTerms(dynamic memberId) async {
    final agreed = await _showNeumorphicTermsDialog(isCommittee: true);
    if (agreed) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _handleLogout();
          return;
        }
        final String token = await user.getIdToken() ?? '';
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/$memberId/',
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
          await _handleLogout();
        }
      } catch (e) {
        await _handleLogout();
      }
    } else {
      await _handleLogout();
    }
  }

  void _showMissingSignatureAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _neumorphicBaseColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text(
              "Signature Required",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "We noticed you haven't set up your digital signature yet.\n\nPlease navigate to the Signatures tab to enter it now so you can authorize official documents and reports.\nIn simple terms a balancesheet needs you signature as a ${committeeMemberRole} to be valid and official.",
          style: TextStyle(
            color: Colors.grey.shade800,
            height: 1.5,
            fontSize: 15,
          ),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: _neumorphicBaseColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade400,
                  offset: Offset(4, 4),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-4, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final tabs = _getTabs(
                  MediaQuery.of(context).size.width >= _desktopBreakpoint,
                  faceUrl != null ? _getSecureImageUrl(faceUrl!) : null,
                );
                int sigIndex = tabs.indexWhere((t) => t.title == "Signatures");
                if (sigIndex != -1) {
                  setState(() {
                    _selectedIndex = sigIndex;
                    _tabController.animateTo(sigIndex);
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Go to Signatures",
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = await user.getIdToken() ?? '';
      final identifier = user.email ?? "";
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${Uri.encodeComponent(identifier)}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final List<dynamic> results = json.decode(response.body);
      if (results.isEmpty) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final overseerData = results[0];
      final overseerId = overseerData['id'];

      setState(() {
        has_agreed_to_privacy = overseerData['has_agreed_to_privacy'] ?? false;
      });

      String? faceUrlToCheck =
          widget.faceUrl ?? prefs.getString('session_faceUrl');
      bool isCommitteeMember = false;

      if (faceUrlToCheck != null) {
        final committeeUrl = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?overseer=$overseerId&face_url=${Uri.encodeComponent(faceUrlToCheck)}',
        );
        final commResponse = await http.get(
          committeeUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (commResponse.statusCode == 200) {
          final List<dynamic> commResults = json.decode(commResponse.body);
          if (commResults.isNotEmpty) {
            isCommitteeMember = true;
            final memberData = commResults[0];

            bool acceptedTsAndCs = memberData['accepted_ts_and_cs'] ?? false;
            if (!acceptedTsAndCs) {
              await _checkCommitteeTerms(memberData['id']);
            }

            final name =
                memberData['full_name'] ??
                memberData['name'] ??
                "Committee Member";
            final role = memberData['portfolio'] ?? "Committee";

            await prefs.setString('session_faceUrl', faceUrlToCheck);
            await prefs.setString('session_name', name);
            await prefs.setString('session_role', role);

            if (mounted) {
              committeeMemberName = name;
              committeeMemberRole = role;
              _initTabController();

              setState(() {
                _displayName = name;
                _displayRole = role;
                faceUrl = faceUrlToCheck;
                _isLoadingProfile = false;
              });

              // ⭐️ 1. Check if logged-in Committee Member needs to sign
              bool needsSignature = false;
              if (_isSignatory) {
                final sig = memberData['signature_base64'];
                if (sig == null || sig.toString().trim().isEmpty) {
                  needsSignature = true;
                }
              }
              if (needsSignature && mounted) {
                _showMissingSignatureAlert();
              }
            }
          }
        }
      }

      if (!isCommitteeMember) {
        if (!has_agreed_to_privacy) await check_terms_of_use(overseerId);

        await prefs.remove('session_faceUrl');
        await prefs.remove('session_name');
        await prefs.remove('session_role');

        String mainName =
            overseerData['overseer_initials_surname'] ?? "Main Overseer";
        String mainRole = "Main Overseer";
        String? mainFaceUrl =
            widget.faceUrl ??
            overseerData['chairperson_face_url'] ??
            overseerData['secretary_face_url'];

        if (mounted) {
          committeeMemberName = mainName;
          committeeMemberRole = mainRole;
          _initTabController();

          setState(() {
            _displayName = mainName;
            _displayRole = mainRole;
            faceUrl = mainFaceUrl;
            _isLoadingProfile = false;
          });

          // ⭐️ 2. Check if logged-in Main Overseer needs to sign
          bool needsSignature = false;
          if (_isSignatory) {
            final comRes = await http.get(
              Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?overseer=$overseerId',
              ),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (comRes.statusCode == 200) {
              final List comData = jsonDecode(comRes.body);
              bool foundSig = false;
              for (var m in comData) {
                if (m['portfolio'] == 'Overseer' ||
                    m['portfolio'] == 'Main Overseer') {
                  final sig = m['signature_base64'];
                  if (sig != null && sig.toString().trim().isNotEmpty) {
                    foundSig = true;
                  }
                  break;
                }
              }
              needsSignature = !foundSig;
            } else {
              needsSignature = true;
            }
          }

          if (needsSignature && mounted) {
            _showMissingSignatureAlert();
          }
        }
      }
    } catch (e) {
      print("❌ Error initializing profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() => _logoBytes = bytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= _desktopBreakpoint;

    if (_isLoadingProfile) {
      return const Scaffold(
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _neumorphicBaseColor,
      drawer: !isLargeScreen ? _buildMobileDrawer(context) : null,
      body: SafeArea(
        child: isLargeScreen
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        _buildSidebar(context),
        Expanded(
          child: Container(
            color: _neumorphicBaseColor,
            padding: const EdgeInsets.all(24),
            child: _buildBodyContent(true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;
    final tabs = _getTabs(false, secureFaceUrl);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: NeumorphicContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 12,
                  child: Icon(Icons.menu, color: Colors.grey[700]),
                ),
              ),
              Text(
                'Overseer Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              NeumorphicContainer(
                padding: const EdgeInsets.all(4),
                borderRadius: 30,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _neumorphicBaseColor,
                  backgroundImage: secureFaceUrl != null
                      ? NetworkImage(secureFaceUrl)
                      : null,
                  child: secureFaceUrl == null
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: tabs.asMap().entries.map((entry) {
              return _buildMobileTabItem(entry.key, entry.value.title);
            }).toList(),
          ),
        ),
        Expanded(
          child: Container(
            color: _neumorphicBaseColor,
            child: TabBarView(
              controller: _tabController,
              children: tabs.map((t) => t.widget).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabItem(int index, String title) {
    final bool isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _tabController.animateTo(index);
          });
        },
        child: NeumorphicContainer(
          isPressed: isSelected,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          borderRadius: 20,
          color: _neumorphicBaseColor,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(bool isLargeScreen) {
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;
    final tabs = _getTabs(isLargeScreen, secureFaceUrl);

    if (_selectedIndex >= 0 && _selectedIndex < tabs.length) {
      return tabs[_selectedIndex].widget;
    }
    return const Center(child: Text("Tab not found"));
  }

  Widget _buildSidebar(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;
    final tabs = _getTabs(true, secureFaceUrl);

    return Container(
      width: 280,
      color: _neumorphicBaseColor,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: NeumorphicContainer(
              isPressed: false,
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, primaryColor.withOpacity(0.1)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: _neumorphicBaseColor,
                      backgroundImage: secureFaceUrl != null
                          ? NetworkImage(secureFaceUrl)
                          : null,
                      child: secureFaceUrl == null
                          ? Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.grey[600],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _displayRole.toUpperCase(),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                ...tabs.asMap().entries.map((entry) {
                  return _buildSidebarItem(
                    entry.key,
                    entry.value.icon,
                    entry.value.title,
                  );
                }),
                const Divider(),
                _buildLogoutSidebarItem(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSidebarItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeumorphicContainer(
        isPressed: false,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            "Logout",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          onTap: _handleLogout,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedIndex = index;
          _tabController.index = index;
        }),
        child: NeumorphicContainer(
          isPressed: isSelected,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 12,
          color: isSelected ? _neumorphicBaseColor : _neumorphicBaseColor,
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryColor : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;
    return Drawer(
      backgroundColor: _neumorphicBaseColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          NeumorphicContainer(
            child: UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: Text(
                _displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_displayRole.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: secureFaceUrl != null
                    ? NetworkImage(secureFaceUrl)
                    : null,
                child: secureFaceUrl == null
                    ? Icon(Icons.person, color: Theme.of(context).primaryColor)
                    : null,
              ),
            ),
          ),
          NeumorphicContainer(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }
}
