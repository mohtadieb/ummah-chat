// lib/pages/shares/share_post_to_group_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../services/auth/auth_service.dart';
import '../../services/chat/chat_provider.dart';
import '../../helper/post_share.dart';
import '../group_chat_page.dart';

class SharePostToGroupPage extends StatefulWidget {
  final Post post;

  const SharePostToGroupPage({super.key, required this.post});

  @override
  State<SharePostToGroupPage> createState() => _SharePostToGroupPageState();
}

class _SharePostToGroupPageState extends State<SharePostToGroupPage> {
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

    // Providers (keep if you want them for later steps)
    final chat = context.read<ChatProvider>();

    // ✅ FIX: define currentUserId
    final currentUserId = AuthService().getCurrentUserId() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        title: Text('Share in group'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search groups'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: currentUserId.isEmpty
                ? Center(child: Text('something_went_wrong'.tr()))
                : StreamBuilder<List<Map<String, dynamic>>>(
              stream: chat.groupRoomsForUserPollingStream(currentUserId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = snap.data ?? [];

                final filtered = _q.isEmpty
                    ? groups
                    : groups.where((g) {
                  final name =
                  (g['name'] ?? '').toString().toLowerCase();
                  return name.contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text('No groups found'.tr()));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0,
                    color: cs.secondary.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (_, i) {
                    final g = filtered[i];
                    final roomId = (g['id'] ?? '').toString();
                    final groupName = (g['name'] ?? '').toString();

                    return ListTile(
                      leading:
                      const CircleAvatar(child: Icon(Icons.group)),
                      title: Text(
                        groupName,
                        style: TextStyle(color: cs.primary),
                      ),
                      onTap: () async {
                        final marker =
                        PostShare.buildMessage(widget.post.id);

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupChatPage(
                              chatRoomId: roomId,
                              groupName: groupName,
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
