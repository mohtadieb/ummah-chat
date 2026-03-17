import 'package:flutter/material.dart';

/*

MY TEXT FIELD

Reusable text input widget with:
- theme-based borders
- optional password visibility icon
- green-tinted fill matching the app theme

*/

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.55),
        ),

        suffixIcon: suffixIcon,

        filled: true,

        // ✅ Green-tinted fill instead of pink surface color
        fillColor: colorScheme.primary.withValues(alpha: 0.06),

        // Border when not focused
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),

        // Border when focused
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.6,
          ),
        ),

        // Error borders
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.error,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.6,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}