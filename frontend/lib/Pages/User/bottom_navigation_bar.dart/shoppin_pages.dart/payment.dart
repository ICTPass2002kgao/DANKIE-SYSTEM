// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Pages/Auth/sign_up.dart';
import 'package:ttact/Components/NeumorphicUtils.dart'; // ⭐️ IMPORTED NEUMORPHIC UTILS

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// --------------------------

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}

// --- INLINE LOGIN FORM ---
class InlineLoginForm extends StatefulWidget {
  final VoidCallback? onSuccess;
  const InlineLoginForm({Key? key, this.onSuccess}) : super(key: key);

  @override
  _InlineLoginFormState createState() => _InlineLoginFormState();
}

class _InlineLoginFormState extends State<InlineLoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      widget.onSuccess?.call();
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.message != null) {
        message = e.message!;
      }
      _showError(message);
    } catch (e) {
      _showError('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ⭐️ NEUMORPHIC UNIFIED TEXT FIELD
  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    required Iterable<String> autofillHints,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: NeumorphicUtils.decoration(
            context: context,
            isPressed: true, // Inset look for text fields
            radius: 12,
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: isPassword ? _obscureText : false,
            autofillHints: autofillHints,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: theme.hintColor,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ⭐️ NEUMORPHIC UNIFIED BUTTON
  Widget _buildPlatformButton({
    required VoidCallback? onPressed,
    required String text,
  }) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: isIOSPlatform
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: NeumorphicUtils.decoration(
          context: context,
          radius: 12,
        ).copyWith(color: theme.primaryColor),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: theme.scaffoldBackgroundColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformTextButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Please sign in to continue',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildPlatformTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            _buildPlatformTextField(
              controller: _passwordController,
              label: 'Password',
              isPassword: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 30),
            _buildPlatformButton(
              onPressed: _isLoading ? null : _signIn,
              text: 'Sign in',
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No account? ', style: TextStyle(color: theme.hintColor)),
                _buildPlatformTextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  text: 'Create one',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentGatewayPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartProducts;
  final String? selectedColor;
  final String? selectedSize;
  const PaymentGatewayPage({
    required this.cartProducts,
    Key? key,
    this.selectedColor,
    this.selectedSize,
  }) : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final TextEditingController _addressController = TextEditingController();

  bool needsDelivery = true;
  double deliveryCharge = 50.0;
  bool isPlacingOrder = false;
  bool _isLoadingAddress = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _pollingTimer;

  String? name;
  String? surname;
  String? email;
  String? phone;

  @override
  void initState() {
    super.initState();
    _fetchUserAddressFromDjango();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserAddressFromDjango() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingAddress = true;
      _addressController.text = 'Loading address...';
    });

    try {
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${currentUser.uid}',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${await currentUser.getIdToken()}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final data = results[0];
          setState(() {
            name = data['name'];
            surname = data['surname'];
            email = data['email'];
            phone = data['phone'];

            String? storedAddress = data['address'];
            if (storedAddress != null && storedAddress.isNotEmpty) {
              _addressController.text = storedAddress;
            } else {
              _addressController.text = '';
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching user data from Django: $e");
      _addressController.text = '';
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  String _getPickupInfo() {
    StringBuffer buffer = StringBuffer();
    for (var item in widget.cartProducts) {
      String productName = item['productName'] ?? 'Item';
      String location = item['location'] ?? 'Contact seller for location';
      buffer.writeln("• $productName: $location");
    }
    return buffer.toString().trim();
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var product in widget.cartProducts) {
      final productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      final productQuantity = (product['quantity'] as int?) ?? 1;
      subtotal += productPrice * productQuantity;
    }
    return subtotal;
  }

  double _calculateTotal() {
    double total = _calculateSubtotal();
    if (needsDelivery) {
      total += deliveryCharge;
    }
    return total;
  }

  void _showLoginPrompt() {
    final loginForm = InlineLoginForm(
      onSuccess: () {
        Navigator.pop(context);
        _fetchUserAddressFromDjango();
        Api().showMessage(
          context,
          'Logged in successfully.',
          'Success',
          Colors.green,
        );
      },
    );

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent, // Transparent for custom wrapper
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 400,
            decoration: NeumorphicUtils.decoration(
              context: context,
              radius: 25,
            ),
            child: loginForm,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: loginForm,
        ),
      );
    }
  }

  void _startPollingForPayment(String orderId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final uri = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/orders/$orderId/verify_payment/',
        );
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'paid' || data['is_paid'] == true) {
            timer.cancel();
            _handlePaymentSuccess(orderId);
          }
        }
      } catch (e) {
        print("Polling error: $e");
      }
    });
  }

  void _handlePaymentSuccess(String orderId) {
    if (!mounted) return;
    CartHelper.clearCart();
    Navigator.popUntil(context, (route) => route.isFirst);

    Api().showMessage(
      context,
      'Payment Successful! Order #$orderId confirmed.',
      'Payment Confirmed',
      Colors.green,
    );
  }

  Future<void> _payWithPaystack() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showLoginPrompt();
      return;
    }

    if (widget.cartProducts.isEmpty) {
      Api().showMessage(context, 'Cart is empty!', 'Error', Colors.red);
      return;
    }

    if (needsDelivery && _addressController.text.trim().isEmpty) {
      Api().showMessage(
        context,
        'Please provide an address.',
        'Error',
        Colors.red,
      );
      return;
    }

    setState(() => isPlacingOrder = true);

    try {
      final String finalAddress = needsDelivery
          ? _addressController.text.trim()
          : _getPickupInfo();

      final Map<String, dynamic> orderPayload = {
        'user_uid': user.uid,
        'full_name': "$name $surname".trim().isEmpty
            ? "Valued Customer"
            : "$name $surname",
        'email': email ?? user.email,
        'address': finalAddress,
        'phone_number': phone ?? "0000000000",
        'city': "South Africa",
        'postal_code': "0000",
        'needs_delivery': needsDelivery,
        'delivery_charge': needsDelivery ? deliveryCharge : 0.0,
        'total_amount': _calculateTotal(),
        'status': 'pending',
        'items': widget.cartProducts.map((p) {
          final prodId = p['productId'] ?? p['product_id'];
          if (prodId == null) throw "Invalid Cart Item. Please Clear Cart.";
          return {
            'product_id': prodId,
            'quantity': p['quantity'] ?? 1,
            'price': p['price'],
            'color': p['selectedColor'],
            'size': p['selectedSize'],
          };
        }).toList(),
      };

      final orderUri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/orders/');
      final orderRes = await http.post(
        orderUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: json.encode(orderPayload),
      );

      if (orderRes.statusCode != 201) {
        throw "Failed to create order: ${orderRes.body}";
      }

      final orderData = json.decode(orderRes.body);
      final String orderId = orderData['id'];

      List<Map<String, dynamic>> paystackItems = widget.cartProducts.map((p) {
        return {
          'name': p['productName'] ?? 'Item',
          'price': p['price'],
          'quantity': p['quantity'] ?? 1,
          'subaccount': p['subaccountCode'] ?? '',
        };
      }).toList();

      final linkUri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/create-payment-link/',
      );
      final linkRes = await http.post(
        linkUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'email': email ?? user.email,
          'products': paystackItems,
          'orderReference': orderId,
        }),
      );

      final linkData = jsonDecode(linkRes.body);
      if (linkData['paymentLink'] != null) {
        final url = Uri.parse(linkData['paymentLink']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          _startPollingForPayment(orderId);

          Api().showMessage(
            context,
            'Redirecting to payment...',
            'Please complete payment.',
            Theme.of(context).primaryColor,
          );
        } else {
          throw 'Could not open payment link';
        }
      } else {
        throw linkData['error'] ?? 'Failed to create payment link';
      }
    } catch (e) {
      print('Payment Error: $e');
      Api().showMessage(context, 'Error: $e', 'Payment Error', Colors.red);
    } finally {
      setState(() => isPlacingOrder = false);
    }
  }

  // --- ⭐️ NEUMORPHIC UI WIDGETS ---

  Widget _buildDeliveryMethodSelector() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(6),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isPressed: true, // Inset background to hold the toggles
        radius: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => needsDelivery = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !needsDelivery
                      ? theme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !needsDelivery
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store,
                      size: 18,
                      color: !needsDelivery ? Colors.white : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Collect',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: !needsDelivery ? Colors.white : theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => needsDelivery = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: needsDelivery
                      ? theme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: needsDelivery
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      size: 18,
                      color: needsDelivery ? Colors.white : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: needsDelivery ? Colors.white : theme.hintColor,
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

  Widget _buildAddressInput() {
    final theme = Theme.of(context);

    return Container(
      decoration: NeumorphicUtils.decoration(
        context: context,
        isPressed: true, // Inset look
        radius: 12,
      ),
      child: TextField(
        controller: _addressController,
        maxLines: 3,
        enabled: !_isLoadingAddress,
        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        decoration: InputDecoration(
          hintText: _isLoadingAddress
              ? 'Fetching profile address...'
              : 'Enter Delivery Address or Pexi Code',
          hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: _isLoadingAddress
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPaymentButton() {
    final theme = Theme.of(context);

    if (isPlacingOrder) {
      return Center(
        child: isIOSPlatform
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: _payWithPaystack,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: NeumorphicUtils.decoration(
          context: context,
          radius: 15,
        ).copyWith(color: theme.primaryColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, color: theme.scaffoldBackgroundColor),
            const SizedBox(width: 10),
            Text(
              'Proceed to Payment',
              style: TextStyle(
                color: theme.scaffoldBackgroundColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Checkout",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: "Clear Cart",
            onPressed: () {
              CartHelper.clearCart();
              Navigator.pop(context);
              Api().showMessage(context, "Cart cleared", "Info", Colors.blue);
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ⭐️ NEUMORPHIC Delivery Option Container ---
                Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: NeumorphicUtils.decoration(
                    context: context,
                    radius: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: theme.primaryColor),
                          const SizedBox(width: 10.0),
                          Text(
                            'Delivery Method',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildDeliveryMethodSelector(),
                      if (needsDelivery)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, left: 4.0),
                          child: Text(
                            'Delivery Charge: R${deliveryCharge.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // --- ⭐️ NEUMORPHIC Address / Pickup Container ---
                Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: NeumorphicUtils.decoration(
                    context: context,
                    radius: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            needsDelivery
                                ? Icons.location_on
                                : Icons.store_mall_directory,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 10.0),
                          Text(
                            needsDelivery
                                ? 'Delivery Address'
                                : 'Pickup Point(s)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (needsDelivery) ...[
                        _buildAddressInput(),
                        if (currentUser == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              "Sign in to load saved address or enter a new one.",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (currentUser != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Wrap(
                              children: [
                                Text(
                                  "Please provide your pexi code for accurate delivery. ",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    launchUrl(
                                      Uri.parse(
                                        'https://www.paxi.co.za/paxi-points',
                                      ),
                                      mode: LaunchMode.inAppBrowserView,
                                    );
                                  },
                                  child: Text(
                                    "Click here",
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  " to find your pexi code.",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: NeumorphicUtils.decoration(
                            context: context,
                            isPressed: true,
                            radius: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "You will collect the items from:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _getPickupInfo(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodyMedium?.color,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Please contact the seller to arrange a time.",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // --- ⭐️ NEUMORPHIC Order Summary Container ---
                Container(
                  margin: const EdgeInsets.only(bottom: 30.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: NeumorphicUtils.decoration(
                    context: context,
                    radius: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: theme.primaryColor),
                          const SizedBox(width: 10.0),
                          Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.cartProducts.length,
                        itemBuilder: (context, index) {
                          final product = widget.cartProducts[index];
                          final productName =
                              product['productName'] ?? 'Product';
                          final productPrice =
                              (product['price'] as num?)?.toDouble() ?? 0.0;
                          final productQuantity =
                              (product['quantity'] as int?) ?? 1;
                          final subtotal = productPrice * productQuantity;
                          final imageUrl =
                              product['imageUrl']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ⭐️ NEUMORPHIC IMAGE THUMBNAIL
                                Container(
                                  decoration: NeumorphicUtils.decoration(
                                    context: context,
                                    isPressed: true,
                                    radius: 10,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10.0),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 45,
                                            height: 45,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                _buildPlaceholderImage(theme),
                                          )
                                        : _buildPlaceholderImage(theme),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'R${productPrice.toStringAsFixed(2)} x $productQuantity',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'R${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: theme.hintColor.withOpacity(0.2)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal:',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.hintColor,
                            ),
                          ),
                          Text(
                            'R${_calculateSubtotal().toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (needsDelivery)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Delivery Charge:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.hintColor,
                                ),
                              ),
                              Text(
                                'R${deliveryCharge.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: theme.hintColor.withOpacity(0.2)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'R${_calculateTotal().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _buildPaymentButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      width: 45,
      height: 45,
      color: theme.hintColor.withOpacity(0.1),
      child: Icon(Icons.image, color: theme.hintColor, size: 20),
    );
  }
}
