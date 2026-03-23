import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ummah_chat/layouts/main_layout.dart';
import 'package:ummah_chat/services/auth/login_or_register.dart';
import 'package:ummah_chat/pages/complete_profile_page.dart';
import 'package:ummah_chat/pages/relationship_onboarding_page.dart';

import '../localization/locale_sync_service.dart';
import '../notifications/push_notification_service.dart';

/// AUTH GATE
///
/// - If there is a Supabase session:
///     -> go to _ProfileGate (which decides CompleteProfilePage vs
///        RelationshipOnboardingPage vs MainLayout)
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
          // ✅ Logged in → check if profile is complete, then relationship onboarding
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
// _ProfileGate: decides between
// CompleteProfilePage -> RelationshipOnboardingPage -> MainLayout
// ------------------------------

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  static const String _seenRelationshipOnboardingKey =
      'seen_relationship_onboarding';

  bool _loading = true;
  bool _profileComplete = false;
  bool _relationshipOnboardingSeen = false;

  @override
  void initState() {
    super.initState();
    _checkProfileAndOnboarding();
  }

  Future<void> _checkProfileAndOnboarding() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profileComplete = false;
        _relationshipOnboardingSeen = false;
        _loading = false;
      });
      return;
    }

    // 🔔 Make sure FCM token is synced now that we know who the user is
    await PushNotificationService.syncFcmTokenWithSupabase();

    // 🌍 Sync selected app language to Supabase (so pushes can localize)
    await LocaleSyncService.syncLocaleToSupabase(context);

    try {
      // Check profile completion
      final data = await supabase
          .from('profiles')
          .select('country, gender')
          .eq('id', user.id)
          .maybeSingle();

      final hasProfile = data != null;
      final complete = hasProfile &&
          (data['country'] ?? '').toString().trim().isNotEmpty &&
          (data['gender'] ?? '').toString().trim().isNotEmpty;

      // Only check relationship onboarding if profile is complete
      bool relationshipSeen = false;
      if (complete) {
        final prefs = await SharedPreferences.getInstance();
        relationshipSeen =
            prefs.getBool(_seenRelationshipOnboardingKey) ?? false;
      }

      if (!mounted) return;
      setState(() {
        _profileComplete = complete;
        _relationshipOnboardingSeen = relationshipSeen;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error checking profile/onboarding: $e');

      if (!mounted) return;
      setState(() {
        _profileComplete = false;
        _relationshipOnboardingSeen = false;
        _loading = false;
      });
    }
  }

  void _onProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final relationshipSeen =
        prefs.getBool(_seenRelationshipOnboardingKey) ?? false;

    if (!mounted) return;
    setState(() {
      _profileComplete = true;
      _relationshipOnboardingSeen = relationshipSeen;
    });
  }

  void _onRelationshipOnboardingFinished() {
    if (!mounted) return;
    setState(() {
      _relationshipOnboardingSeen = true;
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

    if (!_profileComplete) {
      // ❗ Profile incomplete → show CompleteProfilePage
      return CompleteProfilePage(
        onCompleted: _onProfileCompleted,
      );
    }

    if (!_relationshipOnboardingSeen) {
      // ✅ Profile complete, but relationship onboarding not seen yet
      return RelationshipOnboardingPage(
        onFinished: _onRelationshipOnboardingFinished,
      );
    }

    // ✅ User logged in + profile complete + relationship onboarding seen
    return const MainLayout();
  }
}