import 'package:flutter/material.dart';

class Custom_Button extends StatelessWidget {
  final Function() onPressed;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final double minWidth;
  const Custom_Button({
    super.key,
    required this.onPressed,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor, required this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(text),
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
        ),
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
        foregroundColor: WidgetStatePropertyAll(foregroundColor),
        minimumSize: WidgetStatePropertyAll(Size(minWidth, 50)),
 
      ),
    );
  }
}
