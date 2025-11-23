import 'package:flutter/material.dart';
import 'package:ummah_chat/pages/login_page.dart';
import 'package:ummah_chat/pages/register_page.dart';

/*

LOGIN OR REGISTER PAGE

This widget determines whether to display the LoginPage or RegisterPage
based on user interaction.

- Initially, the LoginPage is displayed.
- Users can toggle between Login and Register using the onTap callback.

This keeps your authentication flow clean and modular:
  - LoginPage handles sign-in with Supabase
  - RegisterPage handles sign-up with Supabase

*/

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  // Initially show login page
  bool showLoginPage = true;

  /// Toggle between LoginPage and RegisterPage.
  ///
  /// We also hide the keyboard to avoid flicker when switching screens.
  void togglePages() {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Decide which page to show
    final Widget page = showLoginPage
        ? LoginPage(
      key: const ValueKey('login_page'),
      onTap: togglePages,
    )
        : RegisterPage(
      key: const ValueKey('register_page'),
      onTap: togglePages,
    );

    // Wrap with AnimatedSwitcher for smooth transitions
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Fade transition (clean and lightweight)
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: page,
    );
  }
}
