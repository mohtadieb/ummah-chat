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

  /// Handles login with AuthService
  Future<void> login() async {
    // Hide keyboard first
    FocusScope.of(context).unfocus();

    setState(() => _isLoggingIn = true);

    try {
      // Use AuthService to login
      await _auth.loginEmailPassword(
        emailController.text.trim(),
        pwController.text.trim(),
      );

      // Success — AuthGate handles navigation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Login Error',
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

                      Text(
                        "Welcome back! Login to your account",
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 25),

                      MyTextField(
                        controller: emailController,
                        hintText: "Enter email",
                        obscureText: false,
                      ),

                      const SizedBox(height: 7),

                      MyTextField(
                        controller: pwController,
                        hintText: "Enter password",
                        obscureText: true,
                      ),

                      const SizedBox(height: 28),

                      MyButton(text: "Login", onTap: login),

                      const SizedBox(height: 56),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          GestureDetector(
                            onTap: widget.onTap,
                            child: Text(
                              "Register here",
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Logging in...",
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
