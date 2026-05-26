// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/NeuDesign.dart'; // Ensure this path is correct
import 'package:ttact/Components/API.dart'; // For showMessage/Toast if needed
import 'package:toastification/toastification.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/payment.dart';

// --- PLATFORM UTILITIES ---
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1000.0;

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double totalAmount = 0.0;
  static const String _cartKey = 'cart';

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  // --- CART LOGIC ---

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData != null) {
      List<dynamic> decodedData = json.decode(cartData);
      setState(() {
        cartItems = decodedData
            .map((item) => item as Map<String, dynamic>)
            .toList();
        calculateTotal();
        isLoading = false;
      });
    } else {
      setState(() {
        cartItems = [];
        isLoading = false;
        totalAmount = 0.0;
      });
    }
  }

  void calculateTotal() {
    double tempTotal = 0.0;
    for (var item in cartItems) {
      double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      int quantity = (item['quantity'] as int?) ?? 1;
      tempTotal += price * quantity;
    }
    setState(() {
      totalAmount = tempTotal;
    });
  }

  Future<void> updateCartStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, json.encode(cartItems));
    calculateTotal();
  }

  void incrementQuantity(int index) {
    setState(() {
      int currentQty = (cartItems[index]['quantity'] as int?) ?? 1;
      cartItems[index]['quantity'] = currentQty + 1;

      // Update itemTotalPrice for consistency
      double price = (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
      cartItems[index]['itemTotalPrice'] = price * (currentQty + 1);
    });
    updateCartStorage();
  }

  void decrementQuantity(int index) {
    int currentQty = (cartItems[index]['quantity'] as int?) ?? 1;
    if (currentQty > 1) {
      setState(() {
        cartItems[index]['quantity'] = currentQty - 1;

        // Update itemTotalPrice
        double price = (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
        cartItems[index]['itemTotalPrice'] = price * (currentQty - 1);
      });
      updateCartStorage();
    } else {
      // Ask to remove if quantity is 1
      _confirmRemoveItem(index);
    }
  }

  void removeItem(int index) {
    setState(() {
      cartItems.removeAt(index);
    });
    updateCartStorage();
  }

  void _confirmRemoveItem(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Item'),
        content: Text('Do you want to remove this item from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              removeItem(index);
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> proceedToCheckout() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Your cart is empty")));
      return;
    }

    // TODO: Implement Logic to create Order in Django/Firebase
    // Then navigate to Payment Page (Stripe)

    // Example:
    Navigator.push(context, MaterialPageRoute(builder: (c) => PaymentGatewayPage(  cartProducts: cartItems)));
  }

  // --- WIDGET BUILDER ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // Base color for Neumorphism
    final Color baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        backgroundColor: baseColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Cart",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
          ? _buildEmptyCart(theme, baseColor)
          : isDesktop
          ? _buildDesktopLayout(theme, baseColor)
          : _buildMobileLayout(theme, baseColor),
    );
  }

  Widget _buildEmptyCart(ThemeData theme, Color baseColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NeumorphicContainer(
            color: baseColor,
            isPressed: true, // Sunken
            borderRadius: 50,
            padding: EdgeInsets.all(30),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 60,
              color: theme.hintColor,
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Your Cart is Empty",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, Color baseColor) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: cartItems.length,
            itemBuilder: (context, index) =>
                _buildCartItem(cartItems[index], index, theme, baseColor),
          ),
        ),
        _buildCheckoutArea(theme, baseColor),
      ],
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, Color baseColor) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1000),
        padding: EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cart Items List
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: cartItems.length,
                itemBuilder: (context, index) =>
                    _buildCartItem(cartItems[index], index, theme, baseColor),
              ),
            ),
            SizedBox(width: 30),
            // Checkout Summary Panel
            Expanded(
              flex: 1,
              child: _buildCheckoutArea(theme, baseColor, isDesktop: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(
    Map<String, dynamic> item,
    int index,
    ThemeData theme,
    Color baseColor,
  ) {
    final String name = item['productName'] ?? 'Unknown Product';
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (item['quantity'] as int?) ?? 1;
    final String? imageUrl = item['imageUrl'];
    final String? color = item['selectedColor'];
    final String? size = item['selectedSize'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: false, // Convex
        borderRadius: 20,
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[300],
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
                  ? Icon(Icons.image, color: Colors.grey)
                  : null,
            ),
            SizedBox(width: 15),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  if (color != null || size != null)
                    Text(
                      "${color ?? ''} ${size != null ? '• $size' : ''}",
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                  SizedBox(height: 5),
                  Text(
                    "R${price.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Column(
              children: [
                _buildQuantityBtn(
                  Icons.add,
                  () => incrementQuantity(index),
                  baseColor,
                  theme,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    "$quantity",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildQuantityBtn(
                  Icons.remove,
                  () => decrementQuantity(index),
                  baseColor,
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityBtn(
    IconData icon,
    VoidCallback onTap,
    Color baseColor,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: false,
        borderRadius: 8,
        padding: EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
      ),
    );
  }

  Widget _buildCheckoutArea(
    ThemeData theme,
    Color baseColor, {
    bool isDesktop = false,
  }) {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Subtotal", style: TextStyle(color: theme.hintColor)),
            Text(
              "R${totalAmount.toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Total",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "R${totalAmount.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        GestureDetector(
          onTap: proceedToCheckout,
          child: NeumorphicContainer(
            color: theme.primaryColor,
            isPressed: false,
            borderRadius: 30,
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                "Proceed to Checkout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return NeumorphicContainer(
        color: baseColor,
        isPressed: false,
        borderRadius: 20,
        padding: EdgeInsets.all(20),
        child: content,
      );
    }

    // Mobile Bottom Sheet style
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(child: content),
    );
  }
}
