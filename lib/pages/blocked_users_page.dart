/*
BLOCKED USERS PAGE

Displays a list of users that have been blocked.
Allows unblocking directly from the list.
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/services/database/database_provider.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  late final DatabaseProvider listeningProvider =
  Provider.of<DatabaseProvider>(context);

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  bool _loading = true;
  String? _unblockingUserId;

  @override
  void initState() {
    super.initState();
    loadBlockedUsers();
  }

  Future<void> loadBlockedUsers() async {
    try {
      await databaseProvider.loadBlockedUsers();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showUnblockConfirmationBox(String userId, String name) async {
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) {
        return Dialog(
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
                    Icons.block_flipped,
                    color: cs.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Unblock User".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Are you sure you want to unblock this user?".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          "Unblock".tr(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
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

    setState(() => _unblockingUserId = userId);

    try {
      await databaseProvider.unblockUser(userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User unblocked!".tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _unblockingUserId = null);
      }
    }
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
              Icons.block_outlined,
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
                  "Privacy & Safety".tr(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Blocked Users".tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage the people you’ve blocked from interacting with you."
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

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_user_outlined,
                size: 34,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No blocked users...".tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You haven’t blocked anyone right now.".tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final cs = Theme.of(context).colorScheme;
    final isBusy = _unblockingUserId == user.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? cs.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: isBusy
                ? null
                : () => _showUnblockConfirmationBox(user.id, user.name),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error.withValues(alpha: 0.10),
              foregroundColor: cs.error,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: isBusy
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.error,
              ),
            )
                : const Icon(Icons.lock_open_rounded, size: 18),
            label: Text(
              "Unblock".tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockedUsers = listeningProvider.blockedUsers;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadBlockedUsers,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _buildPremiumHeader(),
              const SizedBox(height: 18),
              if (_loading)
                SizedBox(
                  height: 280,
                  child: Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                )
              else if (blockedUsers.isEmpty)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.52,
                  child: _buildEmptyState(),
                )
              else
                ...blockedUsers.map(
                      (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildUserCard(user),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}