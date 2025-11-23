import 'package:flutter/material.dart';
import 'package:ummah_chat/services/database/database_service.dart';
import '../components/my_button.dart';
import '../components/my_dialogs.dart';
import '../components/my_text_field.dart';
import '../services/auth/auth_service.dart';

/*
REGISTER PAGE (Supabase Version)

This page allows a new user to create an account using Supabase authentication.
We need:

- Name
- Email
- Password
- Confirm Password

--------------------------------------------------------------------------------

Once the user successfully created an account they will be redirected to home page
via AuthGate (listening to auth changes).

Also, if user already has an account, they can go to login page from here.
*/

class RegisterPage extends StatefulWidget {
  final void Function()? onTap; // Callback to switch to LoginPage

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // services
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  // Text Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  // Local loading state
  bool _isRegistering = false;

  /// Register user
  Future<void> register() async {
    // Hide keyboard first to avoid flicker
    FocusScope.of(context).unfocus();

    // Password check
    if (pwController.text != confirmPwController.text) {
      showAppErrorDialog(
        context,
        title: "Registration Error",
        message: "Passwords don't match",
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      // 1) Create Supabase user
      await _auth.registerEmailPassword(
        emailController.text.trim(),
        pwController.text.trim(),
      );

      // 2) Save profile in database
      await _db.saveUserInDatabase(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );

      // 3) Optional success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
      }

      // ⚠️ Navigation is handled by AuthGate listening to auth changes,
      // so we don't push MainLayout here manually.
    } catch (e) {
      if (mounted) {
        showAppErrorDialog(
          context,
          title: 'Registration Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    pwController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }

  // Build UI
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // SCAFFOLD
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

                      //TEXT
                      Text(
                        "Let's create an account for you",
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Name Text Field
                      MyTextField(
                        controller: nameController,
                        hintText: "Enter name",
                        obscureText: false,
                      ),

                      const SizedBox(height: 7),

                      //Email Text Field
                      MyTextField(
                        controller: emailController,
                        hintText: "Enter email",
                        obscureText: false,
                      ),

                      const SizedBox(height: 7),

                      //Password Text Field
                      MyTextField(
                        controller: pwController,
                        hintText: "Enter password",
                        obscureText: true,
                      ),

                      const SizedBox(height: 7),

                      // Confirm password text field
                      MyTextField(
                        controller: confirmPwController,
                        hintText: "Confirm password",
                        obscureText: true,
                      ),

                      const SizedBox(height: 28),

                      // Register button
                      MyButton(text: "Register", onTap: register),

                      const SizedBox(height: 56),

                      // Text
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

                          // Register tap
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

        // 🔄 Local loading overlay
        if (_isRegistering)
          Container(
            // semi-transparent black overlay
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
