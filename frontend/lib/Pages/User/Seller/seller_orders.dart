// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerOrdersTab extends StatefulWidget {
  final String userId;
  final bool isVerified;

  const SellerOrdersTab({
    super.key,
    required this.userId,
    required this.isVerified,
  });

  @override
  State<SellerOrdersTab> createState() => _SellerOrdersTabState();
}

class _SellerOrdersTabState extends State<SellerOrdersTab> {
  bool isLoading = true;
  List<dynamic> orders = [];

  // Controller for the communication message
  final TextEditingController _messageController = TextEditingController();

  final List<String> orderStatuses = [
    'pending',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // --- 1. API: Fetch Orders (SECURED) ---
  Future<void> fetchOrders() async {
    try {
      // SECURE FIX: Get the current user and their ID Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      String? token = await user.getIdToken();
      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/orders/');

      // SECURE FIX: Added Authorization headers
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            orders = json.decode(response.body);
            isLoading = false;
          });
        }
      } else {
        print("Error fetching orders: ${response.statusCode}");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      print("Exception fetching orders: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 2. API: Update Status (SECURED) ---
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    if (!widget.isVerified) {
      Api().showMessage(context, "Account not verified", "Error", Colors.red);
      return;
    }

    Api().showLoading(context);

    try {
      // SECURE FIX: Get current Firebase user and Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/orders/$orderId/');

      // SECURE FIX: Added Authorization header to PATCH request
      final response = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': newStatus}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss Loading

      if (response.statusCode == 200) {
        Api().showMessage(context, "Status Updated", "Success", Colors.green);
        fetchOrders(); // Refresh list
      } else {
        print("Update Error: ${response.body}");
        Api().showMessage(
          context,
          "Failed to update status: ${response.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  // --- 3. API: Send Message to Customer ---
  Future<void> sendMessageToCustomer(
    String orderId,
    String email,
    String message,
  ) async {
    Api().showLoading(context);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      // Requires a backend endpoint to process and deliver the message
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/orders/$orderId/send_message/',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'customer_email': email, 'message': message}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss Loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        Api().showMessage(context, "Message Sent", "Success", Colors.green);
      } else {
        Api().showMessage(
          context,
          "Failed to send message: ${response.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(child: Text("No Orders Yet"));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) =>
                    _buildOrderCard(orders[index], index),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: orders.length,
                itemBuilder: (context, index) =>
                    _buildOrderCard(orders[index], index),
              ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, int index) {
    final orderId = data['id'].toString();
    final status = data['status'] ?? 'pending';
    final accentColor = NeumorphicUtils.getAccentColor(index);
    final customerEmail = data['email'] ?? 'N/A';

    final List<dynamic> items = data['items'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        radius: 12,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  title: Text(
                    "Order #${orderId.substring(0, min(8, orderId.length))}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            height: 20,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          _buildDetailRow("Customer", customerEmail),
                          _buildDetailRow("Address", data['address'] ?? 'N/A'),
                          _buildDetailRow("Total", "R${data['total_amount']}"),

                          const SizedBox(height: 10),
                          const Text(
                            "Items:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                top: 2.0,
                              ),
                              child: Text(
                                "${item['quantity']}x ${item['product_name']}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      _showStatusDialog(orderId, status),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: NeumorphicUtils.decoration(
                                      context: context,
                                      isPressed: true,
                                      radius: 8,
                                    ),
                                    child: Text(
                                      "Update Status",
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showMessageDialog(
                                    orderId,
                                    customerEmail,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: NeumorphicUtils.decoration(
                                      context: context,
                                      isPressed: false,
                                      radius: 8,
                                    ),
                                    child: Text(
                                      "Contact Customer",
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(String orderId, String current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Update Status", style: TextStyle(fontSize: 16)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        children: orderStatuses
            .map(
              (s) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context);
                  updateOrderStatus(orderId, s);
                },
                child: Text(
                  s.toUpperCase(),
                  style: TextStyle(
                    color: s == current ? Theme.of(context).primaryColor : null,
                    fontWeight: s == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showMessageDialog(String orderId, String email) {
    if (email.isEmpty || email == 'N/A') {
      Api().showMessage(
        context,
        "No email available for this customer.",
        "Error",
        Colors.red,
      );
      return;
    }

    _messageController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Message Customer", style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: _messageController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Type your message to $email...",
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_messageController.text.trim().isEmpty) return;
              Navigator.pop(context);
              sendMessageToCustomer(
                orderId,
                email,
                _messageController.text.trim(),
              );
            },
            child: Text(
              "Send",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
