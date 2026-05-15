// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerMyProductsTab extends StatefulWidget {
  final String userId;
  final Color baseColor;

  const SellerMyProductsTab({
    super.key,
    required this.userId,
    required this.baseColor,
  });

  @override
  SellerMyProductsTabState createState() => SellerMyProductsTabState();
}

class SellerMyProductsTabState extends State<SellerMyProductsTab> {
  bool isLoading = true;
  List<dynamic> myProducts = [];

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  // --- 1. FETCH INVENTORY (DJANGO - SECURED) ---
  Future<void> fetchInventory() async {
    setState(() => isLoading = true);
    try {
      // SECURE FIX: Get the current user and token
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

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/seller-inventory/?seller_uid=${widget.userId}',
      );

      // SECURE FIX: Added Authorization headers
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        List<dynamic> productList = [];

        if (data is Map<String, dynamic> && data.containsKey('results')) {
          productList = data['results'];
        } else if (data is List) {
          productList = data;
        }

        if (mounted) {
          setState(() {
            myProducts = productList;
            isLoading = false;
          });
        }
      } else {
        print("Error fetching inventory: ${response.statusCode}");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      print("Exception fetching inventory: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 2. UPDATE PRICE (DJANGO - SECURED) ---
  Future<void> updatePrice(String listingId, double newPrice) async {
    Api().showLoading(context);
    try {
      // SECURE FIX: Get the current user and token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Authentication required");
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/seller-inventory/$listingId/',
      );

      // SECURE FIX: Added Authorization header to PATCH request
      final response = await http.patch(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({"price": newPrice}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        fetchInventory();
        Api().showMessage(
          context,
          "Price updated successfully",
          "Success",
          Colors.green,
        );
      } else {
        print("Update Error: ${response.body}");
        Api().showMessage(
          context,
          "Failed to update. Server returned: ${response.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  void _showUpdatePriceDialog(
    String listingId,
    String name,
    double currentPrice,
  ) {
    final controller = TextEditingController(text: currentPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text("Update Price for $name", style: TextStyle(fontSize: 16)),
        content: NeumorphicUtils.buildTextField(
          controller: controller,
          placeholder: "New Price",
          context: context,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.attach_money,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                Navigator.pop(context);
                updatePrice(listingId, newPrice);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey.withOpacity(0.5),
            ),
            SizedBox(height: 15),
            Text(
              "No products found in your inventory.",
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 5),
            Text(
              "Go to the 'Add' tab to list items.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isDesktop
            ? GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: myProducts.length,
                itemBuilder: (context, index) =>
                    _buildProductCard(myProducts[index], index),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: myProducts.length,
                itemBuilder: (context, index) =>
                    _buildProductCard(myProducts[index], index),
              ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data, int index) {
    final accentColor = NeumorphicUtils.getAccentColor(index);

    final String listingId = data['id'].toString();
    final String name = data['product_name'] ?? 'Unknown';
    final String imageUrl = data['image_url'] ?? '';
    final double price = double.tryParse(data['price'].toString()) ?? 0.0;
    final int views = 0; // Views logic to be implemented later

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
            Container(
              width: 70,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
                image: (imageUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (imageUrl.isEmpty)
                  ? Icon(Icons.image_not_supported, color: Colors.grey)
                  : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "R${price.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Views: $views",
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.edit,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
              onPressed: () => _showUpdatePriceDialog(listingId, name, price),
            ),
          ],
        ),
      ),
    );
  }
}