import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pages/relationship_onboarding_page.dart';
import '../../helper/navigate_pages.dart'; // only if needed
import '../../pages/home_page.dart'; // replace if your real entry is MainLayout

class RelationshipEntryGate extends StatefulWidget {
  const RelationshipEntryGate({super.key});

  @override
  State<RelationshipEntryGate> createState() => _RelationshipEntryGateState();
}

class _RelationshipEntryGateState extends State<RelationshipEntryGate> {
  static const String _seenRelationshipOnboardingKey =
      'seen_relationship_onboarding';

  bool _loading = true;
  bool _shouldShowRelationshipOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  Future<void> _loadFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen =
        prefs.getBool(_seenRelationshipOnboardingKey) ?? false;

    if (!mounted) return;
    setState(() {
      _shouldShowRelationshipOnboarding = !seen;
      _loading = false;
    });
  }

  void _finishRelationshipOnboarding() {
    if (!mounted) return;
    setState(() {
      _shouldShowRelationshipOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_shouldShowRelationshipOnboarding) {
      return RelationshipOnboardingPage(
        onFinished: _finishRelationshipOnboarding,
      );
    }

    // Replace this with your real signed-in entry page if needed.
    return const HomePage();
  }
}