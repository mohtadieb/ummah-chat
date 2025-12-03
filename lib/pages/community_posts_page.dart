import 'dart:io';

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

  File? _selectedImage;
  File? _selectedVideo;

  bool _isLoadingMembers = false;
  List<UserProfile> _members = [];

  bool _isJoined = false;

  @override
  void initState() {
    super.initState();

    // Load posts
    databaseProvider.loadAllPosts();

    // Load members
    _loadMembers();
    _loadMembershipState();
  }

  // ---------------------------------------------------------------------------
  // Load members
  // ---------------------------------------------------------------------------

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
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No members yet')),
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

  // ---------------------------------------------------------------------------
  // Membership state
  // ---------------------------------------------------------------------------

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
        SnackBar(content: Text('You joined "${widget.communityName}".')),
      );
    } catch (e) {
      debugPrint('Error joining community: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join community. Please try again.'),
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
        title: const Text('Leave community?'),
        content: Text(
            'You will no longer see posts or updates from "$communityName".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: colorScheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave', style: TextStyle(color: Colors.red)),
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
        SnackBar(content: Text('You left "$communityName".')),
      );
    } catch (e) {
      debugPrint('Error leaving community: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave community.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Post creation dialog
  // ---------------------------------------------------------------------------

  void _openPostMessageBox() {
    if (!_isJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join this community to share a post.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setInnerState) => MyInputAlertBox(
            textController: controller,
            hintText: "Share something with ${widget.communityName}…",
            onPressedText: "Post",
            onPressed: () async {
              final message = controller.text.trim();

              if (message.replaceAll(RegExp(r'\s+'), '').length < 2) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text("Your message must have at least 2 characters"),
                  ),
                );

                setInnerState(() {
                  _selectedImage = null;
                  _selectedVideo = null; // ⭐ also clear video
                });
                return;
              }

              try {
                // ⭐ SHOW TEMPORARY POST WHILE UPLOADING
                databaseProvider.showLoadingPost(
                  message: message,
                  imageFile: _selectedImage,
                  videoFile: _selectedVideo,
                );

                await _postMessage(
                  message,
                  communityId: widget.communityId,
                  imageFile: _selectedImage,
                  videoFile: _selectedVideo,
                );

                controller.clear();

                messenger?.showSnackBar(
                  const SnackBar(content: Text("Post uploaded successfully!")),
                );
              } catch (e) {
                debugPrint('Error posting community message: $e');

                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to post. Please try again.'),
                  ),
                );
              }
            },
            extraWidget: Column(
              children: [
                if (_selectedImage != null)
                  Image.file(_selectedImage!, height: 150, fit: BoxFit.cover)
                else if (_selectedVideo != null)
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black12,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, size: 28),
                        SizedBox(width: 8),
                        Text("Video selected"),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text("Add Image"),
                      onPressed: () async {
                        final picked = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setInnerState(() {
                            _selectedVideo = null;
                            _selectedImage = File(picked.path);
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text("Add Video"),
                      onPressed: () async {
                        final picked = await ImagePicker()
                            .pickVideo(source: ImageSource.gallery);
                        if (picked != null) {
                          setInnerState(() {
                            _selectedImage = null;
                            _selectedVideo = File(picked.path);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _postMessage(
      String message, {
        required String communityId,
        File? imageFile,
        File? videoFile,
      }) async {
    await databaseProvider.postMessage(
      message,
      imageFile: imageFile,
      videoFile: videoFile,
      communityId: communityId,
    );

    // ⭐ remove temporary tile
    databaseProvider.clearLoadingPost();

    if (!mounted) return;

    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final listeningProvider = Provider.of<DatabaseProvider>(context);

    // Only posts for this community
    final List<Post> communityPosts = listeningProvider.allPosts
        .where((p) => p.communityId == widget.communityId)
        .toList();

    final loadingPost = listeningProvider.loadingPost;

    // ⭐ Insert temporary loading tile
    final postsToShow = [
      if (loadingPost != null) loadingPost,
      ...communityPosts,
    ];

    final String membersSubtitle;
    if (_isLoadingMembers) {
      membersSubtitle = 'Loading members…';
    } else if (_members.isEmpty) {
      membersSubtitle = 'No members yet';
    } else {
      membersSubtitle =
      '${_members.length} member${_members.length == 1 ? '' : 's'}';
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
                      const Text('View members'),
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
                        const Text('Leave community'),
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
                        const Text('Join community'),
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
        onPressed: _openPostMessageBox,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add),
      )
          : null,

      body: Column(
        children: [
          if (!_isJoined)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Join this community to share posts.",
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

  // ---------------------------------------------------------------------------
  // Build list (with loading tile)
  // ---------------------------------------------------------------------------

  Widget _buildPostList(List<Post> posts) {
    if (posts.isEmpty) {
      return const Center(child: Text("Nothing here yet…"));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];

        // ⭐ temporary tile
        if (post.id == 'loading') {
          return _buildLoadingPostTile();
        }

        return MyPostTile(
          post: post,
          onUserTap: () => goUserPage(context, post.userId),
          onPostTap: () => goPostPage(context, post),
          scaffoldContext: context,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Loading tile
  // ---------------------------------------------------------------------------

  Widget _buildLoadingPostTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "Posting your content…",
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
