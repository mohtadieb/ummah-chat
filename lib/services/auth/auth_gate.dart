import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ummah_chat/layouts/main_layout.dart';
import 'package:ummah_chat/services/auth/login_or_register.dart';

/*
AUTH GATE (Supabase Version)

Checks if the user is logged in or not:

- logged in  -> MainLayout
- not logged in -> LoginOrRegister
*/

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final _auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: _auth.onAuthStateChange,
      builder: (context, _) {
        final session = _auth.currentSession;

        // Choose which screen to show
        final Widget currentScreen = session != null
            ? const MainLayout()        // User logged in
            : const LoginOrRegister();  // User not logged in

        // Wrap with HeroMode to disable Hero animations in this subtree
        return HeroMode(
          enabled: false, // 👈 No Hero transitions (incl. SnackBar heroes)
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: currentScreen,
          ),
        );
      },
    );
  }
}
