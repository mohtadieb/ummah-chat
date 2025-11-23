import 'package:flutter/material.dart';

/*

MY TEXT FIELD

A reusable text input widget.

Usage:
- Provide a TextEditingController to access typed text
- Provide a hint text
- Optionally obscure text (for passwords)

*/

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false, // default to false
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(

        // Border when unselected
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.tertiary),
        ),

        // Border when selected
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),

        filled: true,
        fillColor: Theme.of(context).colorScheme.secondary,
        hintText: hintText,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}