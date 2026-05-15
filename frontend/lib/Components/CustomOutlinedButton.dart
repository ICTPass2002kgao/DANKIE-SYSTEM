import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  final Function() onPressed;
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? width;
  const CustomOutlinedButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
      this.width,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(text),
      style: ButtonStyle(
        elevation: WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(Theme.of(context).primaryColor),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
        ),
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
        foregroundColor: WidgetStatePropertyAll(foregroundColor),
        minimumSize: WidgetStatePropertyAll(Size(width!, 50)),
      ),
    );
  }
}
