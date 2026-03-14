import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/*

USER BIO BOX

This is a simple box with text inside. We will use this for the user bio on their profile pages.

--------------------------------------------------------------------------------

To use this widget, you just need:

- text

*/

class MyBioBox extends StatelessWidget {
  final String text;

  const MyBioBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trimmed = text.trim();

    return Text(
      trimmed.isNotEmpty ? trimmed : "empty_bio".tr(),
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.88),
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    );
  }
}