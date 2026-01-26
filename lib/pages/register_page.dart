import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../components/my_button.dart';
import '../components/my_dialogs.dart';
import '../components/my_text_field.dart';
import '../services/auth/auth_service.dart';
import '../services/localization/locale_sync_service.dart';

// ✅ Legal pages
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_use_page.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap; // Callback to switch to LoginPage

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _auth = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  bool _isRegistering = false;

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final pw = pwController.text;
    final confirmPw = confirmPwController.text;

    if (email.isEmpty || pw.isEmpty || confirmPw.isEmpty) {
      showAppErrorDialog(
        context,
        title: "Registration Error".tr(),
        message: "Please fill in all fields.".tr(),
      );
      return;
    }

    if (pw != confirmPw) {
      showAppErrorDialog(
        context,
        title: "Registration Error".tr(),
        message: "Passwords don't match.".tr(),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await _auth.registerEmailPassword(email, pw);

      // ✅ NEW: ensure profile locale is saved
      await LocaleSyncService.syncLocaleToSupabase(context);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created! Please check your email to verify your address before logging in.'
                .tr(),
          ),
        ),
      );

      emailController.clear();
      pwController.clear();
      confirmPwController.clear();

      widget.onTap?.call();
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Registration Error'.tr(),
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> registerWithGoogle() async {
    FocusScope.of(context).unfocus();

    setState(() => _isRegistering = true);

    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Google Sign-In Error'.tr(),
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    pwController.dispose();
    confirmPwController.dispose();
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
            TextSpan(text: 'legal.by_registering_prefix'.tr()),
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

                          const SizedBox(height: 18),

                          Text(
                            "Let's create an account for you".tr(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 28),

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

                          const SizedBox(height: 7),

                          MyTextField(
                            controller: confirmPwController,
                            hintText: "Confirm password".tr(),
                            obscureText: true,
                          ),

                          const SizedBox(height: 20),

                          // ✅ NEW: legal links
                          _legalRow(colorScheme),

                          MyButton(
                            text: "Register".tr(),
                            onTap: register,
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

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed:
                              _isRegistering ? null : registerWithGoogle,
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
                                    "Sign up with Google".tr(),
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
                                "Already a member? ".tr(),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 7),
                              GestureDetector(
                                onTap: widget.onTap,
                                child: Text(
                                  "Login here".tr(),
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
        if (_isRegistering)
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
                        "Registering...".tr(),
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
