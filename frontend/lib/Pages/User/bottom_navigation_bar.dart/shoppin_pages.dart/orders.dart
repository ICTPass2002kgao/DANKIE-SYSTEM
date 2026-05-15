// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String _userRole = 'customer';

  // State for Orders
  List<dynamic> _orders = [];
  bool _isLoading = true;

  final List<String> _orderStatuses = [
    'pending_payment',
    'paid',
    'processing',
    'shipped',
    'delivered',
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _initData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initData() async {
    await _fetchUserRole();
    await _fetchOrdersFromDjango();
  }

  // --- 1. Fetch User Role from Django (SECURED) ---
  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      // SECURE FIX: Get the token
      String? token = await _currentUser!.getIdToken();
      if (token == null) return;

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${_currentUser!.uid}',
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
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _userRole = data[0]['role'] ?? 'customer';
          });
        }
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
  }

  // --- 2. Fetch Orders from Django (SECURED) ---
  Future<void> _fetchOrdersFromDjango() async {
    setState(() => _isLoading = true);

    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // SECURE FIX: Get the token
      String? token = await _currentUser!.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        setState(() => _isLoading = false);
        return;
      }

      String endpoint = '/orders/';

      // Filter based on role
      if (_userRole == 'Seller') {
        // Assuming backend supports seller filtering, otherwise we filter locally
        endpoint += '?seller_uid=${_currentUser!.uid}';
      } else {
        endpoint += '?user_uid=${_currentUser!.uid}';
      }

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}$endpoint');

      // SECURE FIX: Add Authorization header
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedOrders = json.decode(response.body);

        // Sort by created_at desc (local sort if backend doesn't)
        fetchedOrders.sort((a, b) {
          DateTime dateA = DateTime.parse(a['created_at']);
          DateTime dateB = DateTime.parse(b['created_at']);
          return dateB.compareTo(dateA);
        });

        setState(() {
          _orders = fetchedOrders;
          _isLoading = false;
        });
      } else {
        print("Backend Error: ${response.statusCode} - ${response.body}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Connection Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- COLORS & STYLING ---
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blueAccent;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return isIOSPlatform ? CupertinoIcons.time : Icons.access_time;
      case 'paid':
        return isIOSPlatform
            ? CupertinoIcons.check_mark_circled
            : Icons.payment;
      case 'processing':
        return isIOSPlatform
            ? CupertinoIcons.arrow_2_circlepath
            : Icons.autorenew;
      case 'shipped':
        return isIOSPlatform ? CupertinoIcons.bus : Icons.local_shipping;
      case 'delivered':
        return isIOSPlatform
            ? CupertinoIcons.check_mark_circled
            : Icons.check_circle_outline;
      default:
        return isIOSPlatform ? CupertinoIcons.info : Icons.info_outline;
    }
  }

  // --- EMAIL LOGIC (Unchanged) ---
  void _handleContactSupport(
    BuildContext context,
    String sellerEmail,
    String orderId,
    String sellerName,
  ) {
    final TextEditingController messageController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color neumoBase = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: neumoBase,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Contact Seller",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Send a message regarding Order #$orderId",
                  style: TextStyle(color: theme.hintColor),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: neumoBase,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black : Colors.grey.shade400,
                        offset: Offset(4, 4),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        offset: Offset(-4, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Type your message here...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: _buildNeumorphicButton(
                        context,
                        label: "Cancel",
                        icon: Icons.close,
                        isPrimary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildNeumorphicButton(
                        context,
                        label: "Send",
                        icon: Icons.send_rounded,
                        isPrimary: true,
                        onTap: () {
                          _sendSupportEmail(
                            sellerEmail,
                            orderId,
                            messageController.text,
                            sellerName,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendSupportEmail(
    String sellerEmail,
    String orderId,
    String message,
    String sellerName,
  ) {
    if (message.trim().isEmpty) {
      Api().showMessage(
        context,
        "Message cannot be empty",
        "Error",
        Colors.red,
      );
      return;
    }
    final recipient = (sellerEmail.isNotEmpty)
        ? sellerEmail
        : "support@dankie.com";
    final buyerEmail = _currentUser?.email ?? "Unknown User";
    final buyerName = _currentUser?.displayName ?? "A Customer";

    Api().sendEmail(recipient, 'Inquiry regarding Order #$orderId', """
      <p>Hello $sellerName,</p>
      <p>You have received a new inquiry from a customer regarding <strong>Order #$orderId</strong>.</p>
      <p><strong>Customer:</strong> $buyerName ($buyerEmail)</p>
      <hr />
      <p><strong>Message:</strong></p>
      <blockquote style="background: #f9f9f9; border-left: 5px solid #ccc; margin: 1.5em 10px; padding: 0.5em 10px;">
        $message
      </blockquote>
      <hr />
      <p>Please respond to the customer as soon as possible.</p>
      """, context);
  }

  Widget _buildNeumorphicButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isPrimary
        ? theme.primaryColor
        : Color.alphaBlend(
            theme.primaryColor.withOpacity(0.08),
            theme.scaffoldBackgroundColor,
          );
    final textColor = isPrimary ? Colors.white : theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.4),
              offset: Offset(4, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (_currentUser == null) {
      return _buildLoggedOutPage(theme, neumoBaseColor);
    }

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildNeumorphicAppBar(context, theme, neumoBaseColor),
            Expanded(
              child: _userRole == 'Seller'
                  ? _buildSellerOrdersList(theme, neumoBaseColor)
                  : _buildCustomerOrdersList(theme, neumoBaseColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicAppBar(
    BuildContext context,
    ThemeData theme,
    Color baseColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: baseColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            offset: Offset(0, 10),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.4),
                    offset: Offset(4, 4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                isIOSPlatform ? CupertinoIcons.back : Icons.arrow_back_rounded,
                color: theme.hintColor,
                size: 22,
              ),
            ),
          ),
          Text(
            _userRole == 'Seller' ? 'MY SALES' : 'YOUR ORDERS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLoggedOutPage(ThemeData theme, Color baseColor) {
    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: theme.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              "Access Restricted",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            SizedBox(height: 30),
            Container(
              width: 200,
              child: _buildNeumorphicButton(
                context,
                label: "Login Now",
                icon: Icons.login,
                onTap: () => Navigator.pushNamed(context, '/login'),
                isPrimary: true,
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerOrdersList(ThemeData theme, Color baseColor) {
    if (_isLoading) {
      return Center(
        child: isIOSPlatform
            ? CupertinoActivityIndicator()
            : CircularProgressIndicator(),
      );
    }
    if (_orders.isEmpty) {
      return _buildEmptyState(theme, baseColor);
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: ListView.builder(
          padding: const EdgeInsets.all(20.0),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            return _buildNeumorphicOrderTile(
              context,
              _orders[index],
              theme,
              baseColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerOrdersList(ThemeData theme, Color baseColor) {
    if (_isLoading) {
      return Center(
        child: isIOSPlatform
            ? CupertinoActivityIndicator()
            : CircularProgressIndicator(),
      );
    }
    if (_orders.isEmpty) {
      return _buildEmptyState(theme, baseColor, isSeller: true);
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: ListView.builder(
          padding: const EdgeInsets.all(20.0),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];

            // In Django, 'items' is the list.
            // We need to filter items that belong to this seller if the API returns mixed items
            // final items = order['items'] as List<dynamic>?;

            return _buildNeumorphicOrderTile(context, order, theme, baseColor);
          },
        ),
      ),
    );
  }

  // ⭐️ NEUMORPHIC ORDER TILE (Updated keys for Django) ⭐️
  Widget _buildNeumorphicOrderTile(
    BuildContext context,
    Map<String, dynamic> order,
    ThemeData theme,
    Color baseColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    // Map Django keys
    final String status = order['status'] ?? 'pending';
    final String orderReference = order['id'].toString().substring(0, 8);

    DateTime? createdAt;
    if (order['created_at'] != null) {
      createdAt = DateTime.parse(order['created_at']);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.grey.withOpacity(0.4),
            offset: Offset(5, 5),
            blurRadius: 15,
          ),
          BoxShadow(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 15,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$orderReference',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  _buildStatusBadge(status, theme),
                ],
              ),
              SizedBox(height: 8),
              Text(
                createdAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
                    : 'N/A',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          children: [_buildOrderDetails(context, order, orderReference)],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase().replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
    BuildContext context,
    Map<String, dynamic> order,
    String orderReference,
  ) {
    final theme = Theme.of(context);

    // Map Django 'items' to products list
    final List<dynamic> products = order['items'] ?? [];
    final String status = order['status'] ?? 'unknown';
    // Map Django 'total_amount'
    final double totalAmount =
        double.tryParse(order['total_amount'].toString()) ?? 0.0;

    // Django 'needs_delivery'
    final bool needsDelivery = order['needs_delivery'] ?? false;

    // TODO: Ideally fetch Seller Email from the Order Item relations
    String sellerEmail = '';
    String sellerName = 'Seller';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.hintColor.withOpacity(0.1)),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: OrderStatusTracker(
              currentStatus: status,
              allStatuses: _orderStatuses,
              needsDelivery: needsDelivery,
              getStatusIcon: _getStatusIcon,
              getStatusColor: _getStatusColor,
              baseColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          Divider(color: theme.hintColor.withOpacity(0.1)),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, prodIndex) {
              final product = products[prodIndex];

              // Note: Adjust these keys if your Serializer nested the product data
              // e.g. product['product']['image_url']

              String imageUrl = product['product_image'] ?? '';
              // If API sends full product object:
              // String imageUrl = product['product']['image_url'] ?? '';

              String productName = product['product_name'] ?? 'Item';
              double price =
                  double.tryParse(product['price'].toString()) ?? 0.0;
              int qty = int.tryParse(product['quantity'].toString()) ?? 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.image_not_supported, size: 20),
                              )
                            : Icon(
                                Icons.shopping_bag,
                                size: 20,
                                color: theme.hintColor,
                              ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${product['color'] ?? '-'} / ${product['size'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'x$qty',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                        Text(
                          'R${(price * qty).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Amount", style: TextStyle(color: theme.hintColor)),
              Text(
                "R${totalAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          _buildNeumorphicButton(
            context,
            label: "Contact Seller",
            icon: Icons.mail_outline_rounded,
            isPrimary: true,
            onTap: () => _handleContactSupport(
              context,
              sellerEmail,
              orderReference,
              sellerName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    Color baseColor, {
    bool isSeller = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: Offset(5, 5),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-5, -5),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(
              isSeller
                  ? Icons.storefront_outlined
                  : Icons.shopping_bag_outlined,
              size: 60,
              color: theme.primaryColor.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 25),
          Text(
            isSeller ? "No Sales Yet" : "No Orders Yet",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            isSeller
                ? "Your sales history will appear here."
                : "Start exploring amazing products!",
            style: TextStyle(color: theme.hintColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// ⭐️ UPDATED STATUS TRACKER ⭐️
class OrderStatusTracker extends StatelessWidget {
  final String currentStatus;
  final List<String> allStatuses;
  final bool needsDelivery;
  final Function(String) getStatusIcon;
  final Function(String) getStatusColor;
  final Color baseColor;

  const OrderStatusTracker({
    super.key,
    required this.currentStatus,
    required this.allStatuses,
    required this.needsDelivery,
    required this.getStatusIcon,
    required this.getStatusColor,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStatus.toLowerCase() == 'cancelled') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'ORDER CANCELLED',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
      );
    }

    List<String> displayStatuses = allStatuses.where((status) {
      if (needsDelivery) {
        return status != 'ready_for_pickup';
      } else {
        return status != 'shipped' && status != 'delivered';
      }
    }).toList();

    final int displayCurrentStatusIndex = displayStatuses.indexOf(
      currentStatus.toLowerCase(),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(displayStatuses.length, (index) {
        final status = displayStatuses[index];
        final bool isActive = index <= displayCurrentStatusIndex;
        final Color activeColor = getStatusColor(status);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? activeColor : baseColor,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: isDark
                                ? Colors.grey.withOpacity(0.1)
                                : Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                        ],
                ),
                child: Icon(
                  getStatusIcon(status),
                  color: isActive ? Colors.white : Colors.grey[400],
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status.toUpperCase().replaceAll('_', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive ? activeColor : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
