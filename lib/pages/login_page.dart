import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../components/my_button.dart';
import '../components/my_dialogs.dart';
import '../components/my_text_field.dart';
import '../services/auth/auth_service.dart';

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

  // Local loading state
  bool _isLoggingIn = false;

  /// Handles login with AuthService (email/password)
  Future<void> login() async {
    // Hide keyboard first
    FocusScope.of(context).unfocus();

    setState(() => _isLoggingIn = true);

    try {
      await _auth.loginEmailPassword(
        emailController.text.trim(),
        pwController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in successfully!'.tr())),
        );
      }
      // Navigation is handled by your AuthGate
    } catch (e) {
      if (!mounted) return;
      showAppErrorDialog(
        context,
        title: 'Login Error'.tr(),
        message: 'login_failed_generic'.tr(),
        );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  /// 🔐 Login / register with Google via AuthService
  Future<void> loginWithGoogle() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoggingIn = true);

    try {
      await _auth.signInWithGoogle();
      // On mobile: app goes to browser, then returns via deep link.
      // Your AuthGate should react to the new session automatically.
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Google Login Error'.tr(),
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 7),

                      // Logo
                      Image.asset(
                        'assets/login_page_image_green.png',
                        width: 256,
                        height: 256,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 7),

                      Text("Welcome back! Login to your account".tr(),
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

                      const SizedBox(height: 28),

                      MyButton(
                        text: "Login".tr(),
                        onTap: login,
                      ),

                      const SizedBox(height: 24),

                      // ---------- OR separator ----------
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
                            child: Text("OR".tr(),
                              style: TextStyle(
                                color:
                                colorScheme.onSurface.withOpacity(0.7),
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

                      // 🔐 Google Login button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoggingIn ? null : loginWithGoogle,
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color:
                              colorScheme.primary.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Optional: add Google logo asset here
                              // Image.asset('assets/google_logo.png', height: 20),
                              // const SizedBox(width: 8),
                              Text("Continue with Google".tr(),
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
                          Text("Don't have an account? ".tr(),
                            style: TextStyle(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          GestureDetector(
                            onTap: widget.onTap,
                            child: Text("Register here".tr(),
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
          ),
        ),

        // 🔄 Local loading overlay
        if (_isLoggingIn)
          Container(
            color: const Color.fromRGBO(0, 0, 0, 0.25),
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface.withValues(alpha: 0.95),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text("Logging in...".tr(),
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
