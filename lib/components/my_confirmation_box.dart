import 'package:flutter/material.dart';

class MyConfirmationBox extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final VoidCallback onConfirm;

  const MyConfirmationBox({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // close dialog first
            await Future.delayed(const Duration(milliseconds: 100));
            onConfirm(); // execute passed function
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}
