import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? recoveryTokenHash;
  final VoidCallback? onPasswordUpdated;

  const ResetPasswordPage({
    super.key,
    this.recoveryTokenHash,
    this.onPasswordUpdated,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();

  bool _isSaving = false;
  bool _obscurePw1 = true;
  bool _obscurePw2 = true;
  bool _hasVerifiedRecoveryToken = false;

  Future<void> _saveNewPassword() async {
    FocusScope.of(context).unfocus();

    final p1 = _pw1.text.trim();
    final p2 = _pw2.text.trim();

    if (p1.isEmpty || p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in both password fields.'.tr())),
      );
      return;
    }

    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match.'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final tokenHash = widget.recoveryTokenHash?.trim();

      if (supabase.auth.currentSession == null &&
          !_hasVerifiedRecoveryToken &&
          tokenHash != null &&
          tokenHash.isNotEmpty) {
        await supabase.auth.verifyOTP(
          type: OtpType.recovery,
          tokenHash: tokenHash,
        );

        _hasVerifiedRecoveryToken = true;
      }

      if (supabase.auth.currentSession == null) {
        throw Exception(
          'Reset link expired. Please request a new one.'.tr(),
        );
      }

      await supabase.auth.updateUser(
        UserAttributes(password: p1),
      );

      widget.onPasswordUpdated?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password updated.'.tr())),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = e.message;

      if (e.message.toLowerCase().contains('same_password') ||
          e.message.toLowerCase().contains('new password should be different from the old password')) {
        message = 'Your new password must be different from your old password.'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      final raw = e.toString().toLowerCase();
      String message = e.toString();

      if (raw.contains('same_password') ||
          raw.contains('new password should be different from the old password')) {
        message = 'Your new password must be different from your old password.'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: colorScheme.primary.withValues(alpha: 0.72),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      prefixIcon: Icon(
        icon,
        color: colorScheme.primary.withValues(alpha: 0.78),
      ),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: colorScheme.primary.withValues(alpha: 0.72),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Reset password'.tr(),
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.12),
                            colorScheme.secondary.withValues(alpha: 0.42),
                            colorScheme.surfaceContainerHigh,
                          ],
                        ),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create a new password'.tr(),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose a strong password and confirm it below to secure your account.'
                                      .tr(),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary.withValues(alpha: 0.72),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _pw1,
                            obscureText: _obscurePw1,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              context: context,
                              label: 'New password'.tr(),
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePw1,
                              onToggleVisibility: () {
                                setState(() => _obscurePw1 = !_obscurePw1);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pw2,
                            obscureText: _obscurePw2,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isSaving) _saveNewPassword();
                            },
                            decoration: _inputDecoration(
                              context: context,
                              label: 'Confirm new password'.tr(),
                              icon: Icons.verified_user_outlined,
                              obscureText: _obscurePw2,
                              onToggleVisibility: () {
                                setState(() => _obscurePw2 = !_obscurePw2);
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: colorScheme.primary.withValues(alpha: 0.78),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Make sure both password fields match before saving.'
                                        .tr(),
                                    style: textTheme.bodySmall?.copyWith(
                                      color:
                                      colorScheme.primary.withValues(alpha: 0.72),
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveNewPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D6746),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text('Save password'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}