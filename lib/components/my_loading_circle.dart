// lib/components/my_loading_circle.dart
import 'package:flutter/material.dart';

/*
LOADING CIRCLE

- Global, reusable loading dialog.
- Tracks its own dialog context so it can always be closed safely,
  even after navigation changes (AuthGate, push/pop, etc.).
- Shows an optional message like "Logging in..." or "Registering...".
*/

bool _isDialogShowing = false;
BuildContext? _loadingDialogContext;

/// Shows a blocking loading dialog with an optional [message].
///
/// Usage:
///   showLoadingCircle(context, message: "Logging in...");
Future<void> showLoadingCircle(
    BuildContext context, {
      String? message,
    }) async {
  if (_isDialogShowing) return;
  _isDialogShowing = true;

  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      // Save the dialog's own context so we can reliably pop it later.
      _loadingDialogContext = dialogContext;

      return PopScope(
        canPop: false, // 👈 replaces deprecated WillPopScope
        child: Center(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surface.withValues(alpha: 0.95),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Safe way to close the loading circle (prevents Navigator errors).
///
/// Uses the stored [_loadingDialogContext] if available.
/// If the dialog is already gone, this will quietly no-op.
void hideLoadingCircle(BuildContext context) {
  if (!_isDialogShowing) return;
  _isDialogShowing = false;

  try {
    final ctx = _loadingDialogContext ?? context;
    final navigator = Navigator.of(ctx, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }
  } catch (_) {
    // In rare cases (e.g., after aggressive navigation),
    // the dialog might already be gone — just ignore.
  } finally {
    _loadingDialogContext = null;
  }
}
