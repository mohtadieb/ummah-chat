// lib/helper/likes_bottom_sheet_helper.dart
import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Helper for showing a unified "Liked by" bottom sheet in
/// both DMs and group chats.
///
/// The caller is responsible for:
/// - providing a loader that resolves userIds -> List<UserProfile>
/// - passing the currentUserId (for "(You)" badge)
class LikesBottomSheetHelper {
  /// Shows the bottom sheet.
  ///
  /// [loadProfiles] is only called once and can be async (e.g. DB calls).
  static Future<void> show({
    required BuildContext context,
    required Future<List<UserProfile>> Function() loadProfiles,
    required String? currentUserId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return FutureBuilder<List<UserProfile>>(
          future: loadProfiles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(child: Text('No likes yet')),
              );
            }

            final profiles = snapshot.data!;

            return SizedBox(
              height: 320,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, index) {
                  final user = profiles[index];
                  final isYou =
                      currentUserId != null && user.id == currentUserId;

                  final name = user.name.isNotEmpty
                      ? user.name
                      : (user.username.isNotEmpty
                      ? user.username
                      : user.email);

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isYou) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(You)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: user.username.isNotEmpty
                        ? Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    )
                        : null,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
