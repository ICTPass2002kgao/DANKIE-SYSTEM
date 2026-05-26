// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';
import 'package:ttact/Pages/User/Seller/dashboard.dart';
import 'package:ttact/Pages/User/Seller/seller_add_products.dart';
import 'package:ttact/Pages/User/Seller/seller_my_products.dart';
import 'package:ttact/Pages/User/Seller/seller_orders.dart';

const double _desktopBreakpoint = 900.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class SellerProductPage extends StatefulWidget {
  const SellerProductPage({super.key});

  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  final user = FirebaseAuth.instance.currentUser;
  bool isVerified = false;
  Map<String, dynamic> userData = {};
  bool isLoading = true;

  // 1. Create a Key to access the MyProducts Tab State
  final GlobalKey<SellerMyProductsTabState> _myProductsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentIndex) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
    fetchCurrentUser();
  }

  // --- ⭐️ FETCH USER DATA (SECURED) ---
  Future<void> fetchCurrentUser() async {
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }
    try {
      // SECURE FIX: Get the token
      String? token = await user!.getIdToken();
      if (token == null) {
        setState(() => isLoading = false);
        return;
      }

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user!.uid}',
      );
      
      // SECURE FIX: Add Authorization header
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
          final data = results[0] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              userData = data;
              isVerified = data['account_verified'] ?? false;
              isLoading = false;
            });
          }
        } else {
          setState(() => isLoading = false);
        }
      } else {
        print("User Profile Auth Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (user == null) {
      return Scaffold(
        backgroundColor: baseColor,
        body: const Center(child: Text("Please Log In")),
      );
    }

    return Scaffold(
      backgroundColor: baseColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildNeumorphicTabSwitcher(context, theme),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        SellerDashboardTab(
                          userId: user!.uid,
                          baseColor: baseColor,
                        ),

                        // 2. Assign the Key here
                        SellerMyProductsTab(
                          key: _myProductsKey,
                          userId: user!.uid,
                          baseColor: baseColor,
                        ),

                        // 3. Pass the Callback here
                        SellerAddProductTab(
                          userId: user!.uid,
                          isVerified: isVerified,
                          userData: userData,
                          onSaveSuccess: () {
                            // A. Switch to "My Products" tab (Index 1)
                            _tabController.animateTo(1);

                            // B. Refresh the list immediately
                            // We wait a tiny bit to ensure the tab is built/visible
                            Future.delayed(Duration(milliseconds: 300), () {
                              _myProductsKey.currentState?.fetchInventory();
                            });

                            // C. Show success message
                            Api().showMessage(
                              context,
                              "Added to Inventory!",
                              "Success",
                              Colors.green,
                            );
                          },
                        ),

                        SellerOrdersTab(
                          userId: user!.uid,
                          isVerified: isVerified,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicTabSwitcher(BuildContext context, ThemeData theme) {
    final tabs = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dash'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Items'}, // Index 1
      {'icon': Icons.add_circle_rounded, 'label': 'Add'}, // Index 2
      {'icon': Icons.receipt_long_rounded, 'label': 'Sales'},
    ];

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: NeumorphicUtils.decoration(
                  context: context,
                  radius: 12,
                  isPressed: isSelected,
                  isDark: theme.brightness == Brightness.dark,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected ? theme.primaryColor : theme.hintColor,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.primaryColor
                            : theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}