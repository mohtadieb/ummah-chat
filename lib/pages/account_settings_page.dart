import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database/database_provider.dart';
import '../../services/auth/auth_service.dart';
import '../components/my_loading_circle.dart';

/*

ACCOUNT SETTINGS PAGE (Supabase Version)

Allows the user to:
- Confirm and delete their account
- Requires the user to re-enter their password for confirmation
- Shows a progress indicator while deletion is in progress
- Prevents dialog dismissal while deletion is running

*/

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  String _errorMessage = '';
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Opens the confirmation dialog for account deletion
  void _confirmDeletion(BuildContext context) {
    _errorMessage = '';
    _passwordController.clear();

    showDialog(
      barrierDismissible: !_isDeleting,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Confirm Account Deletion"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "To confirm deletion, please re-enter your password. This action is irreversible.",
              ),

              const SizedBox(height: 14),

              // Password input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                enabled: !_isDeleting,
              ),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              // DELETING
              if (_isDeleting)
                Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text("Deleting account..."),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isDeleting ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: _isDeleting
                  ? null
                  : () async {
                final password = _passwordController.text.trim();

                if (password.isEmpty) {
                  setState(() {
                    _errorMessage = "Please enter your password.";
                  });
                  return;
                }

                setState(() => _isDeleting = true);

                try {
                  // Supabase: Re-authenticate and delete
                  await _auth.deleteAccountWithPassword(password);
                  if (mounted) {
                    Navigator.pop(context); // Close dialog

                    // navigate to initial route (Authg gate -> login/register page)
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                          (route) => false,
                    );
                  }
                } catch (e) {
                  setState(() {
                    _isDeleting = false;
                    _errorMessage =
                    "Deletion failed. Check password or try again.";
                  });
                }
              },
              child: const Text("Delete"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //SCAFFOLD
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // App bar
      appBar: AppBar(
        title: const Text("Account Settings"),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [

          // Delete account button
          GestureDetector(
            onTap: () => _confirmDeletion(context),
            child: Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(7),
              ),

              // Delete account text
              child: const Center(
                child: Text(
                  "Delete account",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
