// lib/pages/post_feed_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../components/my_comments_bottom_sheet.dart';
import '../components/my_input_alert_box.dart';
import '../helper/navigate_pages.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../pages/share/share_post_to_friend_page.dart';
import '../pages/share/share_post_to_group_page.dart';
import '../services/database/database_provider.dart';

class PostFeedPage extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const PostFeedPage({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  late final PageController _pageController;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  final List<Post> _sourcePosts = [];
  final List<_MediaPostBundle> _mediaPosts = [];

  int _sourceCursor = 0;
  int _initialMediaIndex = 0;

  static const int _mediaBatchSize = 8;

  final Map<String, bool> _optimisticBookmarks = {};
  final Map<String, bool> _heartAnimations = {};

  @override
  void initState() {
    super.initState();

    _sourcePosts.addAll(widget.posts);
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialMediaPosts());
  }

  Future<void> _loadInitialMediaPosts() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    final safeInitialIndex = _sourcePosts.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _sourcePosts.length - 1);

    final tappedPost = _sourcePosts.isEmpty ? null : _sourcePosts[safeInitialIndex];

    final start = (safeInitialIndex - 3).clamp(0, _sourcePosts.length);
    _sourceCursor = start;

    await _loadMoreMediaPosts(
      db: db,
      targetPostId: tappedPost?.id,
      minimumItems: 10,
    );

    if (!mounted) return;

    final foundIndex = tappedPost == null
        ? 0
        : _mediaPosts.indexWhere((b) => b.post.id == tappedPost.id);

    setState(() {
      _initialMediaIndex = foundIndex < 0 ? 0 : foundIndex;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _mediaPosts.isEmpty) return;
      _pageController.jumpToPage(_initialMediaIndex);
    });
  }

  Future<void> _loadMoreMediaPosts({
    required DatabaseProvider db,
    String? targetPostId,
    int minimumItems = _mediaBatchSize,
  }) async {
    if (_loadingMore || !_hasMore) return;

    _loadingMore = true;

    try {
      final beforeCount = _mediaPosts.length;

      bool targetFound = targetPostId == null ||
          _mediaPosts.any((b) => b.post.id == targetPostId);

      while (true) {
        while (_sourceCursor < _sourcePosts.length) {
          final post = _sourcePosts[_sourceCursor];
          _sourceCursor++;

          final media = await db.getPostMediaCached(post.id);

          final mediaOnly = media
              .where((m) => m.type == 'image' || m.type == 'video')
              .toList(growable: false);

          if (mediaOnly.isNotEmpty &&
              !_mediaPosts.any((b) => b.post.id == post.id)) {
            _mediaPosts.add(
              _MediaPostBundle(
                post: post,
                media: mediaOnly,
              ),
            );
          }

          if (post.id == targetPostId) {
            targetFound = true;
          }

          final loadedEnough = _mediaPosts.length - beforeCount >= minimumItems;

          if (targetFound && loadedEnough) {
            return;
          }
        }

        final newPosts = await db.loadMorePosts();

        if (newPosts.isEmpty) {
          _hasMore = false;
          return;
        }

        final existingIds = _sourcePosts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts
            .where((p) => !existingIds.contains(p.id))
            .toList(growable: false);

        if (uniqueNewPosts.isEmpty) {
          _hasMore = false;
          return;
        }

        _sourcePosts.addAll(uniqueNewPosts);
      }
    } catch (e) {
      debugPrint('Error loading more media posts: $e');
    } finally {
      _loadingMore = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleLike(Post post) async {
    try {
      await Provider.of<DatabaseProvider>(context, listen: false)
          .toggleLike(post.id);
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  void _doubleTapLike(Post post) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final alreadyLiked = db.isPostLikedByCurrentUser(post.id);

    if (!alreadyLiked) {
      await db.toggleLike(post.id);
    }

    if (!mounted) return;

    setState(() {
      _heartAnimations[post.id] = true;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _heartAnimations[post.id] = false;
      });
    });
  }

  Future<void> _toggleBookmark(Post post) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    final wasSaved = _optimisticBookmarks[post.id] ??
        db.isPostBookmarkedByCurrentUser(post.id);

    final newSaved = !wasSaved;

    setState(() {
      _optimisticBookmarks[post.id] = newSaved;
    });

    try {
      await db.toggleBookmark(
        itemType: 'post',
        itemId: post.id,
      );
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');

      if (!mounted) return;

      setState(() {
        _optimisticBookmarks[post.id] = wasSaved;
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text("Could not update bookmark".tr())),
      );
    }
  }

  Future<void> _openPrivateReflectionDialog(Post post) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    await showDialog(
      context: context,
      builder: (_) => MyInputAlertBox(
        title: 'private_reflection'.tr(),
        hintText: "Write a private reflection...".tr(),
        onPressedText: "Save".tr(),
        onPressedWithText: (text) async {
          await Provider.of<DatabaseProvider>(context, listen: false)
              .addPrivateReflection(
            text: text,
            postId: post.id,
          );

          messenger?.showSnackBar(
            SnackBar(content: Text("Saved".tr())),
          );
        },
      ),
    );
  }

  Future<void> _shareExternally(_MediaPostBundle bundle) async {
    final post = bundle.post;

    final name = post.name.trim();
    final username = post.username.trim();
    final message = post.message.trim();
    final firstUrl = bundle.media.isNotEmpty ? bundle.media.first.url.trim() : '';

    final text = [
      if (name.isNotEmpty) name,
      if (username.isNotEmpty) '@$username',
      if (message.isNotEmpty) '',
      if (message.isNotEmpty) message,
      if (firstUrl.isNotEmpty) '',
      if (firstUrl.isNotEmpty) firstUrl,
      '',
      '— Ummah Chat',
    ].join('\n');

    await Share.share(text);
  }

  Future<void> _openShareChooser(_MediaPostBundle bundle) async {
    final cs = Theme.of(context).colorScheme;
    final post = bundle.post;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: cs.primary),
                title: Text('Share in chat'.tr()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SharePostToFriendPage(post: post),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.group_outlined, color: cs.primary),
                title: Text('Share in group'.tr()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SharePostToGroupPage(post: post),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: cs.primary),
                title: Text('Share externally'.tr()),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareExternally(bundle);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text('Cancel'.tr()),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseProvider>();

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_mediaPosts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Text(
                  'No media posts found',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _mediaPosts.length,
        onPageChanged: (index) async {
          if (index >= _mediaPosts.length - 3 && _hasMore && !_loadingMore) {
            await _loadMoreMediaPosts(db: db);
            if (mounted) setState(() {});
          }
        },
        itemBuilder: (context, index) {
          final bundle = _mediaPosts[index];
          final post = bundle.post;

          final liked = db.isPostLikedByCurrentUser(post.id);
          final likeCount = db.getLikeCount(post.id);
          final commentCount = db.getCommentCount(post.id);

          final providerSaved = db.isPostBookmarkedByCurrentUser(post.id);
          final saved = _optimisticBookmarks[post.id] ?? providerSaved;

          final showHeart = _heartAnimations[post.id] == true;

          return GestureDetector(
            onDoubleTap: () => _doubleTapLike(post),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _FullscreenMediaPost(bundle: bundle),
                ),
                if (showHeart) const Center(child: _HeartPopAnimation()),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 64,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => goUserPage(context, post.userId),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white24,
                          backgroundImage: post.profilePhotoUrl != null &&
                              post.profilePhotoUrl!.trim().isNotEmpty
                              ? NetworkImage(post.profilePhotoUrl!.trim())
                              : null,
                          child: post.profilePhotoUrl == null ||
                              post.profilePhotoUrl!.trim().isEmpty
                              ? Text(
                            post.name.isNotEmpty
                                ? post.name[0].toUpperCase()
                                : '@',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            post.username.isNotEmpty
                                ? '@${post.username}'
                                : post.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 78,
                  child: _PostActionRail(
                    liked: liked,
                    saved: saved,
                    likeCount: likeCount,
                    commentCount: commentCount,
                    onLike: () => _toggleLike(post),
                    onComment: () => openCommentsBottomSheet(
                      context: context,
                      post: post,
                    ),
                    onReflection: () => _openPrivateReflectionDialog(post),
                    onShare: () => _openShareChooser(bundle),
                    onBookmark: () => _toggleBookmark(post),
                  ),
                ),
                if (post.message.trim().isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 84,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    child: Text(
                      post.message.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeartPopAnimation extends StatefulWidget {
  const _HeartPopAnimation();

  @override
  State<_HeartPopAnimation> createState() => _HeartPopAnimationState();
}

class _HeartPopAnimationState extends State<_HeartPopAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _scale = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.4, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: const Icon(
          Icons.favorite,
          color: Colors.white,
          size: 112,
          shadows: [
            Shadow(
              color: Colors.black45,
              blurRadius: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostActionRail extends StatelessWidget {
  final bool liked;
  final bool saved;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onReflection;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const _PostActionRail({
    required this.liked,
    required this.saved,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onReflection,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RailButton(
          icon: liked ? Icons.favorite : Icons.favorite_border_rounded,
          color: liked ? Colors.red : Colors.white,
          count: likeCount > 0 ? likeCount.toString() : null,
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _RailButton(
          icon: Icons.mode_comment_outlined,
          count: commentCount > 0 ? commentCount.toString() : null,
          onTap: onComment,
        ),
        const SizedBox(height: 18),
        _RailButton(
          icon: Icons.lock_outline_rounded,
          onTap: onReflection,
        ),
        const SizedBox(height: 18),
        _RailButton(
          icon: Icons.send_outlined,
          onTap: onShare,
        ),
        const SizedBox(height: 18),
        _RailButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border_rounded,
          onTap: onBookmark,
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? count;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Icon(
            icon,
            color: color,
            size: 31,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 7,
              ),
            ],
          ),
        ),
        if (count != null) ...[
          const SizedBox(height: 4),
          Text(
            count!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaPostBundle {
  final Post post;
  final List<PostMedia> media;

  const _MediaPostBundle({
    required this.post,
    required this.media,
  });
}

class _FullscreenMediaPost extends StatefulWidget {
  final _MediaPostBundle bundle;

  const _FullscreenMediaPost({required this.bundle});

  @override
  State<_FullscreenMediaPost> createState() => _FullscreenMediaPostState();
}

class _FullscreenMediaPostState extends State<_FullscreenMediaPost> {
  final PageController _mediaController = PageController();
  int _currentMediaIndex = 0;

  @override
  void dispose() {
    _mediaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.bundle.media;

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _mediaController,
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            onPageChanged: (index) {
              setState(() => _currentMediaIndex = index);
            },
            itemBuilder: (context, index) {
              final item = media[index];

              if (item.type == 'video') {
                return _FullscreenVideo(videoUrl: item.url);
              }

              return _FullscreenImage(imageUrl: item.url);
            },
          ),
        ),
        if (media.length > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(media.length, (index) {
                final active = index == _currentMediaIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: 1440,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 42,
            ),
          );
        },
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  final String videoUrl;

  const _FullscreenVideo({required this.videoUrl});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  late final VideoPlayerController _controller;

  bool _initialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;

        _controller
          ..setLooping(true)
          ..setVolume(_muted ? 0 : 1)
          ..play();

        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }

    setState(() {});
  }

  void _toggleMute() {
    if (!_initialized) return;

    _muted = !_muted;
    _controller.setVolume(_muted ? 0 : 1);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final isPlaying = _controller.value.isPlaying;
    final aspectRatio =
    _controller.value.aspectRatio == 0 ? 9 / 16 : _controller.value.aspectRatio;

    return VisibilityDetector(
      key: Key('fullscreen_video_${widget.videoUrl}'),
      onVisibilityChanged: (info) {
        if (!_initialized) return;

        if (info.visibleFraction >= 0.65 && !_controller.value.isPlaying) {
          _controller.play();
          setState(() {});
        }

        if (info.visibleFraction < 0.35 && _controller.value.isPlaying) {
          _controller.pause();
          setState(() {});
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
              if (!isPlaying)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 28,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 28,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}