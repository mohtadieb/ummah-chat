import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Centralized app dialogs (errors, confirmations, etc.)

/// Shows a simple error dialog with consistent styling.
///
/// [title]   - The title of the error (e.g. "Login Error").
/// [message] - The body text to show (exception message, etc.).
Future<void> showAppErrorDialog(
    BuildContext context, {
      required String title,
      required String message,
    }) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      backgroundColor: colorScheme.surface,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: colorScheme.primary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('OK'.tr()),
        ),
      ],
    ),
  );
}
