import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../services/database/database_provider.dart';
import '../../helper/post_share.dart';

// ✅ IMPORTANT: adjust import to your actual DM page path/class
import '../chat_page.dart';

class SharePostToFriendPage extends StatefulWidget {
  final Post post;

  const SharePostToFriendPage({super.key, required this.post});

  @override
  State<SharePostToFriendPage> createState() => _SharePostToFriendPageState();
}

class _SharePostToFriendPageState extends State<SharePostToFriendPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = context.read<DatabaseProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        title: Text('Share in chat'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search friends'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: db.friendsStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = snap.data ?? [];

                final filtered = _q.isEmpty
                    ? friends
                    : friends.where((f) {
                  final name = (f.name).toLowerCase();
                  final username = (f.username).toLowerCase();
                  return name.contains(_q) || username.contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text('No friends found'.tr()));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0,
                    color: cs.secondary.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (_, i) {
                    final u = filtered[i];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (u.profilePhotoUrl ?? '').isNotEmpty
                            ? NetworkImage(u.profilePhotoUrl!)
                            : null,
                        child: (u.profilePhotoUrl ?? '').isEmpty
                            ? Text(u.name.isNotEmpty ? u.name[0] : '?')
                            : null,
                      ),
                      title: Text(
                        u.name.isNotEmpty ? u.name : u.username,
                        style: TextStyle(color: cs.primary),
                      ),
                      subtitle:
                      u.username.isNotEmpty ? Text('@${u.username}') : null,
                      onTap: () async {
                        final marker = PostShare.buildMessage(widget.post.id);

                        // ✅ Phase 1 approach:
                        // Navigate to your DM page and pass marker to send immediately.
                        //
                        // You will add these optional params to ChatPage:
                        // - initialDraftMessage
                        // - sendDraftOnOpen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              friendId: u.id,
                              friendName: u.name.trim().isNotEmpty ? u.name.trim() : '@${u.username}',
                              initialDraftMessage: marker,
                              sendDraftOnOpen: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
