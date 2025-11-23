import 'package:flutter/material.dart';

/*

INPUT ALERT BOX

This is an alert dialog box that has a text field where the user can type in.
Will use this for things like editing bio, posting a new message, etc.

--------------------------------------------------------------------------------

To use this widget, you need:

- text controller (To access what the user typed)
- hint text (e.g. "Empty bio..")
- a function (e.g. SaveBio())
- text (e.g. "Save")
- optional extra widget (e.g. image picker preview or buttons)

*/

class MyInputAlertBox extends StatelessWidget {
  final TextEditingController textController;
  final String hintText;
  final void Function()? onPressed;
  final String onPressedText;
  final Widget? extraWidget; // 🆕 optional extra widget (e.g., image picker)

  const MyInputAlertBox({
    super.key,
    required this.textController,
    required this.hintText,
    required this.onPressed,
    required this.onPressedText,
    this.extraWidget, // 🆕 pass in optional widget
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    // Alert dialog
    return AlertDialog(
      // Rounded corners
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18), // 🆕 smoother modern radius
      ),

      // Background color
      backgroundColor: color.surface,

      elevation: 12, // 🆕 slight elevation for premium effect

      // Title section (new for aesthetics)
      title: Text(
        "Edit",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: color.primary,
        ),
      ),

      // Content: Text field and optional extra widget
      content: Column(
        mainAxisSize: MainAxisSize.min, // Shrink dialog to fit content
        children: [
          // Text field
          TextField(
            controller: textController,

            // Limit characters
            maxLength: 140,
            maxLines: 4, // 🆕 slightly more space for better writing

            decoration: InputDecoration(
              // hint text
              hintText: hintText,
              hintStyle: TextStyle(color: color.primary), // 🆕 softer hint

              // Color inside of text field
              fillColor: color.secondary, // 🆕 softer interior
              filled: true,

              contentPadding: const EdgeInsets.all(14), // 🆕 nicer spacing

              // Border when text field is unselected
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: color.tertiary),
                borderRadius: BorderRadius.circular(12), // 🆕 softer radius
              ),

              // Border when text field is focused
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: color.primary),
                borderRadius: BorderRadius.circular(12),
              ),

              counterStyle: TextStyle(color: color.primary),
            ),
          ),

          // 🆕 Include extra widget if provided
          if (extraWidget != null) ...[
            const SizedBox(height: 10), // spacing between text field and extra widget
            extraWidget!,
          ],
        ],
      ),

      // Actions
      actionsAlignment: MainAxisAlignment.end, // 🆕 cleaner alignment
      actionsPadding: const EdgeInsets.only(bottom: 10, right: 8),

      actions: [
        // Cancel button
        TextButton(
          onPressed: () {
            // close box
            Navigator.pop(context);

            // clear controller
            textController.clear();
          },
          child: Text(
            "Cancel",
            style: TextStyle(
              color: color.primary, // 🆕 softer cancel color
            ),
          ),
        ),

        // Confirm button
        TextButton(
          onPressed: () {
            // close box
            Navigator.pop(context);

            // execute function
            onPressed!.call();

            // clear controller
            textController.clear();
          },
          style: TextButton.styleFrom(
            foregroundColor: color.inversePrimary,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7), // 🆕 softer button radius
            ),
          ),
          child: Text(
            onPressedText,
            style: const TextStyle(
              fontWeight: FontWeight.bold, // 🆕 stronger emphasis
            ),
          ),
        ),
      ],
    );
  }
}
