// --- ⭐️ 1. REUSABLE NEUMORPHIC CONTAINER (Copied for consistency) ---
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isPressed;
  final Color? color;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 15.0,
    this.padding = const EdgeInsets.all(12.0),
    this.isPressed = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Theme.of(context).scaffoldBackgroundColor;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color lightShadow = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color.fromARGB(255, 241, 240, 240).withOpacity(0.9);

    Color darkShadow = isDark
        ? Colors.black.withOpacity(0.5)
        : Colors.blueGrey.withOpacity(0.2);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // border: Border.symmetric(
        //   vertical: BorderSide(width: 5, color: Colors.purple),
        // ),
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: darkShadow,
                  offset: const Offset(2, 3),
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: lightShadow,
                  offset: const Offset(-5, -3),
                  blurRadius: 5,
                ),
              ]
            : [
                BoxShadow(
                  color: darkShadow,
                  offset: const Offset(6, 6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: lightShadow,
                  offset: const Offset(-6, -6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: child,
    );
  }
}

// Neumorphic Color Palette
class NeuTheme {
  static const Color background = Color(0xFFE0E5EC);
  static const Color lightShadow = Colors.white;
  static const Color darkShadow = Color(0xFFA3B1C6);
  static const Color text = Color(0xFF4A5568);
  static const Color accent = Color(0xFF007BFF);
}

class NeuButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  const NeuButton({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: NeuTheme.background,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isPressed
              ? [
                  // Flat/Pressed state (Low elevation)
                  const BoxShadow(
                    color: NeuTheme.darkShadow,
                    offset: Offset(2, 2),
                    blurRadius: 3,
                  ),
                  const BoxShadow(
                    color: NeuTheme.lightShadow,
                    offset: Offset(-2, -2),
                    blurRadius: 3,
                  ),
                ]
              : [
                  // Unpressed state (High elevation)
                  const BoxShadow(
                    color: NeuTheme.darkShadow,
                    offset: Offset(6, 6),
                    blurRadius: 10,
                  ),
                  const BoxShadow(
                    color: NeuTheme.lightShadow,
                    offset: Offset(-6, -6),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}
