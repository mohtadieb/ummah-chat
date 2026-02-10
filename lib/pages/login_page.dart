import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/my_button.dart';
import '../components/my_dialogs.dart';
import '../components/my_text_field.dart';
import '../services/auth/auth_service.dart';
import '../services/localization/locale_sync_service.dart';

// ✅ Legal pages
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_use_page.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap; // Callback to switch to RegisterPage

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();

  bool _isLoggingIn = false;

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    setState(() => _isLoggingIn = true);

    try {
      await _auth.loginEmailPassword(
        emailController.text.trim(),
        pwController.text.trim(),
      );

      // ✅ NEW: ensure profile locale is saved
      await LocaleSyncService.syncLocaleToSupabase(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in successfully!'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppErrorDialog(
        context,
        title: 'Login Error'.tr(),
        message: 'login_failed_generic'.tr(),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> loginWithGoogle() async {
    FocusScope.of(context).unfocus();

    setState(() => _isLoggingIn = true);

    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Google Login Error'.tr(),
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> sendResetEmail(String email) async {
    FocusScope.of(context).unfocus();

    final trimmed = email.trim();

    if (trimmed.isEmpty) {
      showAppErrorDialog(
        context,
        title: 'Reset Password'.tr(),
        message: 'Enter your email first.'.tr(),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: 'ummahchat://reset-password',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent. Check your email.'.tr())),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppErrorDialog(
        context,
        title: 'Reset Password'.tr(),
        message: e.message, // ✅ SHOW REAL SUPABASE ERROR
      );
    } catch (e) {
      if (!mounted) return;
      showAppErrorDialog(
        context,
        title: 'Reset Password'.tr(),
        message: e.toString(), // ✅ SHOW ANY OTHER ERROR
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    pwController.dispose();
    super.dispose();
  }

  // 🌍 Modern, borderless language selector (top-right)
  Widget _buildLanguageSelector(ColorScheme colorScheme) {
    final currentLocale = context.locale;

    String compactLabel(Locale current) {
      switch (current.languageCode) {
        case 'en':
          return 'EN';
        case 'nl':
          return 'NL';
        case 'ar':
          return 'العربية';
        case 'fr':
          return 'FR';
        default:
          return current.languageCode.toUpperCase();
      }
    }

    return PopupMenuButton<Locale>(
      tooltip: 'Language'.tr(),
      onSelected: (locale) async {
        await context.setLocale(locale);
        await LocaleSyncService.syncLocaleToSupabase(context);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: Locale('en'), child: Text('English')),
        PopupMenuItem(value: Locale('nl'), child: Text('Nederlands')),
        PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
        PopupMenuItem(value: Locale('fr'), child: Text('Français')), // ✅ add this
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language,
            size: 18,
            color: colorScheme.primary.withOpacity(0.8),
          ),
          const SizedBox(width: 6),
          Text(
            compactLabel(currentLocale),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: colorScheme.primary.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Legal row (Terms + Privacy links)
  Widget _legalRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.65),
            fontSize: 12,
            height: 1.3,
          ),
          children: [
            TextSpan(text: 'legal.by_continuing_prefix'.tr()),
            TextSpan(
              text: 'terms.title'.tr(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
                  );
                },
            ),
            TextSpan(text: 'legal.and'.tr()),
            TextSpan(
              text: 'privacy.title'.tr(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                },
            ),
            TextSpan(text: 'legal.dot'.tr()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Stack(
              children: [
                // 🌍 top-right language selector
                Positioned(
                  top: 12,
                  right: 16,
                  child: _buildLanguageSelector(colorScheme),
                ),

                // main content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),

                          Image.asset(
                            'assets/images/login_page_image_green.png',
                            width: 256,
                            height: 256,
                            fit: BoxFit.contain,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "Welcome back! Login to your account".tr(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 25),

                          MyTextField(
                            controller: emailController,
                            hintText: "Enter email".tr(),
                            obscureText: false,
                          ),

                          const SizedBox(height: 7),

                          MyTextField(
                            controller: pwController,
                            hintText: "Enter password".tr(),
                            obscureText: true,
                          ),

                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _isLoggingIn
                                  ? null
                                  : () => sendResetEmail(emailController.text),
                              child: Text(
                                "Forgot password?".tr(),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          MyButton(
                            text: "Login".tr(),
                            onTap: login,
                          ),

                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  thickness: 0.8,
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  "OR".tr(),
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  thickness: 0.8,
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ✅ NEW: legal links
                          _legalRow(colorScheme),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoggingIn ? null : loginWithGoogle,
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: colorScheme.primary.withOpacity(0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Continue with Google".tr(),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ".tr(),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 7),
                              GestureDetector(
                                onTap: widget.onTap,
                                child: Text(
                                  "Register here".tr(),
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Loading overlay
        if (_isLoggingIn)
          Container(
            color: const Color.fromRGBO(0, 0, 0, 0.25),
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface.withValues(alpha: 0.95),
                elevation: 8,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Logging in...".tr(),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
