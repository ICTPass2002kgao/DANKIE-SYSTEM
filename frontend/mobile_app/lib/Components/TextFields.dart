import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String?) onValidate;
  final Function(bool?)? onChange;
  final String placeholder;
  final IconData? icon;
  final bool? visible;

  const AuthTextField({
    Key? key,
    this.controller,
    required this.onValidate,
    required this.placeholder,
    this.icon,
    this.visible,
    this.onChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextFormField(
        onChanged: (value) => onChange?.call,
        controller: controller,
        validator: (value) => onValidate(value),
        obscureText: visible ?? false,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: color.primaryColor),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color.primaryColor),
            borderRadius: BorderRadius.circular(10),
          ),
          focusColor: color.primaryColor,
          fillColor: color.scaffoldBackgroundColor,
          filled: true,
          prefixIcon: icon != null
              ? Icon(icon, color: color.primaryColor)
              : null,
          labelText: placeholder,
        ),
      ),
    );
  }
}
