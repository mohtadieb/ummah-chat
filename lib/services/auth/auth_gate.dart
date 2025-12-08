// lib/services/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ummah_chat/layouts/main_layout.dart';
import 'package:ummah_chat/services/auth/login_or_register.dart';
import 'package:ummah_chat/pages/complete_profile_page.dart';

import '../notifications/push_notification_service.dart';

/// AUTH GATE
///
/// - If there is a Supabase session:
///     -> go to _ProfileGate (which decides MainLayout vs CompleteProfilePage)
/// - If no session:
///     -> show LoginOrRegister
///
/// Special behaviour:
/// - After onboarding, StartupGate may create AuthGate(startOnRegister: true),
///   so the FIRST time (before the user ever had a session) we show Register first.
/// - Once the user has had ANY session in this app run, logging out should
///   always show the LOGIN page, not the Register page.
class AuthGate extends StatefulWidget {
  final bool startOnRegister;

  const AuthGate({
    super.key,
    this.startOnRegister = false,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Becomes true as soon as we ever see a non-null session in this app run.
  bool _hasHadSessionInThisRun = false;

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Prefer session from the stream; fall back to currentSession
        final session = snapshot.data?.session ?? auth.currentSession;

        if (session != null) {
          // As soon as there's a session once, we remember it
          _hasHadSessionInThisRun = true;
        }

        // 👉 Effective flag:
        // - Before the user ever had a session in this run:
        //     use widget.startOnRegister (true after onboarding, false otherwise)
        // - After the user has had a session once:
        //     ALWAYS show login first on logout
        final bool effectiveStartOnRegister =
            widget.startOnRegister && !_hasHadSessionInThisRun;

        Widget currentScreen;

        if (session != null) {
          // ✅ Logged in → check if profile is complete
          currentScreen = const _ProfileGate(
            key: ValueKey('profile_gate'),
          );
        } else {
          // ❌ Not logged in → show login/register
          currentScreen = LoginOrRegister(
            key: const ValueKey('login_register'),
            startOnRegister: effectiveStartOnRegister,
          );
        }

        return HeroMode(
          enabled: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: currentScreen,
          ),
        );
      },
    );
  }
}

// ------------------------------
// _ProfileGate: decides between MainLayout and CompleteProfilePage
// ------------------------------

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  bool _loading = true;
  bool _profileComplete = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _profileComplete = false;
        _loading = false;
      });
      return;
    }

    // 🔔 NEW: make sure FCM token is synced now that we know who the user is
    await PushNotificationService.syncFcmTokenWithSupabase();

    try {
      // 👇 Make sure these columns exist in your "profiles" table:
      // country (text), gender (text)
      final data = await supabase
          .from('profiles')
          .select('country, gender')
          .eq('id', user.id)
          .maybeSingle();

      final hasProfile = data != null;
      final complete = hasProfile &&
          (data['country'] ?? '').toString().trim().isNotEmpty &&
          (data['gender'] ?? '').toString().trim().isNotEmpty;

      setState(() {
        _profileComplete = complete;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error checking profile: $e');
      setState(() {
        _profileComplete = false;
        _loading = false;
      });
    }
  }

  void _onProfileCompleted() {
    // Called by CompleteProfilePage after successful save.
    setState(() {
      _profileComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileComplete) {
      // ✅ User logged in + profile complete → show main app
      return const MainLayout();
    }

    // ❗ Profile incomplete → show CompleteProfilePage
    return CompleteProfilePage(
      onCompleted: _onProfileCompleted,
    );
  }
}
