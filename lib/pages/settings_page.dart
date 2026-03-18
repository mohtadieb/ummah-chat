import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ummah_chat/components/my_loading_circle.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../components/my_dialogs.dart';
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

  static const LinearGradient _brandGradient = LinearGradient(
    colors: [
      Color(0xFF0F8254),
      Color(0xFF16A36A),
      Color(0xFF44C48A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

  Future<void> _confirmLogout() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (context) {
        final dialogCs = Theme.of(context).colorScheme;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: dialogCs.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: dialogCs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log out?'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: dialogCs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to log out of your Ummah Chat account on this device?'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: dialogCs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: dialogCs.surfaceContainerHighest,
                          side: BorderSide(color: dialogCs.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Cancel'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: dialogCs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _brandGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Log out'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _openDonateLink() async {
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (context) {
        final dialogCs = Theme.of(context).colorScheme;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: dialogCs.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: dialogCs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: dialogCs.secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: dialogCs.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Support Ummah Chat'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: dialogCs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You’ll be redirected to PayPal to make a donation.'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: dialogCs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: dialogCs.surfaceContainerHighest,
                          side: BorderSide(color: dialogCs.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Cancel'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: dialogCs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _brandGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Continue'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Settings'.tr(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.14),
              cs.secondary.withValues(alpha: 0.55),
              cs.surfaceContainerHigh,
            ],
          ),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.14),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings'.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ummah Chat',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your app, privacy, language, and account preferences in one place.'
                        .tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.72),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconBg,
    Color? iconColor,
    Color? titleColor,
    Color? subtitleColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? cs.surfaceContainerHighest
              : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg ?? cs.secondary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: iconColor ?? cs.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor ?? cs.onSurface.withOpacity(0.68),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withOpacity(0.38),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentLocale = context.locale;
    final supportedLocales = context.supportedLocales;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildHeroCard(context),
            const SizedBox(height: 18),

            _sectionCard(
              context: context,
              title: 'Appearance'.tr(),
              children: [
                _settingsTile(
                  context: context,
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode'.tr(),
                  subtitle: 'Switch between light and dark appearance.'.tr(),
                  trailing: CupertinoSwitch(
                    value: themeProvider.isDarkMode,
                    activeColor: cs.primary,
                    onChanged: (value) => themeProvider.toggleTheme(),
                  ),
                ),
                const SizedBox(height: 12),
                _settingsTile(
                  context: context,
                  icon: Icons.language_outlined,
                  title: 'Language'.tr(),
                  subtitle: _localeLabel(currentLocale),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<Locale>(
                      value: currentLocale,
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: cs.surfaceContainer,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      items: supportedLocales.map((locale) {
                        return DropdownMenuItem<Locale>(
                          value: locale,
                          child: Text(
                            _localeLabel(locale),
                            style: TextStyle(color: cs.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (newLocale) async {
                        if (newLocale == null) return;
                        if (newLocale.languageCode ==
                            context.locale.languageCode) {
                          return;
                        }

                        await context.setLocale(newLocale);
                        await LocaleSyncService.syncLocaleToSupabase(context);

                        if (!mounted) return;
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _sectionCard(
              context: context,
              title: 'Privacy & Safety'.tr(),
              children: [
                _settingsTile(
                  context: context,
                  icon: Icons.block_outlined,
                  title: 'Blocked Users'.tr(),
                  subtitle: 'Manage the people you have blocked.'.tr(),
                  onTap: () async {
                    final databaseProvider = Provider.of<DatabaseProvider>(
                      context,
                      listen: false,
                    );
                    await databaseProvider.loadBlockedUsers();
                    goBlockedUsersPage(context);
                  },
                ),
                const SizedBox(height: 12),
                Consumer<DatabaseProvider>(
                  builder: (_, db, __) {
                    final v = db.profileVisibility.trim().toLowerCase();
                    final safeV = (v == 'friends' ||
                        v == 'nobody' ||
                        v == 'everyone')
                        ? v
                        : 'everyone';

                    return _settingsTile(
                      context: context,
                      icon: Icons.visibility_outlined,
                      title: 'Profile visibility'.tr(),
                      subtitle: _visibilityLabel(safeV),
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeV,
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: cs.surfaceContainer,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'everyone',
                              child: Text(
                                _visibilityLabel('everyone'),
                                style: TextStyle(color: cs.onSurface),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'friends',
                              child: Text(
                                _visibilityLabel('friends'),
                                style: TextStyle(color: cs.onSurface),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'nobody',
                              child: Text(
                                _visibilityLabel('nobody'),
                                style: TextStyle(color: cs.onSurface),
                              ),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val == null) return;
                            if (val == safeV) return;
                            await db.setProfileVisibility(visibility: val);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _sectionCard(
              context: context,
              title: 'Account'.tr(),
              children: [
                _settingsTile(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'Account Settings'.tr(),
                  subtitle: 'Manage your personal account details.'.tr(),
                  onTap: () => goAccountSettingsPage(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _sectionCard(
              context: context,
              title: 'Support'.tr(),
              children: [
                _settingsTile(
                  context: context,
                  icon: Icons.favorite_outline,
                  title: 'Donate'.tr(),
                  subtitle: 'Support the continued growth of Ummah Chat.'.tr(),
                  onTap: _openDonateLink,
                ),
                const SizedBox(height: 12),
                _settingsTile(
                  context: context,
                  icon: Icons.feedback_outlined,
                  title: 'Feedback'.tr(),
                  subtitle: 'Share ideas, suggestions, or report issues.'.tr(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackPage()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            _sectionCard(
              context: context,
              title: 'Danger Zone'.tr(),
              children: [
                _settingsTile(
                  context: context,
                  icon: Icons.logout_rounded,
                  title: 'Logout'.tr(),
                  subtitle: 'Sign out from this device.'.tr(),
                  onTap: _confirmLogout,
                  iconBg: cs.error.withOpacity(0.10),
                  iconColor: cs.error,
                  titleColor: cs.error,
                  subtitleColor: cs.error.withOpacity(0.82),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.error.withOpacity(0.82),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}