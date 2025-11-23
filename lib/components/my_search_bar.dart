import 'package:flutter/material.dart';

/// A rounded search bar used across the app (Search page, Communities, etc.).
///
/// Features:
/// - Rounded pill-shaped border
/// - Uses theme colors for background, text and borders
/// - Optional clear (X) button that appears when there is text
/// - Exposes `onChanged` and `onClear` callbacks so pages can plug in custom logic
class MySearchBar extends StatefulWidget {
  /// Controller for the search text.
  final TextEditingController controller;

  /// Hint text to display when empty.
  final String hintText;

  /// Called every time the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the clear button is pressed (after the controller is cleared).
  final VoidCallback? onClear;

  const MySearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  State<MySearchBar> createState() => _MySearchBarState();
}

class _MySearchBarState extends State<MySearchBar> {
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;

    // Listen for text changes to toggle the clear icon visibility.
    widget.controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final hasTextNow = widget.controller.text.isNotEmpty;
    if (hasTextNow != _hasText) {
      setState(() {
        _hasText = hasTextNow;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: widget.controller,
      style: TextStyle(color: colorScheme.primary),
      cursorColor: colorScheme.primary,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: colorScheme.primary),
        prefixIcon: Icon(Icons.search,
          color: colorScheme.primary,),
        filled: true,
        // Light tint using secondary color, consistent across pages
        fillColor: colorScheme.secondary.withValues(alpha: 0.15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: colorScheme.secondary.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: colorScheme.secondary.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.3,
          ),
        ),
        // Clear button when there's input
        suffixIcon: _hasText
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            widget.controller.clear();
            // Trigger external clear logic (e.g. reset search results)
            if (widget.onClear != null) {
              widget.onClear!();
            }
          },
        )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}
