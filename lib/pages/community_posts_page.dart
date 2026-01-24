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
import '../services/navigation/bottom_nav_provider.dart';
import 'create_post_page.dart';

enum _CommunityMenuAction {
  viewMembers,
  joinCommunity,
  leaveCommunity,
  inviteMembers,
  deleteCommunity,
}

class CommunityPostsPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? communityDescription;

  final bool openedFromInvite;

  const CommunityPostsPage({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityDescription,
    this.openedFromInvite = false,
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

  late final DatabaseProvider databaseProvider = Provider.of<DatabaseProvider>(
    context,
    listen: false,
  );

  bool _isLoadingMembers = false;
  List<UserProfile> _members = [];

  bool _isJoined = false;

  bool _hasPendingInvite = false;
  bool _inviteChecked = false;
  bool _handlingInviteAction = false;

  bool _isOwner = false;
  String? _communityOwnerId;
  String _inviterName = '';

  Set<String> _memberIds = {};
  Set<String> _pendingInviteIds = {};

  String get _myId => databaseProvider.currentUserId;

  @override
  void initState() {
    super.initState();

    databaseProvider.loadAllPosts();
    _loadMembers();
    _loadMembershipState();
    _loadCommunityOwner(); // ✅ ADD THIS

    _loadMyInviterName();

    if (widget.openedFromInvite) {
      _inviteChecked = false; // let DB decide
      _hasPendingInvite = false;
    }
    _loadPendingInviteState();
  }

  void _goToMyProfileInMainLayout() {
    Provider.of<BottomNavProvider>(context, listen: false).setIndex(4);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _loadMyInviterName() async {
    if (_inviterName.isNotEmpty) return;

    final myId = databaseProvider.currentUserId;
    if (myId.isEmpty) return;

    final me = await databaseProvider.getUserProfile(myId);
    if (!mounted) return;

    final fullName = (me?.name ?? '').trim();
    final username = (me?.username ?? '').trim();

    setState(() {
      _inviterName = fullName.isNotEmpty ? fullName : username;
    });
  }

  Future<void> _loadInviteSheetData() async {
    try {
      final members = await databaseProvider.getCommunityMemberIds(
        widget.communityId,
      );
      final pending = await databaseProvider.getPendingCommunityInviteIds(
        widget.communityId,
      );

      setState(() {
        _memberIds = members;
        _pendingInviteIds = pending;
      });
    } catch (e) {
      debugPrint('Error loading invite sheet data: $e');
    }
  }

  Future<void> _loadCommunityOwner() async {
    final c = await databaseProvider.getCommunityById(widget.communityId);
    final ownerId = c?['created_by']?.toString();

    setState(() {
      _communityOwnerId = ownerId;
      _isOwner = ownerId != null && ownerId.isNotEmpty && ownerId == _myId;
    });
  }

  Future<void> _loadPendingInviteState() async {
    try {
      final hasInvite = await databaseProvider.hasPendingCommunityInvite(
        widget.communityId,
      );

      setState(() {
        _hasPendingInvite = hasInvite;
        _inviteChecked = true;
      });
    } catch (e) {
      debugPrint('Error checking pending invite: $e');
      setState(() => _inviteChecked = true);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);

    try {
      final rawMembers = await databaseProvider.getCommunityMemberProfiles(
        widget.communityId,
      );

      final members = rawMembers.map((member) {
        final createdAt = member['created_at'] != null
            ? DateTime.tryParse(member['created_at'].toString()) ?? DateTime.now()
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

      // ✅ Put owner first (if we know the owner id)
      final ownerId = (_communityOwnerId ?? '').trim();
      if (ownerId.isNotEmpty) {
        members.sort((a, b) {
          final aIsOwner = a.id == ownerId;
          final bIsOwner = b.id == ownerId;
          if (aIsOwner && !bIsOwner) return -1;
          if (!aIsOwner && bIsOwner) return 1;
          return 0;
        });
      }

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
      builder: (sheetCtx) {
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

        final ownerId = (_communityOwnerId ?? '').trim();

        return SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _members.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            itemBuilder: (sheetCtx, index) {
              final u = _members[index];
              final isMe = u.id == _myId;
              final isOwner = ownerId.isNotEmpty && u.id == ownerId;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // close the bottomsheet first
                  Navigator.of(sheetCtx).pop();

                  // then navigate next frame
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

                    if (isMe) {
                      _goToMyProfileInMainLayout();
                    } else {
                      goUserPage(context, u.id);
                    }
                  });
                },
                child: IgnorePointer(
                  // ✅ prevents MyUserTile from eating the tap
                  ignoring: true,
                  child: Row(
                    children: [
                      Expanded(child: MyUserTile(user: u)),
                      if (isOwner)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: colorScheme.primary.withValues(alpha: 0.10),
                          ),
                          child: Text(
                            'community_owner'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openInviteFriendsSheet() async {
    if (!_isOwner) return;

    await _loadInviteSheetData();
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    final TextEditingController searchCtrl = TextEditingController();
    String query = '';

    // ✅ NEW: track button loading per friend for instant feedback
    final Set<String> invitingIds = {};

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'community_invite_members'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: colorScheme.primary),
                        ),
                      ],
                    ),

                    // Search
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'community_search_friends'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (v) {
                        setModalState(() => query = v.trim().toLowerCase());
                      },
                    ),
                    const SizedBox(height: 12),

                    // Friends list (stream)
                    SizedBox(
                      height: 420,
                      child: StreamBuilder<List<UserProfile>>(
                        stream: databaseProvider.friendsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final friends = snapshot.data ?? [];

                          final filtered = query.isEmpty
                              ? friends
                              : friends.where((f) {
                                  final name = (f.name).toLowerCase();
                                  final username = (f.username).toLowerCase();
                                  return name.contains(query) ||
                                      username.contains(query);
                                }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text('community_no_friends_found'.tr()),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 0,
                              color: colorScheme.secondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            itemBuilder: (_, index) {
                              final friend = filtered[index];
                              final friendId = friend.id;

                              final alreadyMember = _memberIds.contains(
                                friendId,
                              );
                              final alreadyInvited = _pendingInviteIds.contains(
                                friendId,
                              );
                              final isInviting = invitingIds.contains(friendId);

                              final disabled =
                                  alreadyMember || alreadyInvited || isInviting;

                              String trailingText = 'community_invite'.tr();
                              if (alreadyMember) {
                                trailingText = 'community_member'.tr();
                              }
                              if (alreadyInvited) {
                                trailingText = 'community_invited'.tr();
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (friend.profilePhotoUrl ?? '').isNotEmpty
                                      ? NetworkImage(friend.profilePhotoUrl!)
                                      : null,
                                  child: (friend.profilePhotoUrl ?? '').isEmpty
                                      ? Text(
                                          friend.name.isNotEmpty
                                              ? friend.name[0]
                                              : '?',
                                        )
                                      : null,
                                ),
                                title: Text(
                                  friend.name.isNotEmpty
                                      ? friend.name
                                      : friend.username,
                                  style: TextStyle(color: colorScheme.primary),
                                ),
                                subtitle: friend.username.isNotEmpty
                                    ? Text('@${friend.username}')
                                    : null,
                                trailing: TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () async {
                                          // ✅ instant feedback
                                          setModalState(() {
                                            invitingIds.add(friendId);
                                          });

                                          try {
                                            final inviterName =
                                                _inviterName.trim().isNotEmpty
                                                ? _inviterName.trim()
                                                : 'Someone'.tr(); // fallback

                                            await databaseProvider
                                                .inviteUserToCommunity(
                                                  widget.communityId,
                                                  friendId,
                                                  widget.communityName,
                                                  inviterName,
                                                );

                                            // ✅ optimistic disable button
                                            setModalState(() {
                                              invitingIds.remove(friendId);
                                              _pendingInviteIds.add(friendId);
                                            });

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'community_invite_sent'.tr(),
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            // ❌ revert so button becomes clickable again
                                            setModalState(() {
                                              invitingIds.remove(friendId);
                                            });

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'community_invite_failed'
                                                      .tr(),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  child: isInviting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(trailingText),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
        ),
      );
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
        content: Text("leave_warning".tr(namedArgs: {"name": communityName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(color: colorScheme.primary),
            ),
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
        ),
      );
    } catch (e) {
      debugPrint('Error leaving community: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave community.'.tr())),
      );
    }
  }

  Future<void> _confirmDeleteCommunity() async {
    if (!_isOwner) return;

    final colorScheme = Theme.of(context).colorScheme;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("delete_community_title".tr()),
        content: Text("delete_community_warning".tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await databaseProvider.deleteCommunity(widget.communityId);

      if (!mounted) return;
      Navigator.pop(context); // leave CommunityPostsPage
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Community deleted.'.tr())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete community.'.tr())),
      );
    }
  }

  Widget _buildInviteBanner(ColorScheme colorScheme) {
    if (!_inviteChecked) return const SizedBox.shrink();
    if (!_hasPendingInvite) return const SizedBox.shrink();
    if (_isJoined)
      return const SizedBox.shrink(); // already a member -> no banner

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.primary.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'community_invite_banner'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_handlingInviteAction)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextButton(
              onPressed: () async {
                setState(() => _handlingInviteAction = true);
                try {
                  await databaseProvider.acceptCommunityInvite(
                    widget.communityId,
                  );

                  if (!mounted) return;
                  setState(() => _handlingInviteAction = false);

                  await _loadMembershipState();
                  await _loadPendingInviteState();
                  await _loadMembers();

                  if (!mounted) return;
                  setState(() {
                    _hasPendingInvite =
                        false; // ensure hidden even if check slow
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'you_joined_community'.tr(
                          namedArgs: {"name": widget.communityName},
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _handlingInviteAction = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept invite.'.tr())),
                  );
                }
              },
              child: Text('Accept'.tr()),
            ),
            TextButton(
              onPressed: () async {
                setState(() => _handlingInviteAction = true);
                try {
                  await databaseProvider.declineCommunityInvite(
                    widget.communityId,
                  );

                  if (!mounted) return;

                  // 1) stop spinner immediately
                  setState(() => _handlingInviteAction = false);

                  // 2) re-check pending invite (DB truth)
                  await _loadPendingInviteState();

                  if (!mounted) return;

                  // 3) ensure banner hidden locally too
                  setState(() => _hasPendingInvite = false);

                  // 4) leave page
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _handlingInviteAction = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to decline invite.'.tr())),
                  );
                }
              },
              child: Text(
                'Decline'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
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
      membersSubtitle = "member_count".plural(
        _members.length,
        namedArgs: {"count": _members.length.toString()},
      );
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
                case _CommunityMenuAction.inviteMembers:
                  await _openInviteFriendsSheet();
                  break;
                case _CommunityMenuAction.deleteCommunity:
                  await _confirmDeleteCommunity();
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
                      Icon(
                        Icons.group_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
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
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
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
                        Icon(Icons.login, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Join community'.tr()),
                      ],
                    ),
                  ),
                );
              }

              // ✅ Owner-only: Invite members
              if (_isOwner) {
                items.add(const PopupMenuDivider());
                items.add(
                  PopupMenuItem(
                    value: _CommunityMenuAction.inviteMembers,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text('community_invite_members'.tr()),
                      ],
                    ),
                  ),
                );
                items.add(const PopupMenuDivider());
                items.add(
                  PopupMenuItem(
                    value: _CommunityMenuAction.deleteCommunity,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "delete_community".tr(),
                          style: const TextStyle(color: Colors.red),
                        ),
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
          _buildInviteBanner(colorScheme), // ✅ banner FIRST

          if (!_isJoined && !(_inviteChecked && _hasPendingInvite))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Join this community to share posts.".tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
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
            child: Text(
              "Posting your content…".tr(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
