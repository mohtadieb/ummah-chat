import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MyInputAlertBox extends StatefulWidget {
  /// ✅ Optional: if you pass one, we will NOT dispose it.
  /// If you don’t pass one, the dialog creates + disposes its own controller safely.
  final TextEditingController? textController;

  final String hintText;

  /// ✅ Backwards compatible (your existing callers)
  final FutureOr<void> Function()? onPressed;

  /// ✅ New: safer for dialogs where you want text without managing controller outside
  final FutureOr<void> Function(String text)? onPressedWithText;

  final String onPressedText;
  final Widget? extraWidget;
  final String title;

  /// Behavior toggles (safe defaults)
  final bool autoClose; // close after success
  final bool clearOnClose; // clear text when closing

  const MyInputAlertBox({
    super.key,
    this.textController,
    required this.hintText,
    this.onPressed,
    this.onPressedWithText,
    required this.onPressedText,
    this.extraWidget,
    this.title = "Edit",
    this.autoClose = true,
    this.clearOnClose = true,
  });

  @override
  State<MyInputAlertBox> createState() => _MyInputAlertBoxState();
}

class _MyInputAlertBoxState extends State<MyInputAlertBox> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.textController == null;
    _controller = widget.textController ?? TextEditingController();
  }

  @override
  void dispose() {
    // ✅ Only dispose if we created it
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _safeClose() {
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    if (widget.clearOnClose) {
      _controller.clear();
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);

    try {
      // ✅ Run the right callback
      if (widget.onPressedWithText != null) {
        await Future.sync(() => widget.onPressedWithText!(text));
      } else {
        // fallback to old signature (no args)
        if (widget.onPressed != null) {
          await Future.sync(widget.onPressed!);
        }
      }

      if (!mounted) return;

      if (widget.autoClose) {
        // ✅ Close at end of frame to avoid controller/listener issues during rebuilds
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _safeClose();
        });
      }
    } catch (e, st) {
      debugPrint('❌ MyInputAlertBox confirm error: $e\n$st');
      // keep dialog open on error
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: color.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag indicator
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),

                // Title row with close button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: color.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : _safeClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: color.outline,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _controller,
                          maxLength: 140,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: color.surfaceContainerHighest,
                            hintText: widget.hintText,
                            hintStyle: TextStyle(color: color.outline),
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: color.primary,
                                width: 1.2,
                              ),
                            ),
                            counterStyle: TextStyle(
                              fontSize: 12,
                              color: color.outline,
                            ),
                          ),
                        ),
                        if (widget.extraWidget != null) ...[
                          const SizedBox(height: 12),
                          widget.extraWidget!,
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : _safeClose,
                      style: TextButton.styleFrom(
                        foregroundColor: color.outline,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        "Cancel".tr(),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _confirm,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: color.primary,
                        foregroundColor: color.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: color.onPrimary,
                        ),
                      )
                          : Text(
                        widget.onPressedText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
