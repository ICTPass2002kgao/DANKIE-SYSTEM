// initial_route_wrapper.dart

// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Auth State Only
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For platform check
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/API.dart'; // Ensure API is imported

// Helper to check platform
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class InitialRouteWrapper extends StatefulWidget {
  const InitialRouteWrapper({super.key});

  @override
  State<InitialRouteWrapper> createState() => _InitialRouteWrapperState();
}

class _InitialRouteWrapperState extends State<InitialRouteWrapper>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _initialRoute = '/login'; // Default fallback
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Key for SharedPreferences
  static const String _introSeenKey = 'hasSeenIntro';

  @override
  void initState() {
    super.initState();

    // ⭐️ SETUP BREATHING ANIMATION
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Pulse in and out

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _determineRoute();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// This function handles all logic in the correct order.
  void _determineRoute() async {
    // 1. Check SharedPreferences for intro screen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool(_introSeenKey) ?? false;

    // 2. Wait for Firebase Auth to initialize (The Guard)
    User? user = await FirebaseAuth.instance.authStateChanges().first;

    String targetRoute;

    if (user == null) {
      // --- User is NOT logged in ---
      targetRoute = hasSeenIntro ? '/login' : '/introduction';
    } else {
      // --- User IS logged in ---
      try {
        // SECURE FIX: Get the Firebase ID token for the backend request
        String? token = await user.getIdToken();
        
        if (token == null) {
          throw Exception("Could not retrieve Firebase token.");
        }

        // 3. Verify User Profile in Django (The Brain)
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}',
        );

        // SECURE FIX: Added headers with the Bearer token
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List results = json.decode(response.body);

          if (results.isNotEmpty) {
            // User exists in Django DB
            targetRoute = '/main-menu';
          } else {
            // User authenticated in Firebase but no Django profile.
            // Sign out to reset state.
            await FirebaseAuth.instance.signOut();
            targetRoute = '/main-menu';
          }
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // SECURE FIX: Only sign out if the server actively rejects the token
          print("Django Auth Rejected. Signing out.");
          await FirebaseAuth.instance.signOut();
          targetRoute = '/login';
        } else {
          // SECURE FIX: If server is 500 or down, do NOT log them out.
          // Allow them into the app so offline features still work.
          print("Django Server Error: ${response.statusCode}");
          targetRoute = '/main-menu'; 
        }
      } catch (e) {
        // SECURE FIX: Handle network timeouts (e.g. offline)
        // Safe fallback allows app to open even if API is down or user has no internet
        print("Error checking user backend or no internet: $e");
        targetRoute = '/main-menu';
      }
    }

    // 4. Update state to trigger navigation
    if (mounted) {
      setState(() {
        _initialRoute = targetRoute;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⭐️ PREMIUM LOADING UI
    if (_isLoading) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      // Calculate Neumorphic Base Color
      final Color baseColor = Color.alphaBlend(
        theme.primaryColor.withOpacity(0.08),
        theme.scaffoldBackgroundColor,
      );

      return Scaffold(
        backgroundColor: baseColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. BREATHING LOGO CONTAINER
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                        // Premium Neumorphic Shadows
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.4),
                            offset: const Offset(5, 5),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: isDark
                                ? Colors.grey.withOpacity(0.1)
                                : Colors.white,
                            offset: const Offset(-5, -5),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/dankie_logo.PNG',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.flash_on_rounded,
                            size: 50,
                            color: theme.primaryColor,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // 2. APP NAME
              Text(
                "Dankie Mobile",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Starting up...",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.hintColor,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 50),

              // 3. SUBTLE LOADER
              SizedBox(
                width: 30,
                height: 30,
                child: isIOSPlatform
                    ? CupertinoActivityIndicator(color: theme.primaryColor)
                    : CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.primaryColor,
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Navigation Logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(_initialRoute);
      }
    });

    return const SizedBox.shrink();
  }
}