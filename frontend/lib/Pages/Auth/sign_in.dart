// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:text_field_validation/text_field_validation.dart';

import 'package:ttact/Pages/Auth/face_verification.dart';
import 'package:ttact/Pages/Auth/reset_password.dart';
import 'package:ttact/Pages/Auth/sign_up.dart';
import '../../Components/API.dart';
import '../../Components/NeuDesign.dart';

bool get isIOSPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

Widget _buildNeumorphicTextField({
  required TextEditingController controller,
  required String placeholder,
  required Color baseColor,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  Widget? suffixIcon,
  String? Function(String?)? validator,
  required BuildContext context,
}) {
  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NeumorphicContainer(
        isPressed: true,
        color: baseColor,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: isIOSPlatform
            ? CupertinoTextField(
                controller: controller,
                placeholder: placeholder,
                placeholderStyle: TextStyle(
                  color: theme.hintColor.withOpacity(0.9),
                ),
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                keyboardType: keyboardType,
                obscureText: obscureText,
                decoration: null,
                padding: const EdgeInsets.all(16.0),
                prefix: prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(prefixIcon, color: theme.primaryColor),
                      )
                    : null,
                suffix: suffixIcon,
              )
            : TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
                  prefixIcon: prefixIcon != null
                      ? Icon(prefixIcon, color: theme.primaryColor)
                      : null,
                  suffixIcon: suffixIcon,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 10.0,
                  ),
                ),
                validator: validator,
              ),
      ),
      if (validator != null) SizedBox(height: 5),
    ],
  );
}

class Login_Page extends StatefulWidget {
  const Login_Page({super.key});

  @override
  State<Login_Page> createState() => _Login_PageState();
}

class _Login_PageState extends State<Login_Page>
    with SingleTickerProviderStateMixin {
  final TextEditingController txtEmail = TextEditingController();
  final TextEditingController txtPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;

  late AnimationController _logoAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    );
    _logoAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    txtEmail.dispose();
    txtPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    isIOSPlatform ? Api().showIosLoading(context) : Api().showLoading(context);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: txtEmail.text.trim(),
            password: txtPassword.text.trim(),
          );

      var user = userCredential.user;
      if (user == null) throw Exception("Auth failed");
      var uid = user.uid;
      var email = user.email ?? txtEmail.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', uid);

      List<Map<String, String>> potentialIdentities = [];

      // CHECK OVERSEER COMMITTEE
      var overseerProfile = await _fetchProfileFromDjango(
        'overseers',
        email,
        queryParam: 'email',
      );
      if (overseerProfile != null) {
        var members = await _fetchListFromDjango(
          'committee_members',
          'overseer=${overseerProfile['id']}',
        );
        potentialIdentities = members
            .map<Map<String, String>>(
              (m) => {
                'name': m['full_name'] ?? 'Unknown Member',
                'portfolio': m['portfolio'] ?? 'Committee',
                'faceUrl': m['face_url'] ?? '',
              },
            )
            .toList();

        _launchVerification(
          uid,
          'Overseer',
          potentialIdentities,
          overseerProfile['overseer_initials_surname'] ?? 'Overseer',
        );
        return;
      }

      // CHECK TACTSO BRANCH COMMITTEE
      var tactsoProfile = await _fetchProfileFromDjango(
        'tactso_branches',
        uid,
        queryParam: 'uid',
      );
      if (tactsoProfile != null) {
        var members = await _fetchListFromDjango(
          'branch_committee',
          'branch=${tactsoProfile['id']}',
        );
        potentialIdentities = members
            .map<Map<String, String>>(
              (m) => {
                'name': m['full_name'] ?? 'Unknown Member',
                'portfolio': m['portfolio'] ?? 'Branch Staff',
                'faceUrl': m['face_url'] ?? '',
              },
            )
            .toList();

        _launchVerification(
          uid,
          'Tactso Branch',
          potentialIdentities,
          tactsoProfile['university_name'] ?? 'University Branch',
        );
        return;
      }

      // CHECK ADMIN STAFF
      var staffProfile = await _fetchProfileFromDjango(
        'staff',
        uid,
        queryParam: 'uid',
      );
      if (staffProfile != null) {
        potentialIdentities = [
          {
            'name': staffProfile['full_name'] ?? 'Admin',
            'portfolio': staffProfile['portfolio'] ?? 'Management',
            'faceUrl': staffProfile['face_url'] ?? '',
          },
        ];
        _launchVerification(
          uid,
          'Admin',
          potentialIdentities,
          "Management Portal",
        );
        return;
      }

      // STANDARD USER
      var userProfile = await _fetchProfileFromDjango(
        'users',
        uid,
        queryParam: 'uid',
      );
      if (userProfile != null) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, "/main-menu");
        return;
      }

      throw Exception("No associated profile found.");
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      Api().showMessage(context, e.toString(), 'Login Error', Colors.red);
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileFromDjango(
    String endpoint,
    String identifier, {
    String queryParam = 'uid',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    String token = await user?.getIdToken() ?? "";
    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/$endpoint/?$queryParam=$identifier',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      var decoded = json.decode(response.body);
      List results = (decoded is Map) ? decoded['results'] : decoded;
      return results.isNotEmpty ? results[0] : null;
    }
    return null;
  }

  Future<List<dynamic>> _fetchListFromDjango(
    String endpoint,
    String query,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    String token = await user?.getIdToken() ?? "";
    final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/$endpoint/?$query');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      var decoded = json.decode(response.body);
      return (decoded is Map) ? decoded['results'] : decoded;
    }
    return [];
  }

  void _launchVerification(
    String uid,
    String role,
    List<Map<String, String>> identities,
    String branchName,
  ) async {
    if (context.mounted) Navigator.pop(context);
    final cameras = await availableCameras();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceVerificationScreen(
          email: txtEmail.text.trim(),
          password: txtPassword.text.trim(),
          camera: cameras.first,
          entityUid: uid,
          role: role,
          identities: identities,
          branchName: branchName,
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

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: NeumorphicContainer(
                        color: neumoBaseColor,
                        borderRadius: 100,
                        padding: const EdgeInsets.all(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(90),
                          child: Image.asset(
                            "assets/dankie_logo.PNG",
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 20,
                      padding: const EdgeInsets.all(25),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: theme.primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Sign in to continue",
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.primaryColor.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 30),
                            _buildNeumorphicTextField(
                              context: context,
                              baseColor: neumoBaseColor,
                              controller: txtEmail,
                              placeholder: "Email Address",
                              prefixIcon: isIOSPlatform
                                  ? CupertinoIcons.mail_solid
                                  : Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => TextFieldValidation.email(v!),
                            ),
                            SizedBox(height: 20),
                            _buildNeumorphicTextField(
                              context: context,
                              baseColor: neumoBaseColor,
                              controller: txtPassword,
                              placeholder: "Password",
                              prefixIcon: isIOSPlatform
                                  ? CupertinoIcons.lock_fill
                                  : Icons.lock,
                              obscureText: _obscureText,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(
                                  () => _obscureText = !_obscureText,
                                ),
                                child: Icon(
                                  _obscureText
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: theme.primaryColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPassword(),
                                  ),
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            GestureDetector(
                              onTap: _handleLogin,
                              child: NeumorphicContainer(
                                color: theme.primaryColor,
                                borderRadius: 10,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: theme.hintColor),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          ),
                          child: Text(
                            "Register Now",
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
