import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/components/my_loading_circle.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../components/my_dialogs.dart';
import '../components/my_settings_tile.dart';
import '../helper/navigate_pages.dart';
import '../services/auth/auth_service.dart';
import '../services/database/database_provider.dart';
import '../services/localization/locale_sync_service.dart';
import '../themes/theme_provider.dart';
import 'feedback_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _auth = AuthService();

  // ✅ Your app green (same as you use elsewhere)
  static const Color _ummahGreen = Color(0xFF0F8254);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DatabaseProvider>().hydrateMyProfileVisibility();
    });
  }

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

  String _localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'nl':
        return 'Nederlands';
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      default:
        return locale.languageCode;
    }
  }

  String _visibilityLabel(String v) {
    switch (v.trim().toLowerCase()) {
      case 'friends':
        return 'Friends'.tr();
      case 'nobody':
        return 'Nobody'.tr();
      case 'everyone':
      default:
        return 'Everyone'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cs = Theme.of(context).colorScheme;

    final currentLocale = context.locale;
    final supportedLocales = context.supportedLocales;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text("Settings".tr()),
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
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
            Text('Appearance'.tr(), style: _sectionTitleStyle(context)),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Dark Mode".tr(),
              leadingIcon: Icons.dark_mode_outlined,
              enabled: true,
              trailing: CupertinoSwitch(
                value: themeProvider.isDarkMode,
                activeColor: _ummahGreen,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
            ),

            const SizedBox(height: 10),

            MySettingsTile(
              title: "Language".tr(),
              leadingIcon: Icons.language_outlined,
              enabled: true,
              trailing: DropdownButton<Locale>(
                value: currentLocale,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                dropdownColor: cs.surface,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
                items: supportedLocales.map((locale) {
                  return DropdownMenuItem<Locale>(
                    value: locale,
                    child: Text(
                      _localeLabel(locale),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newLocale) async {
                  if (newLocale == null) return;

                  if (newLocale.languageCode == context.locale.languageCode) {
                    return;
                  }

                  await context.setLocale(newLocale);

                  await LocaleSyncService.syncLocaleToSupabase(context);

                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ),

            const SizedBox(height: 24),

            Text('Privacy & Safety'.tr(), style: _sectionTitleStyle(context)),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Blocked Users".tr(),
              leadingIcon: Icons.block_outlined,
              onPressed: () async {
                final databaseProvider = Provider.of<DatabaseProvider>(
                  context,
                  listen: false,
                );
                await databaseProvider.loadBlockedUsers();
                goBlockedUsersPage(context);
              },
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: cs.primary,
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Profile visibility dropdown (replaces private toggle)
            MySettingsTile(
              title: "Profile visibility".tr(),
              leadingIcon: Icons.visibility_outlined,
              enabled: true,
              trailing: Consumer<DatabaseProvider>(
                builder: (_, db, __) {
                  final v = (db.profileVisibility).trim().toLowerCase();
                  final safeV = (v == 'friends' || v == 'nobody' || v == 'everyone')
                      ? v
                      : 'everyone';

                  return DropdownButton<String>(
                    value: safeV,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: cs.surface,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'everyone',
                        child: Text(_visibilityLabel('everyone')),
                      ),
                      DropdownMenuItem(
                        value: 'friends',
                        child: Text(_visibilityLabel('friends')),
                      ),
                      DropdownMenuItem(
                        value: 'nobody',
                        child: Text(_visibilityLabel('nobody')),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val == null) return;
                      if (val == safeV) return;
                      await db.setProfileVisibility(visibility: val);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Text('Account'.tr(), style: _sectionTitleStyle(context)),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Account Settings".tr(),
              leadingIcon: Icons.person_outline,
              onPressed: () => goAccountSettingsPage(context),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: cs.primary,
              ),
            ),

            const SizedBox(height: 24),

            Text('Support'.tr(), style: _sectionTitleStyle(context)),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Donate".tr(),
              leadingIcon: Icons.favorite_outline,
              onPressed: _openDonateLink,
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: cs.primary,
              ),
            ),

            const SizedBox(height: 24),

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
                color: cs.primary,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Danger Zone'.tr(),
              style: _sectionTitleStyle(context).copyWith(
                color: cs.error.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),

            MySettingsTile(
              title: "Logout".tr(),
              leadingIcon: Icons.logout,
              onPressed: _logout,
              trailing: Icon(
                Icons.logout,
                color: cs.error,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
