import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Helper for platform-specific text field
Widget buildPlatformTextField(
  BuildContext context, {
  required TextEditingController controller,
  required String placeholder,
  TextInputType? keyboardType,
  bool obscureText = false,
  IconData? prefixIcon,
}) {
  final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;

  if (isCupertino) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        keyboardType: keyboardType,
        prefix: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(prefixIcon, color: Colors.grey),
              )
            : null,
        padding: const EdgeInsets.all(14.0),
      ),
    );
  } else {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: placeholder,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14.0),
        ),
      ),
    );
  }
}
