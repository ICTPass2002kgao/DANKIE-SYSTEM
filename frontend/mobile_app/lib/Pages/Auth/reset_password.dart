// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:text_field_validation/text_field_validation.dart';
import '../../Components/API.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required BuildContext context,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⭐️ NEUMORPHIC INSET CONTAINER
        NeumorphicContainer(
          isPressed: true, // Sunken effect
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: baseColor,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: theme.hintColor),
              icon: Icon(icon, color: theme.primaryColor),
              border: InputBorder.none, // No borders, let shadow define shape
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorStyle: const TextStyle(
                height: 0,
              ), // Hide default error to avoid layout jump
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  // --- NEW: Platform-Aware Message ---
  void _showPlatformMessage(
    String title,
    String message,
    Color backgroundColor,
  ) {
    if (isIOSPlatform) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  Future<void> _handlePasswordReset() async { 

    if (_formKey.currentState?.validate() ?? false) {
      isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);

      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        await auth.sendPasswordResetEmail(email: emailController.text.trim());

        if (!context.mounted) return;
        Navigator.pop(context);

        _showPlatformMessage(
          'Success',
          'Password reset link sent to ${emailController.text.trim()}',
          Colors.green,
        );
      } on FirebaseAuthException catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);

        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found for that email address.';
        } else {
          errorMessage = e.message ?? 'An unknown error occurred.';
        }
        _showPlatformMessage('Error', errorMessage, Colors.red);
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);
        _showPlatformMessage(
          'Error',
          'An unexpected error occurred: $e',
          Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: baseColor, // Solid base color for Neumorphism
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 1. CUSTOM BACK BUTTON (Neumorphic)
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: NeumorphicContainer(
                    isPressed: false,
                    borderRadius: 30,
                    padding: const EdgeInsets.all(10),
                    color: baseColor,
                    child: Icon(
                      isIOSPlatform
                          ? CupertinoIcons.arrow_left
                          : Icons.arrow_back,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 2. MAIN CARD (Neumorphic Popped)
              Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: NeumorphicContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(30),
                  color: baseColor,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon Header
                        Center(
                          child: NeumorphicContainer(
                            isPressed: false,
                            borderRadius: 50,
                            padding: const EdgeInsets.all(20),
                            color: baseColor,
                            child: Icon(
                              Icons.lock_reset,
                              size: 40,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter your email address and we will send you a link to reset your password.',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.hintColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // --- NEUMORPHIC INPUT ---
                        _buildNeumorphicTextField(
                          context: context,
                          controller: emailController,
                          placeholder: 'Email Address',
                          icon: isIOSPlatform
                              ? CupertinoIcons.mail
                              : Icons.email,
                          validator: (value) =>
                              TextFieldValidation.email(value!),
                        ),

                        const SizedBox(height: 30),

                        // --- NEUMORPHIC BUTTON ---
                        GestureDetector(
                          onTap: _handlePasswordReset,
                          child: NeumorphicContainer(
                            isPressed: false, // Popped button
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            color: baseColor, // Base color
                            child: Center(
                              child: Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      primaryColor, // Colored text instead of background
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- BACK LINK ---
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Back to Login',
                              style: TextStyle(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
