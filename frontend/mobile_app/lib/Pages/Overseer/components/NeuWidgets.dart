import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';

// Standard Neumorphic Colors
const Color shadowLight = Color(0xFFFFFFFF);
const Color shadowDark = Color(0xFFA3B1C6);
const Color textColor = Color(0xFF4A5568);
const Color backgroundColor = Color(0xFFFFFFFF);

BoxDecoration neuDecoration({double radius = 16, bool isPressed = false}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: isPressed
        ? []
        : [
            BoxShadow(
              color: shadowDark.withOpacity(0.5),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: shadowLight,
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
  );
}

BoxDecoration neuInnerDecoration({double radius = 8}) {
  return BoxDecoration(
    color: const Color(0xFFD1D9E6),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
    boxShadow: [
      BoxShadow(
        color: shadowDark.withOpacity(0.5),
        offset: const Offset(2, 2),
        blurRadius: 4,
      ),
      BoxShadow(
        color: shadowLight,
        offset: const Offset(-2, -2),
        blurRadius: 4,
      ),
    ],
  );
}

class NeuCard extends StatelessWidget {
  final Widget child;
  final double padding;
  final double radius;

  const NeuCard({
    super.key,
    required this.child,
    this.padding = 20.0,
    this.radius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Api().neumoBaseColor(context),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withOpacity(0.5),
            offset: const Offset(6, 6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: shadowLight,
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}

class NeuTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool readOnly;

  const NeuTextField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: maxLines == 1 ? 45 : null,
          decoration: neuInnerDecoration(radius: 8),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            style: const TextStyle(color: textColor, fontSize: 14),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class NeuButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.backgroundColor = const Color(0xFFD1D9E6),
    this.foregroundColor = textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Api().neumoBaseColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: shadowLight,
            offset: const Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}
