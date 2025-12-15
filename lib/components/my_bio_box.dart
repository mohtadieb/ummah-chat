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

    // Container
    return Container(
      // Padding outside
      margin: const EdgeInsets.symmetric(horizontal: 28.0),

      // Padding inside
      padding: const EdgeInsets.all(28.0),

      // Decoration
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary, // background color
        borderRadius: BorderRadius.circular(7), // rounded corners
      ),

      // Text content
      child: Text(
        text.isNotEmpty ? text : "Empty bio..".tr(), // fallback if bio is empty
        style: TextStyle(
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
      ),
    );
  }
}