// lib/pages/communities/community_posts_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../services/database/database_provider.dart';
import '../../components/my_post_tile.dart';
import '../../components/my_user_tile.dart';
import '../../helper/navigate_pages.dart';
import '../services/navigation/bottom_nav_provider.dart';
import 'create_post_page.dart';

enum _CommunityMenuAction {
  viewMembers,
  joinCommunity,
  inviteMembers,
  changeCommunityPhoto,
  leaveCommunity,
  deleteCommunity,
}

class CommunityPostsPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? communityDescription;
  final String? communityAvatarUrl;

  final bool openedFromInvite;

  const CommunityPostsPage({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityDescription,
    this.communityAvatarUrl,
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

  String? _communityAvatarUrl;

  @override
  void initState() {
    super.initState();

    databaseProvider.loadAllPosts();
    _loadMembers();
    _loadMembershipState();
    _loadCommunityOwner();

    _loadMyInviterName();

    if (widget.openedFromInvite) {
      _inviteChecked = false;
      _hasPendingInvite = false;
    }
    _loadPendingInviteState();

    _communityAvatarUrl = widget.communityAvatarUrl;
    _loadCommunityAvatarIfMissing();
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

  Future<void> _loadCommunityAvatarIfMissing() async {
    final current = (_communityAvatarUrl ?? '').trim();
    if (current.isNotEmpty) return;

    try {
      final c = await databaseProvider.getCommunityById(widget.communityId);
      final url = (c?['avatar_url'] ?? '').toString().trim();
      if (!mounted) return;

      if (url.isNotEmpty) {
        setState(() => _communityAvatarUrl = url);
      }
    } catch (e) {
      debugPrint('Error loading community avatar: $e');
    }
  }

  Widget _buildCommunityAvatar(ColorScheme colorScheme) {
    const radius = 24.0;

    final url = (_communityAvatarUrl ?? '').trim();

    if (url.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(url),
        ),
      );
    }

    final initial = widget.communityName.trim().isNotEmpty
        ? widget.communityName.trim()[0].toUpperCase()
        : 'C';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.secondary.withValues(alpha: 0.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
          width: 1.1,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Future<void> _changeCommunityPhoto() async {
    if (!_isOwner) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final newUrl = await databaseProvider.updateCommunityAvatar(
        communityId: widget.communityId,
        filePath: picked.path,
      );

      if (!mounted) return;

      setState(() {
        _communityAvatarUrl = newUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Community photo updated.'.tr())),
      );
    } catch (e) {
      debugPrint('Error changing community photo: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update community photo.'.tr())),
      );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        if (_isLoadingMembers) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_members.isEmpty) {
          return SizedBox(
            height: 220,
            child: Center(child: Text('No members yet'.tr())),
          );
        }

        final ownerId = (_communityOwnerId ?? '').trim();

        return SizedBox(
          height: 360,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _members.length,
            separatorBuilder: (_, __) => Divider(
              height: 14,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            itemBuilder: (sheetCtx, index) {
              final u = _members[index];
              final isMe = u.id == _myId;
              final isOwner = ownerId.isNotEmpty && u.id == ownerId;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(sheetCtx).pop();

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
                  ignoring: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
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
    final Set<String> invitingIds = {};

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'community_invite_members'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'community_search_friends'.tr(),
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        setModalState(() => query = v.trim().toLowerCase());
                      },
                    ),
                    const SizedBox(height: 14),
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
                            final name = f.name.toLowerCase();
                            final username = f.username.toLowerCase();
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
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final friend = filtered[index];
                              final friendId = friend.id;

                              final alreadyMember = _memberIds.contains(friendId);
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

                              return Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                    (friend.profilePhotoUrl ?? '').isNotEmpty
                                        ? NetworkImage(friend.profilePhotoUrl!)
                                        : null,
                                    backgroundColor: colorScheme.primary
                                        .withValues(alpha: 0.10),
                                    child: (friend.profilePhotoUrl ?? '').isEmpty
                                        ? Text(
                                      friend.name.isNotEmpty
                                          ? friend.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                        : null,
                                  ),
                                  title: Text(
                                    friend.name.isNotEmpty
                                        ? friend.name
                                        : friend.username,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: friend.username.isNotEmpty
                                      ? Text(
                                    '@${friend.username}',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  )
                                      : null,
                                  trailing: TextButton(
                                    onPressed: disabled
                                        ? null
                                        : () async {
                                      setModalState(() {
                                        invitingIds.add(friendId);
                                      });

                                      try {
                                        final inviterName =
                                        _inviterName.trim().isNotEmpty
                                            ? _inviterName.trim()
                                            : 'Someone'.tr();

                                        await databaseProvider
                                            .inviteUserToCommunity(
                                          widget.communityId,
                                          friendId,
                                          widget.communityName,
                                          inviterName,
                                        );

                                        setModalState(() {
                                          invitingIds.remove(friendId);
                                          _pendingInviteIds.add(friendId);
                                        });

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'community_invite_sent'.tr(),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        setModalState(() {
                                          invitingIds.remove(friendId);
                                        });

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'community_invite_failed'.tr(),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.primary,
                                      backgroundColor:
                                      colorScheme.primary.withValues(
                                        alpha: disabled ? 0.04 : 0.10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isInviting
                                        ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : Text(
                                      trailingText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            child: Text('Leave'.tr(), style: TextStyle(color: Colors.red.shade600)),
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
        content: Text("delete_community_warning".tr()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Community deleted.'.tr())),
      );
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
    if (_isJoined) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.10),
            colorScheme.secondary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'community_invite_banner'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.35,
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
          else
            Column(
              children: [
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
                        _hasPendingInvite = false;
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
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Accept'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () async {
                    setState(() => _handlingInviteAction = true);
                    try {
                      await databaseProvider.declineCommunityInvite(
                        widget.communityId,
                      );

                      if (!mounted) return;

                      setState(() => _handlingInviteAction = false);
                      await _loadPendingInviteState();

                      if (!mounted) return;

                      setState(() => _hasPendingInvite = false);
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
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildJoinHintBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Join this community to share posts.".tr(),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(ColorScheme colorScheme) {
    final description = (widget.communityDescription ?? '').trim();
    final memberCount = _members.length;

    String membersSubtitle;
    if (_isLoadingMembers) {
      membersSubtitle = 'Loading members…'.tr();
    } else if (_members.isEmpty) {
      membersSubtitle = 'No members yet'.tr();
    } else {
      membersSubtitle = "member_count".plural(
        memberCount,
        namedArgs: {"count": memberCount.toString()},
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommunityAvatar(colorScheme),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.communityName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniPill(
                      context,
                      icon: Icons.groups_2_rounded,
                      label: membersSubtitle,
                    ),
                    if (_isOwner)
                      _buildMiniPill(
                        context,
                        icon: Icons.workspace_premium_rounded,
                        label: 'community_owner'.tr(),
                      ),
                    if (_isJoined && !_isOwner)
                      _buildMiniPill(
                        context,
                        icon: Icons.check_circle_rounded,
                        label: 'community_member'.tr(),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colorScheme.onSurface.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(
      BuildContext context, {
        required IconData icon,
        required String label,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listeningProvider = Provider.of<DatabaseProvider>(context);

    final List<Post> communityPosts = listeningProvider.posts
        .where((p) => p.communityId == widget.communityId)
        .toList();

    final loadingPost = listeningProvider.loadingPost;

    final postsToShow = [
      if (loadingPost != null) loadingPost,
      ...communityPosts,
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<_CommunityMenuAction>(
              icon: Icon(Icons.more_horiz_rounded, color: colorScheme.onSurface),
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (action) async {
                switch (action) {
                  case _CommunityMenuAction.viewMembers:
                    await _openMembersBottomSheet();
                    break;
                  case _CommunityMenuAction.joinCommunity:
                    await _joinCommunity();
                    break;
                  case _CommunityMenuAction.inviteMembers:
                    await _openInviteFriendsSheet();
                    break;
                  case _CommunityMenuAction.changeCommunityPhoto:
                    await _changeCommunityPhoto();
                    break;
                  case _CommunityMenuAction.leaveCommunity:
                    await _confirmLeaveCommunity();
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

                if (!_isJoined) {
                  items.add(
                    PopupMenuItem(
                      value: _CommunityMenuAction.joinCommunity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text('Join community'.tr()),
                        ],
                      ),
                    ),
                  );
                }

                if (_isOwner) {
                  items.add(
                    PopupMenuItem(
                      value: _CommunityMenuAction.inviteMembers,
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text('community_invite_members'.tr()),
                        ],
                      ),
                    ),
                  );

                  items.add(
                    PopupMenuItem(
                      value: _CommunityMenuAction.changeCommunityPhoto,
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_camera_back_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text('Change community photo'.tr()),
                        ],
                      ),
                    ),
                  );
                }

                if (_isJoined) {
                  items.add(
                    PopupMenuItem(
                      value: _CommunityMenuAction.leaveCommunity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 12),
                          Text('Leave community'.tr()),
                        ],
                      ),
                    ),
                  );
                }

                if (_isOwner) {
                  items.add(
                    PopupMenuItem(
                      value: _CommunityMenuAction.deleteCommunity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'delete_community'.tr(),
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
          ),
        ],
      ),
      floatingActionButton: _isJoined
          ? FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Post'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
          child: Column(
            children: [
              _buildPremiumHeader(colorScheme),
              _buildInviteBanner(colorScheme),
              if (!_isJoined && !(_inviteChecked && _hasPendingInvite))
                _buildJoinHintBanner(colorScheme),
              const SizedBox(height: 10),
              Expanded(child: _buildPostList(postsToShow)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
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

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_outlined,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Nothing here yet…".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isJoined
                    ? 'Be the first to share something with this community.'.tr()
                    : 'Join this community to see and share posts.'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPostTile() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Posting your content…".tr(),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}