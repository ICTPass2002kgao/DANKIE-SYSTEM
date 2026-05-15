import 'package:flutter/material.dart';

class NeumorphicUtils {
  // Premium Palette for the vertical lines
  static const List<Color> premiumPalette = [
    Color(0xFF6C63FF), // Purple
    Color(0xFF00BFA6), // Teal
    Color(0xFFFF6584), // Pink
    Color(0xFF32A8F7), // Blue
    Color(0xFFFFA726), // Orange
    Color(0xFF7D5FFF), // Indigo
  ];

  static Color getAccentColor(int index) {
    return premiumPalette[index % premiumPalette.length];
  }

  static BoxDecoration decoration({
    required BuildContext context,
    double radius = 15,
    bool isPressed = false,
    bool isDark = false,
    Color? customColor,
  }) {
    final theme = Theme.of(context);
    final baseColor = customColor ??
        Color.alphaBlend(
          theme.primaryColor.withOpacity(0.08),
          theme.scaffoldBackgroundColor,
        );

    Color shadowLight = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    Color shadowDark =
        isDark ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.3);

    if (isPressed) {
      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withOpacity(0.15),
            offset: const Offset(2, 2),
            blurRadius: 4,
             
          ),
          BoxShadow(
            color: shadowLight.withOpacity(0.8),
            offset: const Offset(-2, -2),
            blurRadius: 4,
             
          ),
        ],
        border: Border.all(color: theme.hintColor.withOpacity(0.05)),
      );
    } else {
      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowDark,
            offset: const Offset(3, 3), // Reduced offset for compact look
            blurRadius: 6,
          ),
          BoxShadow(
            color: shadowLight,
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
        ],
      );
    }
  }

  static Widget buildTextField({
    required TextEditingController controller,
    required String placeholder,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0), // Tighter margin
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black : Colors.grey.shade400,
            offset: const Offset(2, 2),
            blurRadius: 4,
             
          ),
          BoxShadow(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            offset: const Offset(-2, -2),
            blurRadius: 4,
             
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 14), // Smaller font
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: theme.hintColor, size: 18)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14.0,
            horizontal: 14.0,
          ),
        ),
      ),
    );
  }
}