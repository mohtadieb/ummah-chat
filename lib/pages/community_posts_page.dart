// lib/pages/communities/community_posts_page.dart

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../services/database/database_provider.dart';
import '../../components/my_input_alert_box.dart';
import '../../components/my_post_tile.dart';
import '../../components/my_user_tile.dart';
import '../../helper/navigate_pages.dart';
import 'create_post_page.dart';

enum _CommunityMenuAction { viewMembers, joinCommunity, leaveCommunity }

class CommunityPostsPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? communityDescription;

  const CommunityPostsPage({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityDescription,
  });

  @override
  State<CommunityPostsPage> createState() => _CommunityPostsPageState();
}

class _CommunityPostsPageState extends State<CommunityPostsPage> {
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  late final DatabaseProvider databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  bool _isLoadingMembers = false;
  List<UserProfile> _members = [];

  bool _isJoined = false;

  @override
  void initState() {
    super.initState();

    databaseProvider.loadAllPosts();
    _loadMembers();
    _loadMembershipState();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);

    try {
      final rawMembers =
      await databaseProvider.getCommunityMemberProfiles(widget.communityId);

      final members = rawMembers.map((member) {
        final createdAt = member['created_at'] != null
            ? DateTime.tryParse(member['created_at'].toString()) ??
            DateTime.now()
            : DateTime.now();

        return UserProfile(
          id: member['id'] ?? '',
          name: member['name'] ?? 'Unknown',
          username: member['username'] ?? 'user',
          email: member['email'] ?? '',
          bio: member['bio'] ?? '',
          profilePhotoUrl: member['profile_photo_url'] ?? '',
          createdAt: createdAt,
        );
      }).toList();

      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error loading community members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _openMembersBottomSheet() async {
    await _loadMembers();
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        if (_isLoadingMembers) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_members.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('No members yet'.tr())),
          );
        }

        return SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _members.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            itemBuilder: (_, index) => MyUserTile(user: _members[index]),
          ),
        );
      },
    );
  }

  Future<void> _loadMembershipState() async {
    try {
      final isJoined = await databaseProvider.isMember(widget.communityId);
      setState(() => _isJoined = isJoined);
    } catch (e) {
      debugPrint('Error checking membership: $e');
    }
  }

  Future<void> _joinCommunity() async {
    try {
      await databaseProvider.joinCommunity(widget.communityId);
      await _loadMembershipState();
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "you_joined_community".tr(
                namedArgs: {"name": widget.communityName},
              ),
            ),
          ));
    } catch (e) {
      debugPrint('Error joining community: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join community. Please try again.'.tr()),
        ),
      );
    }
  }

  Future<void> _confirmLeaveCommunity() async {
    final communityName = widget.communityName;
    final colorScheme = Theme.of(context).colorScheme;

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leave community?'.tr()),
        content: Text(
            "leave_warning"
                .tr(namedArgs: {"name": communityName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr(), style: TextStyle(color: colorScheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave'.tr(), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLeave != true) return;

    try {
      await databaseProvider.leaveCommunity(widget.communityId);

      if (!mounted) return;

      setState(() => _isJoined = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "you_left_community".tr(namedArgs: {"name": communityName}),
            ),
          )
      );
    } catch (e) {
      debugPrint('Error leaving community: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave community.'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final listeningProvider = Provider.of<DatabaseProvider>(context);

    // Only posts for this community
    final List<Post> communityPosts = listeningProvider.posts
        .where((p) => p.communityId == widget.communityId)
        .toList();

    final loadingPost = listeningProvider.loadingPost;

    final postsToShow = [
      if (loadingPost != null) loadingPost,
      ...communityPosts,
    ];

    final String membersSubtitle;
    if (_isLoadingMembers) {
      membersSubtitle = 'Loading members…'.tr();
    } else if (_members.isEmpty) {
      membersSubtitle = 'No members yet'.tr();
    } else {
      membersSubtitle = "member_count"
          .plural(_members.length, namedArgs: {"count": _members.length.toString()});
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.communityName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            if ((widget.communityDescription ?? '').trim().isNotEmpty)
              Text(
                widget.communityDescription!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            Text(
              membersSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_CommunityMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) async {
              switch (action) {
                case _CommunityMenuAction.viewMembers:
                  await _openMembersBottomSheet();
                  break;
                case _CommunityMenuAction.joinCommunity:
                  await _joinCommunity();
                  break;
                case _CommunityMenuAction.leaveCommunity:
                  await _confirmLeaveCommunity();
                  break;
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<_CommunityMenuAction>>[];

              items.add(
                PopupMenuItem(
                  value: _CommunityMenuAction.viewMembers,
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('View members'.tr()),
                    ],
                  ),
                ),
              );

              items.add(const PopupMenuDivider());

              if (_isJoined) {
                items.add(
                  PopupMenuItem(
                    value: _CommunityMenuAction.leaveCommunity,
                    child: Row(
                      children: [
                        Icon(Icons.logout,
                            size: 20, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        Text('Leave community'.tr()),
                      ],
                    ),
                  ),
                );
              } else {
                items.add(
                  PopupMenuItem(
                    value: _CommunityMenuAction.joinCommunity,
                    child: Row(
                      children: [
                        Icon(Icons.login,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Join community'.tr()),
                      ],
                    ),
                  ),
                );
              }

              return items;
            },
          ),
        ],
      ),
      floatingActionButton: _isJoined
          ? FloatingActionButton(
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePostPage(
                communityId: widget.communityId,
                communityName: widget.communityName,
              ),
            ),
          );
        },
      )
          : null,
      body: Column(
        children: [
          if (!_isJoined)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Join this community to share posts.".tr(),
                      style:
                      TextStyle(fontSize: 13, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildPostList(postsToShow)),
        ],
      ),
    );
  }

  Widget _buildPostList(List<Post> posts) {
    if (posts.isEmpty) {
      return Center(child: Text("Nothing here yet…".tr()));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];

        if (post.id == 'loading') {
          return _buildLoadingPostTile();
        }

        return MyPostTile(
          key: ValueKey(post.id),
          post: post,
          onUserTap: () => goUserPage(context, post.userId),
          onPostTap: () => goPostPage(context, post),
          scaffoldContext: context,
        );
      },
    );
  }

  Widget _buildLoadingPostTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: Text("Posting your content…".tr(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
