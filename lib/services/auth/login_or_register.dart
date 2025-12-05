import 'package:flutter/material.dart';
import 'package:ummah_chat/pages/login_page.dart';
import 'package:ummah_chat/pages/register_page.dart';

/*

LOGIN OR REGISTER PAGE

*/

class LoginOrRegister extends StatefulWidget {
  /// If true → start directly on the RegisterPage
  final bool startOnRegister;

  const LoginOrRegister({
    super.key,
    this.startOnRegister = false,
  });

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  late bool showLoginPage;

  @override
  void initState() {
    super.initState();
    // ✅ If startOnRegister == true → show register first
    showLoginPage = !widget.startOnRegister;
  }

  void togglePages() {
    FocusScope.of(context).unfocus();
    setState(() => showLoginPage = !showLoginPage);
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = showLoginPage
        ? LoginPage(
      key: const ValueKey('login_page'),
      onTap: togglePages,
    )
        : RegisterPage(
      key: const ValueKey('register_page'),
      onTap: togglePages,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: page,
    );
  }
}
