import 'package:flutter/material.dart';

class MyInputAlertBox extends StatelessWidget {
  final TextEditingController textController;
  final String hintText;
  final VoidCallback onPressed;
  final String onPressedText;
  final Widget? extraWidget;
  final String title;

  const MyInputAlertBox({
    super.key,
    required this.textController,
    required this.hintText,
    required this.onPressed,
    required this.onPressedText,
    this.extraWidget,
    this.title = "Edit",
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero, // Takes full width
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            // Use margin for spacing from screen edges
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.85,
            ),
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
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: color.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        textController.clear();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: color.outline,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: textController,
                          maxLength: 140,
                          maxLines: 4,

                          decoration: InputDecoration(
                            filled: true,
                            fillColor: color.surfaceContainerHighest,
                            hintText: hintText,
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

                        if (extraWidget != null) ...[
                          const SizedBox(height: 12),
                          extraWidget!,
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Buttons
                Row(
                  children: [
                    // Cancel
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        textController.clear();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: color.outline,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),

                    const Spacer(),

                    // Confirm
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onPressed();
                        textController.clear();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: color.primary,
                        foregroundColor: color.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        onPressedText,
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
