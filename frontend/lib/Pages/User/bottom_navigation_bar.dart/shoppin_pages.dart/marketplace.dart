// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'package:toastification/toastification.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/ProductCard.dart';
import 'package:ttact/Components/Product_Details.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/cart.dart';
import 'package:ttact/Components/NeumorphicUtils.dart'; // ⭐️ IMPORTED NEUMORPHIC UTILS

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> addToCart(
    Map<String, dynamic> product,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    List<Map<String, dynamic>> cart = [];

    if (cartData != null) {
      cart = List<Map<String, dynamic>>.from(
        (json.decode(cartData) as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
    }

    final String? uniqueId = product['listingId'] ?? product['productId'];
    if (uniqueId == null) {
      print("Error: Product ID is missing.");
      return;
    }

    bool productFound = false;
    for (int i = 0; i < cart.length; i++) {
      String? cartItemId = cart[i]['listingId'] ?? cart[i]['productId'];
      if (cartItemId == uniqueId &&
          cart[i]['selectedColor'] == selectedColor &&
          cart[i]['selectedSize'] == selectedSize) {
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;

        cart[i]['quantity'] = currentQuantity + 1;
        cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        productFound = true;
        break;
      }
    }

    if (!productFound) {
      double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      product['quantity'] = 1;
      product['itemTotalPrice'] = productPrice;
      product['selectedColor'] = selectedColor;
      product['selectedSize'] = selectedSize;
      cart.add(product);
    }

    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<void> removeFromCart(
    String uniqueId,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData == null) return;

    List<Map<String, dynamic>> cart = List<Map<String, dynamic>>.from(
      (json.decode(cartData) as List).map(
        (item) => item as Map<String, dynamic>,
      ),
    );

    for (int i = 0; i < cart.length; i++) {
      String? cartItemId = cart[i]['listingId'] ?? cart[i]['productId'];
      if (cartItemId == uniqueId &&
          cart[i]['selectedColor'] == selectedColor &&
          cart[i]['selectedSize'] == selectedSize) {
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        if (currentQuantity > 1) {
          cart[i]['quantity'] = currentQuantity - 1;
          double productPrice = (cart[i]['price'] as num?)?.toDouble() ?? 0.0;
          cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        } else {
          cart.removeAt(i);
        }
        break;
      }
    }
    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<List<Map<String, dynamic>>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData != null) {
      return List<Map<String, dynamic>>.from(
        (json.decode(cartData) as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
    }
    return [];
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  int cartCount = 0;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _currentUserId;

  String _searchQuery = '';
  Map<String, dynamic>? _selectedProductDetails;
  bool _isDetailsPanelVisible = false;

  final List<String> _productCategories = const [
    'All',
    'Shirts & Polos',
    'Suits & Jackets',
    'Trousers & Skirts',
    'Footwear',
    'Accessories',
    'Hats',
    'Shoes',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    loadCartCount();
    fetchAllSellerProducts();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    int totalItems = 0;
    for (var item in cart) {
      totalItems += (item['quantity'] as int? ?? 0);
    }
    setState(() {
      cartCount = totalItems;
    });
  }

  // --- CHANGED: SECURED API CALL ---
  void fetchAllSellerProducts() async {
    setState(() => _isLoading = true);

    try {
      // SECURE FIX: Grab the current user and their token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/seller-inventory/',
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
        final dynamic data = json.decode(response.body);
        List<dynamic> results = [];

        // Handle Pagination vs List
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          results = data['results'];
        } else if (data is List) {
          results = data;
        }

        List<Map<String, dynamic>> loadedProducts = [];

        for (var item in results) {
          String sellerId = item['seller_uid'] ?? '';

          // Commented out self-filter for testing visibility
          // if (_currentUserId != null && sellerId == _currentUserId) continue;

          // MAP SNAKE_CASE (API) -> CAMELCASE (UI Widgets)
          loadedProducts.add({
            'listingId': item['id'],
            'productId': item['product_id'],
            'sellerId': sellerId,

            // FIX: Use 'product_name' (from Serializer) instead of 'product'
            'productName': item['product_name'] ?? 'Unknown',
            'category': item['category'] ?? 'Other',
            'description': item['description'] ?? 'No description',

            // FIX: Use 'image_url' (from Serializer)
            'imageUrl': item['image_url'] ?? '',

            // Seller Data
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'location': item['location'] ?? '',
            'availableColors': item['seller_colors'] ?? [],
            'availableSizes': item['seller_sizes'] ?? [],

            // Defaults
            'discountPercentage': 0.0,
            'isAvailable': true,
            'subAccountCode': '',
            'sellerEmail': '',
            'sellerName': '',
          });
        }

        if (mounted) {
          setState(() {
            products = loadedProducts;
            _applyFilter();
            _isLoading = false;
          });
        }
      } else {
        print("Failed to load shop: ${response.statusCode} - ${response.body}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching shop: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    String query = _searchQuery.toLowerCase();

    // 1. Start with products
    Iterable<Map<String, dynamic>> tempProducts = products;

    // 2. Apply Category filter
    if (_selectedCategory != 'All') {
      tempProducts = tempProducts.where(
        (product) => product['category'] == _selectedCategory,
      );
    }

    // 3. Apply Search query filter
    if (query.isNotEmpty) {
      tempProducts = tempProducts.where((product) {
        final productName =
            (product['productName'] as String?)?.toLowerCase() ?? '';
        final category = (product['category'] as String?)?.toLowerCase() ?? '';

        return productName.contains(query) || category.contains(query);
      });
    }

    _filteredProducts = tempProducts.toList();
    setState(() {});
  }

  void addToCartFromProductDetails(
    Map<String, dynamic> product,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final theme = Theme.of(context);
    await CartHelper.addToCart(product, selectedColor, selectedSize);
    loadCartCount();

    toastification.dismissAll();
    Api().showMessage(
      context,
      '${product['productName']} added to cart',
      'Success',
      theme.primaryColor,
    );
  }

  void _handleProductClick(Map<String, dynamic> product) {
    final isDesktop = isLargeScreen(context);

    if (isDesktop) {
      setState(() {
        _selectedProductDetails = product;
        _isDetailsPanelVisible = true;
      });
    } else {
      showModalBottomSheet(
        scrollControlDisabledMaxHeightRatio: 0.8,
        backgroundColor: Colors.transparent, // ⭐️ Transparent for Neumorphism
        context: context,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ProductDetails(
              productDetails: product,
              sellerProductId: product['sellerId'],
              onAddToCart: (selectedColor, selectedSize) {
                addToCartFromProductDetails(
                  product,
                  selectedColor,
                  selectedSize,
                );
              },
            ),
          );
        },
      );
    }
  }

  Widget _buildProductGrid(
    ThemeData theme,
    double horizontalPadding,
    double spacing,
    double cardWidth,
  ) {
    final isDesktop = isLargeScreen(context);

    Widget productContent = SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: DefaultTabController(
        length: _productCategories.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⭐️ NEUMORPHIC Search Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, top: 10),
              child: Container(
                decoration: NeumorphicUtils.decoration(
                  context: context,
                  isPressed: true, // Inset look for text fields
                  radius: 18,
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilter();
                      _isDetailsPanelVisible = false;
                      _selectedProductDetails = null;
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(18),
                    hintText: 'Search product by name or category...',
                    hintStyle: TextStyle(color: theme.hintColor),
                    prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            // ⭐️ NEUMORPHIC Tabs
            Container(
              padding: EdgeInsets.all(4),
              decoration: NeumorphicUtils.decoration(
                context: context,
                isPressed: false, // Protruding container to hold tabs
                radius: 20,
              ),
              child: TabBar(
                isScrollable: !isDesktop,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.scaffoldBackgroundColor.withOpacity(0.9),
                dividerColor: Colors.transparent,
                unselectedLabelColor: theme.hintColor,
                overlayColor: WidgetStatePropertyAll(
                  theme.primaryColor.withOpacity(0.1),
                ),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                onTap: (index) {
                  setState(() {
                    _selectedCategory = _productCategories[index];
                    _applyFilter();
                    _isDetailsPanelVisible = false;
                    _selectedProductDetails = null;
                  });
                },
                tabs: _productCategories
                    .map((category) => Tab(text: category))
                    .toList(),
              ),
            ),
            SizedBox(height: 30),

            // Grid
            if (_filteredProducts.isEmpty && _isLoading == false)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Container(
                    padding: EdgeInsets.all(40),
                    decoration: NeumorphicUtils.decoration(
                      context: context,
                      radius: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: theme.hintColor,
                        ),
                        SizedBox(height: 15),
                        Text(
                          'No products found matching your search.',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.hintColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.start,
                children: _filteredProducts.map((product) {
                  final bool isSellerProduct =
                      _currentUserId == product['sellerId'];

                  final bool isSelected =
                      isDesktop &&
                      _selectedProductDetails?['listingId'] ==
                          product['listingId'];

                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: () => _handleProductClick(product),
                      child: Product_Card(
                        onCartPressed: () => _handleProductClick(product),
                        imageUrl: product['imageUrl'],
                        categoryName: product['category'],
                        productName: product['productName'],
                        price: product['price'],
                        discountPercentage: product['discountPercentage'],
                        location: product['location'] ?? '',
                        isAvailable: product['isAvailable'] ?? true,
                        availableColors: product['availableColors'] as dynamic,
                        isSellerProduct: isSellerProduct,
                        cardBorder: isSelected
                            ? Border.all(color: theme.primaryColor, width: 2.5)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: 1200.0),
        child: productContent,
      ),
    );
  }

  Widget _buildDetailsPanel(ThemeData theme) {
    if (!_isDetailsPanelVisible || _selectedProductDetails == null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(30),
          decoration: NeumorphicUtils.decoration(context: context, radius: 20),
          child: Text(
            'Select a product to view details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor.withOpacity(0.5)),
          ),
        ),
      );
    }

    // ⭐️ NEUMORPHIC Details Panel
    return Container(
      margin: EdgeInsets.only(top: 20, right: 20, bottom: 20, left: 10),
      decoration: NeumorphicUtils.decoration(context: context, radius: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ProductDetails(
          productDetails: _selectedProductDetails!,
          sellerProductId: _selectedProductDetails!['sellerId'],
          onAddToCart: (selectedColor, selectedSize) {
            addToCartFromProductDetails(
              _selectedProductDetails!,
              selectedColor,
              selectedSize,
            );
          },
          onClose: () {
            setState(() {
              _isDetailsPanelVisible = false;
              _selectedProductDetails = null;
            });
          },
          isStandalone: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    final int baseCrossAxisCount = 2;
    final int desktopCrossAxisCount = _isDetailsPanelVisible ? 3 : 5;
    final int crossAxisCount = isDesktop
        ? desktopCrossAxisCount
        : baseCrossAxisCount;

    final double horizontalPadding = isDesktop ? 20.0 : 10.0;
    final double spacing = isDesktop ? 20.0 : 10.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    const double maxWidth = 1200.0;

    double availableWidth;
    if (isDesktop) {
      double containerWidth = screenWidth > maxWidth ? maxWidth : screenWidth;
      if (_isDetailsPanelVisible) {
        availableWidth = (containerWidth * (3 / 5)) - (horizontalPadding * 2);
      } else {
        availableWidth = containerWidth - (horizontalPadding * 2);
      }
    } else {
      availableWidth = screenWidth - (horizontalPadding * 2);
    }

    final double calculatedCardWidth =
        (availableWidth - ((crossAxisCount - 1) * spacing));
    final double cardWidth =
        calculatedCardWidth.isFinite && calculatedCardWidth > 0
        ? calculatedCardWidth / crossAxisCount
        : (screenWidth / crossAxisCount) - spacing;

    Widget content;

    if (_isLoading) {
      isIOSPlatform
          ? content = Center(child: CupertinoActivityIndicator())
          : content = Center(child: CircularProgressIndicator());
    } else if (products.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            padding: EdgeInsets.all(40),
            decoration: NeumorphicUtils.decoration(
              context: context,
              radius: 25,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, size: 80, color: theme.hintColor),
                const SizedBox(height: 20),
                Text(
                  'No products available right now.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new arrivals!',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.hintColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    } else if (isDesktop) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildProductGrid(
              theme,
              horizontalPadding,
              spacing,
              cardWidth,
            ),
          ),
          if (_isDetailsPanelVisible)
            Expanded(flex: 1, child: _buildDetailsPanel(theme)),
        ],
      );
    } else {
      content = _buildProductGrid(theme, horizontalPadding, spacing, cardWidth);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ⭐️ NEUMORPHIC Floating Action Button Wrapper
      floatingActionButton: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          );
          loadCartCount();
        },
        child: badges.Badge(
          showBadge: cartCount > 0,
          badgeContent: Text(
            '$cartCount',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          position: badges.BadgePosition.topEnd(top: 0, end: 0),
          child: Container(
            height: 60,
            width: 60,
            decoration:
                NeumorphicUtils.decoration(
                  context: context,
                  radius: 30, // Make it circular
                ).copyWith(
                  color: theme.primaryColor, // Keep the primary color
                ),
            child: Icon(
              Icons.shopping_cart_outlined,
              color: theme.scaffoldBackgroundColor.withOpacity(0.9),
              size: 28,
            ),
          ),
        ),
      ),
      body: content,
    );
  }
}
