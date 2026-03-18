import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';

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

  void _confirmDeletion(BuildContext context) {
    _errorMessage = '';
    _passwordController.clear();

    final cs = Theme.of(context).colorScheme;

    showDialog(
      barrierDismissible: !_isDeleting,
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                    color: cs.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: cs.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Confirm Account Deletion".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "To confirm deletion, please re-enter your password. This action is irreversible."
                      .tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isDeleting,
                  decoration: InputDecoration(
                    labelText: "Password".tr(),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      color: cs.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_isDeleting) ...[
                  const SizedBox(height: 18),
                  Column(
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 12),
                      Text("Deleting account...".tr()),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                        _isDeleting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: cs.surfaceContainerHighest,
                          side: BorderSide(color: cs.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          "Cancel".tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting
                            ? null
                            : () async {
                          final password =
                          _passwordController.text.trim();

                          if (password.isEmpty) {
                            setLocalState(() {
                              _errorMessage =
                                  "Please enter your password.".tr();
                            });
                            return;
                          }

                          setLocalState(() {
                            _isDeleting = true;
                            _errorMessage = '';
                          });

                          try {
                            await _auth.deleteAccountWithPassword(password);

                            if (mounted) {
                              Navigator.pop(context);
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                    (route) => false,
                              );
                            }
                          } catch (e) {
                            setLocalState(() {
                              _isDeleting = false;
                              _errorMessage =
                                  "Deletion failed. Check password or try again."
                                      .tr();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          "Delete".tr(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
    );
  }

  Widget _buildPremiumHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
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
              Icons.manage_accounts_outlined,
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
                  "Account".tr(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Account Settings".tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage important actions related to your account and security."
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
    );
  }

  Widget _dangerCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Danger Zone".tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.error,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Deleting your account will permanently remove your data and cannot be undone."
                .tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDeletion(context),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(
                "Delete account".tr(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                minimumSize: const Size.fromHeight(54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _buildPremiumHeader(),
            const SizedBox(height: 18),
            _dangerCard(),
          ],
        ),
      ),
    );
  }
}