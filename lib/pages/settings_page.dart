import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ummah_chat/components/my_loading_circle.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart'; // 👈 NEW

import '../components/my_dialogs.dart';
import '../components/my_settings_tile.dart';
import '../helper/navigate_pages.dart';
import '../services/auth/auth_gate.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import '../services/localization/locale_sync_service.dart';
import '../services/notifications/notification_service.dart';
import '../themes/theme_provider.dart';
import 'feedback_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _auth = AuthService();

  Future<void> _logout() async {
    FocusScope.of(context).unfocus();

    showLoadingCircle(context, message: "Logging out...".tr());

    try {
      final databaseProvider = Provider.of<DatabaseProvider>(
        context,
        listen: false,
      );

      await _auth.logout();
      databaseProvider.clearAllCachedData();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged out successfully!'.tr())),
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Logout Error'.tr(),
          message: e.toString(),
        );
      }
    } finally {
      hideLoadingCircle(context);
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
        title: Text('Support Ummah Chat'.tr()),
        content: Text('You’ll be redirected to PayPal to make a donation.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue'.tr()),
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

  // 👇 Helper: how to show locale names in the dropdown
  String _localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'nl':
        return 'Nederlands';
      case 'ar':
        return 'العربية';
      default:
        return locale.languageCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // current & supported locales from EasyLocalization
    final currentLocale = context.locale;
    final supportedLocales = context.supportedLocales;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        // later you can do: 'settings_title'.tr()
        title: Text("Settings".tr()),
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
              'Appearance'.tr(), // later: 'settings_appearance'.tr()
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            // Dark mode toggle
            MySettingsTile(
              title: "Dark Mode".tr(), // later: 'settings_dark_mode'.tr()
              leadingIcon: Icons.dark_mode_outlined,

              // ✅ Switch rows should NOT navigate on tile tap
              enabled: false,

              // ✅ New API: use trailing instead of onTap widget
              trailing: CupertinoSwitch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
            ),

            const SizedBox(height: 10),

            // 🌍 Language selector
            MySettingsTile(
              title: "Language".tr(), // later: 'settings_language'.tr()
              leadingIcon: Icons.language_outlined,

              // ✅ Dropdown rows should NOT navigate on tile tap
              enabled: false,

              trailing: DropdownButton<Locale>(
                value: currentLocale,
                underline: const SizedBox(), // no blue underline
                borderRadius: BorderRadius.circular(12),
                items: supportedLocales.map((locale) {
                  return DropdownMenuItem<Locale>(
                    value: locale,
                    child: Text(_localeLabel(locale)),
                  );
                }).toList(),

                // ✅ IMPORTANT: await locale save + rebuild
                onChanged: (newLocale) async {
                  if (newLocale == null) return;

                  if (newLocale.languageCode == context.locale.languageCode) {
                    return;
                  }

                  await context.setLocale(newLocale);

                  // ✅ NEW: store language for push localization
                  await LocaleSyncService.syncLocaleToSupabase(context);

                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ),

            const SizedBox(height: 24),

            // PRIVACY & SAFETY SECTION
            Text(
              'Privacy & Safety'.tr(),
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Blocked Users".tr(),
              leadingIcon: Icons.block_outlined,

              // ✅ Whole tile tap navigates
              onPressed: () async {
                final databaseProvider = Provider.of<DatabaseProvider>(
                  context,
                  listen: false,
                );
                await databaseProvider.loadBlockedUsers();
                goBlockedUsersPage(context);
              },

              // ✅ Trailing icon just for visual hint (tile handles tap)
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // ACCOUNT SECTION
            Text(
              'Account'.tr(),
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Account Settings".tr(),
              leadingIcon: Icons.person_outline,
              onPressed: () => goAccountSettingsPage(context),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // SUPPORT SECTION
            Text(
              'Support'.tr(),
              style: _sectionTitleStyle(context),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Donate".tr(),
              leadingIcon: Icons.favorite_outline,
              onPressed: _openDonateLink,
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // FEEDBACK (same spacing as other tiles/sections)
            MySettingsTile(
              title: 'Feedback'.tr(),
              leadingIcon: Icons.feedback_outlined,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackPage()),
                );
              },
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // DANGER ZONE / LOGOUT
            Text(
              'Danger Zone'.tr(),
              style: _sectionTitleStyle(context).copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Logout".tr(),
              leadingIcon: Icons.logout,
              onPressed: _logout,
              trailing: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
