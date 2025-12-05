import 'package:flutter/material.dart';

import '../components/my_button.dart';
import '../components/my_dialogs.dart';
import '../components/my_text_field.dart';
import '../services/auth/auth_service.dart';

/// REGISTER PAGE (Supabase Version)
///
/// Only handles account credentials:
/// - Email
/// - Password
/// - Confirm Password
///
/// Profile details (name, country, gender) are asked
/// on CompleteProfilePage after registration/login.
class RegisterPage extends StatefulWidget {
  final void Function()? onTap; // Callback to switch to LoginPage

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _auth = AuthService();

  // Text Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  bool _isRegistering = false;

  Future<void> register() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final pw = pwController.text;
    final confirmPw = confirmPwController.text;

    if (email.isEmpty || pw.isEmpty || confirmPw.isEmpty) {
      showAppErrorDialog(
        context,
        title: "Registration Error",
        message: "Please fill in all fields.",
      );
      return;
    }

    if (pw != confirmPw) {
      showAppErrorDialog(
        context,
        title: "Registration Error",
        message: "Passwords don't match.",
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await _auth.registerEmailPassword(email, pw);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
      }
      // 👉 AuthGate + your logic should route to CompleteProfilePage next.
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Registration Error',
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

                      // Logo / illustration
                      Image.asset(
                        'assets/login_page_image_green.png',
                        width: 256,
                        height: 256,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 7),

                      Text(
                        "Let's create an account for you",
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 28),

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

                      const SizedBox(height: 7),

                      MyTextField(
                        controller: confirmPwController,
                        hintText: "Confirm password",
                        obscureText: true,
                      ),

                      const SizedBox(height: 28),

                      MyButton(
                        text: "Register",
                        onTap: register,
                      ),

                      const SizedBox(height: 56),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already a member? ",
                            style: TextStyle(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          GestureDetector(
                            onTap: widget.onTap,
                            child: Text(
                              "Login here",
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Registering...",
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
