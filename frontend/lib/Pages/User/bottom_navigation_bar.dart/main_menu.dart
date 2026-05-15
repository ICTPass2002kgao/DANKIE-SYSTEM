// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'dart:async'; // Required for Timer
import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Pages/User/profile.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/marketplace.dart';
import 'package:ttact/Pages/User/Seller/seller_main.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/orders.dart';
import 'events.dart';
import 'history_page.dart';
import 'home/home_page.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class MotherPage extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final int initialIndex;

  const MotherPage({
    super.key,
    required this.onToggleTheme,
    this.initialIndex = 0,
  });

  static final ValueNotifier<String?> deepLinkSongIdNotifier =
      ValueNotifier<String?>(null);

  @override
  State<MotherPage> createState() => _MotherPageState();
}

class _MotherPageState extends State<MotherPage>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _isSeller = false;
  late AppLinks _appLinks;
  Map<String, dynamic> _userData = {};

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TextEditingController issueTitle = TextEditingController();
  TextEditingController issueDescription = TextEditingController();
  // bool get _isMobileWeb => kIsWeb && !isLargeScreen(context); // Unused currently

  // ⭐️ SCROLL VISIBILITY STATE
  bool _isBottomNavVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    fetchUserData();
    _initDeepLinks();
  }

  // --- DEEP LINK LOGIC ---
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleDeepLink(uri);
      _appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint("Deep link error: $e");
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/song')) {
      final songUrl = uri.queryParameters['url'];
      if (songUrl != null) {
        setState(() => _currentIndex = 0);
        Future.delayed(Duration(milliseconds: 100), () {
          MotherPage.deepLinkSongIdNotifier.value = songUrl;
        });
      }
    }
  }

  // --- USER DATA & ROLE LOGIC (SECURED) ---

  void _reportIssue() async {
    if (issueTitle.text.isEmpty || issueDescription.text.isEmpty) {
      Api().showMessage(
        context,
        "Validation Error",
        "Please fill in both the title and description.",
        Colors.orangeAccent,
      );
      return;
    }

    // SECURE FIX: Grab the current user and their token
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Api().showMessage(
        context,
        "Not Logged In",
        "Please log in to report an issue.",
        Colors.redAccent,
      );
      return;
    }

    try {
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Could not retrieve Auth Token");

      final url = Uri.parse("${Api().BACKEND_BASE_URL_DEBUG}/issue_report/");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // SECURE FIX: Inject token
        },
        body: jsonEncode({
          'title': issueTitle.text,
          'description': issueDescription.text,
          'reported_by':
              '${_userData['name'] ?? ''} ${_userData['surname'] ?? ''}'.trim(),
        }),
      );

      if (response.statusCode == 201) {
        print("Issue reported successfully");
        issueTitle.clear();
        issueDescription.clear();
        Api().showMessage(
          context,
          "Submitted",
          "We received your report.",
          Colors.green,
        );
      } else {
        print("Failed to report issue: ${response.statusCode}");
        Api().showMessage(
          context,
          "Error",
          "Failed to submit your report. Please try again later.",
          Colors.redAccent,
        );
      }
    } catch (e) {
      debugPrint("Error reporting issue: $e");
    }
  }

  Future<void> fetchUserData() async {
    // SECURE FIX: Grab current user dynamically
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSeller = false);
      return;
    }

    try {
      String? token = await user.getIdToken();
      if (token == null) return;

      // Query Django API for user profile by UID
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // SECURE FIX: Inject token
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final data = results[0];

          String role = data['role']?.toString().toLowerCase() ?? '';

          // ROLE CHECK: If not member or seller, return to login
          if (!role.contains('member') && role != 'seller') {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
            return;
          }

          if (mounted) {
            setState(() {
              _userData = data;
              _isSeller = _userData['role'] == 'Seller';

              // Adjust index if role changes permissions
              if (_isSeller) {
                if (_currentIndex > 4) _currentIndex = 4;
              } else {
                if (_currentIndex > 3) _currentIndex = 0;
              }
            });

            // GENDER CHECK: Trigger Neumorphic Pop-up if gender is missing
            String? gender = _userData['gender'];
            if (gender == null || gender.toString().trim().isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showGenderSelectionPopup();
              });
            }
          }
        }
      } else {
        print(
          "Failed to fetch user data: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Error fetching user data from Django: $e");
    }
  }

  void _showGenderSelectionPopup() {
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    String? localSelectedGender;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Forces the user to make a selection
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: NeumorphicContainer(
                color: neumoBaseColor,
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.person_pin_circle_outlined,
                      size: 60,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Complete Your Profile",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please select your gender to continue using the application.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    _buildGenderOption(
                      "Male",
                      localSelectedGender == "Male",
                      neumoBaseColor,
                      theme,
                      () {
                        setStateDialog(() => localSelectedGender = "Male");
                      },
                    ),
                    _buildGenderOption(
                      "Female",
                      localSelectedGender == "Female",
                      neumoBaseColor,
                      theme,
                      () {
                        setStateDialog(() => localSelectedGender = "Female");
                      },
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: localSelectedGender == null || isSaving
                          ? null
                          : () async {
                              setStateDialog(() => isSaving = true);
                              await _updateGender(localSelectedGender!);
                              if (mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                      child: NeumorphicContainer(
                        color: localSelectedGender == null
                            ? theme.hintColor.withOpacity(0.3)
                            : theme.primaryColor,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: isSaving
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "SAVE & CONTINUE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
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

  Widget _buildGenderOption(
    String text,
    bool isSelected,
    Color baseColor,
    ThemeData theme,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: NeumorphicContainer(
          color: isSelected ? theme.primaryColor : baseColor,
          isPressed: isSelected,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateGender(String gender) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? token = await user.getIdToken();
      String? userId = _userData['uid'];

      if (userId == null) return;

      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/$userId/');

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'gender': gender}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _userData['gender'] = gender;
        });
      } else {
        print(
          "Failed to update gender: ${response.statusCode} - ${response.body}",
        );
        Api().showMessage(
          context,
          "Error",
          "Could not save gender. Please try again.",
          Colors.red,
        );
      }
    } catch (e) {
      print("Error updating gender: $e");
      Api().showMessage(
        context,
        "Error",
        "A network error occurred.",
        Colors.red,
      );
    }
  }

  void _handleThemeChange(bool isDark) async {
    widget.onToggleTheme(isDark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      debugPrint("Error saving theme: $e");
    }
  }

  List<Map<String, dynamic>> _getNavItems() {
    List<Map<String, dynamic>> items = [
      {'icon': Ionicons.home_outline, 'label': 'Home'},
      {'icon': Ionicons.calendar_outline, 'label': 'Events'},
      {'icon': Icons.local_mall_outlined, 'label': 'Shopping'},
      {'icon': Icons.history_outlined, 'label': 'History'},
    ];
    if (_isSeller) {
      items.add({'icon': Ionicons.storefront_outline, 'label': 'My Shop'});
    }
    return items;
  }

  // --- SHARED LEGAL LAUNCHER ---
  Future<void> _launchLegalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  // --- DYNAMIC GREETING LOGIC ---
  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // Subtle tint for that premium "off-white" or "deep-dark" look
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    List<Widget> pages = [
      HomePage(),
      EventsPage(),
      ShoppingPage(),
      HistoryPage(),
      if (_isSeller) SellerProductPage(),
    ];

    if (_currentIndex >= pages.length) _currentIndex = 0;

    if (isDesktop) {
      return _buildDesktopLayout(theme, neumoBaseColor, pages[_currentIndex]);
    } else {
      return _buildMobileLayout(theme, neumoBaseColor, pages[_currentIndex]);
    }
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
      drawer: _buildNeumorphicMobileDrawer(theme, neumoBaseColor),
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ⭐️ THE NEW WOW APP BAR ⭐️
                _buildWowAppBar(theme, neumoBaseColor),

                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (_isBottomNavVisible)
                          setState(() => _isBottomNavVisible = false);
                      } else if (notification.direction ==
                          ScrollDirection.forward) {
                        if (!_isBottomNavVisible)
                          setState(() => _isBottomNavVisible = true);
                      }
                      return true;
                    },
                    child: content,
                  ),
                ),
              ],
            ),
          ),

          // --- ANIMATED NEUMORPHIC DOCK ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _isBottomNavVisible ? Offset(0, 0) : Offset(0, 1.2),
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdManager().bannerAdWidget(),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 25,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildNavItem(Ionicons.home_outline, 0, theme),
                          _buildNavItem(Ionicons.calendar_outline, 1, theme),
                          _buildNavItem(Icons.local_mall_outlined, 2, theme),
                          _buildNavItem(Icons.history_outlined, 3, theme),
                          if (_isSeller)
                            _buildNavItem(
                              Ionicons.storefront_outline,
                              4,
                              theme,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, ThemeData theme) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.4),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : theme.hintColor.withOpacity(0.6),
          size: 24,
        ),
      ),
    );
  }

  // ===========================================================================
  // ⭐️⭐️ NEW PREMIUM "WOW" APP BAR ⭐️⭐️
  // ===========================================================================
  Widget _buildWowAppBar(ThemeData theme, Color neumoBaseColor) {
    final Color contentColor = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.primaryColor;

    bool isHomePage = _currentIndex == 0;
    bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    // Greeting Logic
    String topLine = "";
    String bottomLine = "";

    if (isHomePage) {
      topLine = _getGreeting();
      String name = _userData['name'] ?? 'Guest';
      bottomLine = name.length > 15 ? "${name.substring(0, 15)}..." : name;
    } else {
      topLine = "Browsing";
      bottomLine = _getNavItems()[_currentIndex]['label'].toUpperCase();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- 1. LEFT: MENU TOGGLE (Animated) ---
            _buildNeuIconButton(
              icon: Ionicons.grid_outline,
              color: contentColor,
              onTap: () {
                HapticFeedback.mediumImpact();
                _scaffoldKey.currentState?.openDrawer();
              },
              baseColor: neumoBaseColor,
            ),

            // --- 2. CENTER: DYNAMIC TITLE ---
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topLine.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: contentColor.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 2),
                  // GRADIENT TEXT
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [theme.primaryColor, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      bottomLine,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white, // Required for shader
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- 3. RIGHT: ACTIONS (Cart / Profile) ---
            if (!_isSeller && isLoggedIn)
              _buildNeuIconButton(
                icon: Icons.shopping_bag_outlined,
                color: contentColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OrdersPage()),
                  );
                },
                baseColor: neumoBaseColor,
                hasBadge: true, // Show a little red dot
              )
            else if (isLoggedIn)
              // If user is logged in but no cart needed, show Profile Avatar
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(
                  color: neumoBaseColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: -Offset(3, 3),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: Offset(1, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      "${_userData['name'] ?? ''} ${_userData['surname'] ?? ''}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(width: 45), // Spacer
          ],
        ),
      ),
    );
  }

  // --- HELPER: ANIMATED NEUMORPHIC ICON BUTTON ---
  Widget _buildNeuIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Color baseColor,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
          // The "Wow" Shadows
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              offset: Offset(2, 2),
              blurRadius: 2,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            if (hasBadge)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 🖥️ DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    ThemeData theme,
    Color neumoBaseColor,
    Widget content,
  ) {
    bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Row(
        children: [
          _buildNeumorphicNavigationRail(theme, neumoBaseColor),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 80,
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getNavItems()[_currentIndex]['label'],
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _handleThemeChange(
                              theme.brightness == Brightness.light,
                            ),
                            child: NeumorphicContainer(
                              color: neumoBaseColor,
                              padding: EdgeInsets.all(10),
                              borderRadius: 50,
                              child: Icon(
                                theme.brightness == Brightness.light
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 20),
                          if (isLoggedIn)
                            NeumorphicContainer(
                              color: neumoBaseColor,
                              borderRadius: 50,
                              padding: EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.primaryColor,
                                child: Text(
                                  (_userData['name'] ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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

  Widget _buildNeumorphicNavigationRail(ThemeData theme, Color neumoBaseColor) {
    return Container(
      width: 260,
      color: neumoBaseColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                NeumorphicContainer(
                  color: neumoBaseColor,
                  borderRadius: 100,
                  padding: EdgeInsets.all(15),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage('assets/dankie_logo.PNG'),
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Dankie Mobile",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                ..._getNavItems().asMap().entries.map((entry) {
                  int idx = entry.key;
                  var item = entry.value;
                  bool isSelected = _currentIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = idx),
                      child: NeumorphicContainer(
                        color: isSelected ? theme.primaryColor : neumoBaseColor,
                        borderRadius: 15,
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'],
                              color: isSelected
                                  ? Colors.white
                                  : theme.hintColor.withOpacity(0.7),
                              size: 22,
                            ),
                            SizedBox(width: 15),
                            Text(
                              item['label'],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : theme.hintColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildSidebarAction(
                  theme,
                  neumoBaseColor,
                  Icons.person_outline,
                  "Profile",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyProfile()),
                  ),
                ),
                SizedBox(height: 10),
                _buildSidebarAction(
                  theme,
                  neumoBaseColor,
                  Icons.description_outlined,
                  "Terms & Conditions",
                  () => _launchLegalUrl(
                    "https://dankie-website.web.app/terms_and_conditions.html",
                  ),
                ),
                SizedBox(height: 10),
                _buildSidebarAction(
                  theme,
                  neumoBaseColor,
                  Icons.privacy_tip_outlined,
                  "Privacy Policy",
                  () => _launchLegalUrl(
                    "https://dankie-website.web.app/privacy_policy.html",
                  ),
                ),
                SizedBox(height: 10),
                _buildSidebarAction(
                  theme,
                  neumoBaseColor,
                  Icons.logout,
                  "Logout",
                  () => _logout(context),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarAction(
    ThemeData theme,
    Color baseColor,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: baseColor,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : theme.hintColor,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : theme.hintColor,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- MOBILE DRAWER (With Dark Mode Switcher) ---
  Widget _buildNeumorphicMobileDrawer(ThemeData theme, Color neumoBaseColor) {
    return Drawer(
      backgroundColor: neumoBaseColor,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 60, bottom: 30),
            width: double.infinity,
            child: Column(
              children: [
                NeumorphicContainer(
                  color: neumoBaseColor,
                  borderRadius: 100,
                  padding: EdgeInsets.all(15),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage('assets/dankie_logo.PNG'),
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Dankie Mobile",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildDrawerTile(
                  theme,
                  neumoBaseColor,
                  Ionicons.person_outline,
                  "Profile",
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProfile()),
                    );
                  },
                ),
                _buildDrawerTile(
                  theme,
                  neumoBaseColor,
                  theme.brightness == Brightness.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  theme.brightness == Brightness.light
                      ? "Dark Mode"
                      : "Light Mode",
                  () =>
                      _handleThemeChange(theme.brightness == Brightness.light),
                ),
                Divider(color: theme.hintColor.withOpacity(0.2)),
                _buildDrawerTile(
                  theme,
                  neumoBaseColor,
                  Icons.description_outlined,
                  "Terms & Conditions",
                  () => _launchLegalUrl(
                    "https://dankie-website.web.app/terms_and_conditions.html",
                  ),
                ),
                _buildDrawerTile(
                  theme,
                  neumoBaseColor,
                  Icons.shield_outlined,
                  "Privacy Policy",
                  () => _launchLegalUrl(
                    "https://dankie-website.web.app/privacy_policy.html",
                  ),
                ),
                _buildDrawerTile(
                  theme,
                  neumoBaseColor,
                  Icons.help_outline,
                  "Report Issue",
                  () {
                    Navigator.pop(context);
                    _showHelpBottomSheet();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GestureDetector(
              onTap: () => _logout(context),
              child: NeumorphicContainer(
                color: neumoBaseColor,
                borderRadius: 15,
                padding: EdgeInsets.symmetric(vertical: 16),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
    ThemeData theme,
    Color baseColor,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
          color: baseColor,
          borderRadius: 12,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.hintColor),
              SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGOUT & HELP ---
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // REMOVED: await prefs.remove('authToken'); Firebase handles this!
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showHelpBottomSheet() {
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: neumoBaseColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 30,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report an Issue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            NeumorphicContainer(
              color: neumoBaseColor,
              isPressed: true,
              borderRadius: 12,
              child: TextField(
                controller: issueTitle,
                decoration: InputDecoration(
                  hintText: 'Subject',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
              ),
            ),
            SizedBox(height: 15),
            NeumorphicContainer(
              color: neumoBaseColor,
              isPressed: true,
              borderRadius: 12,
              child: TextField(
                controller: issueDescription,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
              ),
            ),
            SizedBox(height: 25),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _reportIssue();
              },
              child: NeumorphicContainer(
                color: theme.primaryColor,
                borderRadius: 12,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
