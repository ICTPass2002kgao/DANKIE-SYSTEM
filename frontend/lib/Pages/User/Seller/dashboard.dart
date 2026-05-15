// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerDashboardTab extends StatefulWidget {
  final String userId;
  final Color baseColor;

  const SellerDashboardTab({
    super.key,
    required this.userId,
    required this.baseColor,
  });

  @override
  State<SellerDashboardTab> createState() => _SellerDashboardTabState();
}

class _SellerDashboardTabState extends State<SellerDashboardTab> {
  // Stats Variables
  double totalRevenue = 0.0;
  int totalOrders = 0;
  int totalProducts = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // SECURE FIX: Get the current Firebase user and their ID Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // --- 1. Fetch Inventory (For Product Count) ---
      final invUri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/seller-inventory/?seller_uid=${widget.userId}',
      );
      
      // SECURE FIX: Added Authorization headers
      final invResponse = await http.get(invUri, headers: headers);
      List<dynamic> products = [];

      if (invResponse.statusCode == 200) {
        final dynamic data = json.decode(invResponse.body);
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          products = data['results'];
        } else if (data is List) {
          products = data;
        }
      } else {
        print("Inventory Auth Error: ${invResponse.statusCode}");
      }

      // --- 2. Fetch Orders (For Revenue & Order Count) ---
      final orderUri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/orders/');
      
      // SECURE FIX: Added Authorization headers
      final orderResponse = await http.get(orderUri, headers: headers);
      List<dynamic> orders = [];

      if (orderResponse.statusCode == 200) {
        final dynamic data = json.decode(orderResponse.body);
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          orders = data['results'];
        } else if (data is List) {
          orders = data;
        }
      } else {
        print("Orders Auth Error: ${orderResponse.statusCode}");
      }

      // --- 3. Calculate Stats ---
      double tempRevenue = 0.0;

      for (var order in orders) {
        // Django OrderSerializer returns 'items' list
        final items = order['items'] as List? ?? [];

        for (var item in items) {
          // Parse fields from Django OrderItemSerializer
          final double price = double.tryParse(item['price'].toString()) ?? 0.0;
          final int qty = int.tryParse(item['quantity'].toString()) ?? 1;

          // In a real scenario, check if item['product_id'] belongs to this seller.
          // For now, assuming filtered orders or calculating raw total:
          tempRevenue += (price * qty);
        }
      }

      if (mounted) {
        setState(() {
          totalOrders = orders.length;
          totalProducts = products.length;
          totalRevenue = tempRevenue;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Dashboard Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Overview",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
              SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        _buildStatCard(
                          theme,
                          "Total Revenue",
                          "R${totalRevenue.toStringAsFixed(2)}",
                          Icons.attach_money,
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                theme,
                                "Orders",
                                "$totalOrders",
                                Icons.shopping_bag,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: _buildStatCard(
                                theme,
                                "Products",
                                "$totalProducts",
                                Icons.inventory_2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            theme,
                            "Total Revenue",
                            "R${totalRevenue.toStringAsFixed(2)}",
                            Icons.attach_money,
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _buildStatCard(
                            theme,
                            "Total Orders",
                            "$totalOrders",
                            Icons.shopping_bag,
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _buildStatCard(
                            theme,
                            "Active Products",
                            "$totalProducts",
                            Icons.inventory_2,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),

              SizedBox(height: 40),

              Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                ),
              ),
              SizedBox(height: 15),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      context,
                      theme,
                      "Withdraw Funds",
                      Icons.account_balance_wallet,
                      () {
                        Api().showMessage(
                          context,
                          "Withdrawals coming soon",
                          "Info",
                          theme.primaryColor,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: _buildActionBtn(
                      context,
                      theme,
                      "Store Settings",
                      Icons.settings,
                      () {
                        Api().showMessage(
                          context,
                          "Settings coming soon",
                          "Info",
                          theme.primaryColor,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(25),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: theme.brightness == Brightness.dark,
        radius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: theme.primaryColor, size: 28),
              // Subtle dot to indicate 'live' status
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: NeumorphicUtils.decoration(
          context: context,
          isDark: theme.brightness == Brightness.dark,
          radius: 15,
          isPressed: false,
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.hintColor),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}