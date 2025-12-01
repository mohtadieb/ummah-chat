import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/components/my_loading_circle.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 NEW

import '../components/my_dialogs.dart';
import '../components/my_settings_tile.dart';
import '../helper/navigate_pages.dart';
import '../services/auth/auth_gate.dart'; // you can actually remove this now if unused
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import '../themes/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Auth Service
  final AuthService _auth = AuthService(); // Auth logic

  /// Handles logout via AuthService
  Future<void> _logout() async {
    // Hide keyboard if something somehow has focus
    FocusScope.of(context).unfocus();

    showLoadingCircle(context, message: "Logging out...");

    try {
      // Get database provider here (context-safe)
      final databaseProvider = Provider.of<DatabaseProvider>(
        context,
        listen: false,
      );

      // Logout from Supabase
      await _auth.logout();

      // Clear any cached user data in provider
      databaseProvider.clearAllCachedData();

      if (!mounted) return;

      // Go back to the root (AuthGate) — this removes SettingsPage
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully!')),
      );

      // AuthGate will detect session change automatically and switch to LoginOrRegister
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Logout Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        hideLoadingCircle(context);
      } else {
        hideLoadingCircle(context);
      }
    }
  }


  TextStyle _sectionTitleStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: colorScheme.primary.withValues(alpha: 0.7),
    );
  }

  Future<void> _openDonateLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Ummah Chat'),
        content: const Text('You’ll be redirected to PayPal to make a donation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uri = Uri.parse(
      'https://www.paypal.com/donate/?hosted_button_id=USB86WSASURYG',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 20.0,
          ),
          children: [
            // APPEARANCE SECTION
            Text(
              'Appearance',
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Dark Mode",
              leadingIcon: Icons.dark_mode_outlined,
              onTap: CupertinoSwitch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
            ),

            const SizedBox(height: 24),

            // PRIVACY & SAFETY SECTION
            Text(
              'Privacy & Safety',
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Blocked Users",
              leadingIcon: Icons.block_outlined,
              onTap: IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () async {
                  final databaseProvider = Provider.of<DatabaseProvider>(
                    context,
                    listen: false,
                  );
                  await databaseProvider.loadBlockedUsers();
                  goBlockedUsersPage(context);
                },
              ),
            ),

            const SizedBox(height: 24),

            // ACCOUNT SECTION
            Text(
              'Account',
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Account Settings",
              leadingIcon: Icons.person_outline,
              onTap: IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => goAccountSettingsPage(context),
              ),
            ),

            const SizedBox(height: 24),

            // SUPPORT SECTION 🇵🇸🤍
            Text(
              'Support',
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Donate",
              leadingIcon: Icons.favorite_outline,
              onTap: IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _openDonateLink,
              ),
            ),


            const SizedBox(height: 32),

            // DANGER ZONE / LOGOUT SECTION
            Text(
              'Danger Zone',
              style: _sectionTitleStyle(context).copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Logout",
              leadingIcon: Icons.logout,
              onTap: IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: _logout,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
