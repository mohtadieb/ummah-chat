// lib/components/my_post_tile.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../services/database/database_provider.dart';
import '../components/my_input_alert_box.dart';
import '../services/auth/auth_service.dart';
import 'my_confirmation_box.dart';
import '../services/navigation/bottom_nav_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../pages/fullscreen_image_page.dart';

const bool kUseAdaptiveMediaAspectRatio = true;
const bool kShowSubtlePostSeparator = true;

class MyPostTile extends StatefulWidget {
  final Post post;
  final void Function()? onUserTap;
  final void Function()? onPostTap;
  final BuildContext scaffoldContext;
  final bool isInPostPage;

  final void Function(bool isSaved)? onBookmarkChanged;

  const MyPostTile({
    super.key,
    required this.post,
    this.onUserTap,
    required this.onPostTap,
    required this.scaffoldContext,
    this.isInPostPage = false,
    this.onBookmarkChanged,
  });

  @override
  State<MyPostTile> createState() => _MyPostTileState();
}

class _MyPostTileState extends State<MyPostTile>
    with AutomaticKeepAliveClientMixin {
  late final listeningProvider =
  Provider.of<DatabaseProvider>(context, listen: true);
  late final databaseProvider =
  Provider.of<DatabaseProvider>(context, listen: false);

  final _commentController = TextEditingController();

  late Future<List<PostMedia>> _mediaFuture;
  List<PostMedia> _media = [];
  bool _mediaReady = false;

  int _currentMediaIndex = 0;
  final Map<String, double> _imageAspectRatios = {};

  bool? _optimisticBookmarked;

  final List<TapGestureRecognizer> _linkRecognizers = [];
  bool _deleting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // ✅ IMPORTANT: DO NOT load comments per tile (stutter source)
    // Comments should load only on post details page.

    // ✅ Media: cached + deduped in provider
    _mediaFuture = databaseProvider.getPostMediaCached(widget.post.id);
    _mediaFuture.then((items) {
      if (!mounted) return;
      setState(() {
        _media = items;
        _mediaReady = true;
      });

      if (kUseAdaptiveMediaAspectRatio) {
        for (final m in items) {
          if (m.type == 'image') _precacheImageAspectRatio(m.url);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MyPostTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id) {
      _media = [];
      _mediaReady = false;
      _currentMediaIndex = 0;
      _imageAspectRatios.clear();
      _optimisticBookmarked = null;

      _mediaFuture = databaseProvider.getPostMediaCached(widget.post.id);
      _mediaFuture.then((items) {
        if (!mounted) return;
        setState(() {
          _media = items;
          _mediaReady = true;
        });

        if (kUseAdaptiveMediaAspectRatio) {
          for (final m in items) {
            if (m.type == 'image') _precacheImageAspectRatio(m.url);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();

    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();

    super.dispose();
  }

  void _toggleLikePost() async {
    try {
      await databaseProvider.toggleLike(widget.post.id);
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _toggleBookmarkPost() async {
    final bool wasSaved = _optimisticBookmarked ??
        listeningProvider.isPostBookmarkedByCurrentUser(widget.post.id);

    final bool newSaved = !wasSaved;

    if (mounted) {
      setState(() => _optimisticBookmarked = newSaved);
    }

    widget.onBookmarkChanged?.call(newSaved);

    try {
      await databaseProvider.toggleBookmark(
        itemType: 'post',
        itemId: widget.post.id,
      );
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');

      if (!mounted) return;
      setState(() => _optimisticBookmarked = wasSaved);
      widget.onBookmarkChanged?.call(wasSaved);

      ScaffoldMessenger.maybeOf(widget.scaffoldContext)?.showSnackBar(
        SnackBar(content: Text("Could not update bookmark".tr())),
      );
    }
  }

  Future<void> _sharePost() async {
    try {
      final name = widget.post.name.trim();
      final username = widget.post.username.trim();
      final message = widget.post.message.trim();

      String? firstUrl;
      if (_media.isNotEmpty) {
        firstUrl = _media.first.url.trim();
        if (firstUrl.isEmpty) firstUrl = null;
      }

      final text = [
        if (name.isNotEmpty) name,
        if (username.isNotEmpty) '@$username',
        if (message.isNotEmpty) '',
        if (message.isNotEmpty) message,
        if (firstUrl != null) '',
        if (firstUrl != null) firstUrl!,
        '',
        '— Ummah Chat',
      ].join('\n');

      await Share.share(text);
    } catch (e) {
      debugPrint('Error sharing post: $e');
      ScaffoldMessenger.maybeOf(widget.scaffoldContext)?.showSnackBar(
        SnackBar(content: Text('could_not_share'.tr())),
      );
    }
  }

  void _openNewCommentBox() {
    final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);

    showDialog(
      context: context,
      builder: (dialogContext) => MyInputAlertBox(
        textController: _commentController,
        title: 'add_comment_title'.tr(),
        hintText: "Type a comment".tr(),
        onPressedText: "Post".tr(),
        onPressed: () async {
          final comment = _commentController.text.trim();

          if (comment.replaceAll(RegExp(r'\s+'), '').length < 5) {
            messenger?.showSnackBar(
              SnackBar(
                content: Text("Comment must be at least 5 characters".tr()),
              ),
            );
            return;
          }

          await _addComment();
        },
      ),
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await databaseProvider.addComment(
        widget.post.id,
        _commentController.text.trim(),
      );
    } catch (e) {
      debugPrint('Error adding comment: $e');
    } finally {
      _commentController.clear();
    }
  }

  Future<void> _openPrivateReflectionDialog() async {
    final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);

    await showDialog(
      context: context,
      builder: (ctx) => MyInputAlertBox(
        title: 'private_reflection'.tr(),
        hintText: "Write a private reflection...".tr(),
        onPressedText: "Save".tr(),
        onPressedWithText: (text) async {
          await databaseProvider.addPrivateReflection(
            text: text,
            postId: widget.post.id,
          );
          messenger?.showSnackBar(SnackBar(content: Text("Saved".tr())));
        },
      ),
    );
  }

  void _showOptions() {
    final currentUserId = AuthService().getCurrentUserId();
    final isOwnPost = widget.post.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text("Delete".tr()),
                onTap: _deleting
                    ? null
                    : () async {
                  Navigator.pop(sheetContext);
                  final messenger =
                  ScaffoldMessenger.maybeOf(widget.scaffoldContext);

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text("Delete Post".tr()),
                      content: Text(
                        "Are you sure you want to delete this post?".tr(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, false),
                          child: Text("Cancel".tr()),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, true),
                          child: Text("Delete".tr()),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!mounted) return;
                    setState(() => _deleting = true);

                    try {
                      await databaseProvider.deletePost(widget.post);

                      if (!mounted) return;
                      messenger?.showSnackBar(
                        SnackBar(content: Text("Post deleted".tr())),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text("Could not delete post".tr()),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _deleting = false);
                      }
                    }
                  }
                },
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.report_outlined),
                    title: Text("Report".tr()),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reportPostConfirmationBox();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: Text("Block user".tr()),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _blockUserConfirmationBox();
                    },
                  ),
                ],
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text("Cancel".tr()),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _reportPostConfirmationBox() {
    showDialog(
      context: context,
      builder: (dialogContext) => MyConfirmationBox(
        title: "Report Message".tr(),
        content: "Are you sure you want to report this message?".tr(),
        confirmText: "Report".tr(),
        onConfirm: () async {
          await databaseProvider.reportUser(
            widget.post.id,
            widget.post.userId,
          );
          final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);
          messenger?.showSnackBar(
            SnackBar(content: Text("Message reported".tr())),
          );
        },
      ),
    );
  }

  void _blockUserConfirmationBox() {
    showDialog(
      context: context,
      builder: (dialogContext) => MyConfirmationBox(
        title: "Block User".tr(),
        content: "Are you sure you want to block this user?".tr(),
        confirmText: "Block".tr(),
        onConfirm: () async {
          await databaseProvider.blockUser(widget.post.userId);
          final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);
          messenger?.showSnackBar(
            SnackBar(content: Text("User blocked".tr())),
          );
        },
      ),
    );
  }

  void _handleUserTap() {
    final currentUserId = AuthService().getCurrentUserId();

    // 👉 Other user → normal navigation
    if (widget.post.userId != currentUserId) {
      widget.onUserTap?.call();
      return;
    }

    // 👉 Own post → jump to own profile tab
    goToOwnProfileTab(context);
  }


  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleUserTap,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
                  child: Text(
                    widget.post.name.isNotEmpty
                        ? widget.post.name[0].toUpperCase()
                        : '@',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.post.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showOptions,
            icon: const Icon(Icons.more_horiz),
            splashRadius: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  void _openFullscreenForMedia(PostMedia media) {
    final imageMedias =
    _media.where((m) => m.type == 'image').toList(growable: false);
    if (imageMedias.isEmpty) return;

    final imageUrls = imageMedias.map((m) => m.url).toList();
    final initialIndex = imageMedias
        .indexWhere((m) => m.id == media.id)
        .clamp(0, imageUrls.length - 1);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImagePage(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _precacheImageAspectRatio(String url) {
    if (_imageAspectRatios.containsKey(url)) return;

    final image = NetworkImage(url);
    final stream = image.resolve(const ImageConfiguration());

    ImageStreamListener? listener;
    listener = ImageStreamListener(
          (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w > 0 && h > 0) {
          final ratio = w / h;
          if (mounted) {
            setState(() => _imageAspectRatios[url] = ratio);
          } else {
            _imageAspectRatios[url] = ratio;
          }
        }
        stream.removeListener(listener!);
      },
      onError: (Object _, StackTrace? __) {
        stream.removeListener(listener!);
      },
    );

    stream.addListener(listener);
  }

  double _currentMediaAspectRatio() {
    const fallback = 4 / 5;

    if (!kUseAdaptiveMediaAspectRatio) return fallback;
    if (_media.isEmpty) return fallback;

    final media = _media[_currentMediaIndex];

    if (media.type == 'image') {
      final ratio = _imageAspectRatios[media.url];
      if (ratio == null) return fallback;
      return ratio.clamp(0.8, 1.25);
    }

    return fallback;
  }

  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );

  Future<void> _openUrl(String raw) async {
    var url = raw.trim();

    if (url.toLowerCase().startsWith('www.')) {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final ok = await canLaunchUrl(uri);
    if (!ok) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildSelectableLinkText(
      BuildContext context, {
        required String text,
        TextStyle? style,
        int? maxLines,
        TextOverflow? overflow,
        VoidCallback? onTapNonLink,
      }) {
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();

    final spans = <TextSpan>[];
    final matches = _urlRegex.allMatches(text);

    int currentIndex = 0;

    for (final m in matches) {
      if (m.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, m.start)));
      }

      final urlText = text.substring(m.start, m.end);
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          await _openUrl(urlText);
        };

      _linkRecognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: urlText,
          recognizer: recognizer,
          style: style?.copyWith(
            decoration: TextDecoration.underline,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      currentIndex = m.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;

    return GestureDetector(
      onTap: onTapNonLink,
      behavior: HitTestBehavior.opaque,
      child: SelectionArea(
        child: RichText(
          maxLines: maxLines,
          overflow: overflow ?? TextOverflow.clip,
          text: TextSpan(style: baseStyle, children: spans),
        ),
      ),
    );
  }

  Widget _buildImageOrText(BuildContext context) {
    final theme = Theme.of(context);

    if (!_mediaReady) {
      // ✅ fixed-size placeholder so layout stays stable while loading
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.45),
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_media.isNotEmpty) {
      final aspectRatio = _currentMediaAspectRatio();

      return AspectRatio(
        aspectRatio: aspectRatio,
        child: PageView.builder(
          key: PageStorageKey<String>('post_media_${widget.post.id}'),
          itemCount: _media.length,
          onPageChanged: (index) => setState(() => _currentMediaIndex = index),
          itemBuilder: (context, index) {
            final media = _media[index];

            if (media.type == 'video') {
              return _VideoPostPlayer(videoUrl: media.url);
            }

            return GestureDetector(
              onTap: () => _openFullscreenForMedia(media),
              child: Image.network(
                media.url,
                fit: BoxFit.cover,
                width: double.infinity,
                cacheWidth: 1080,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text('Failed to load media'.tr()),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _buildSelectableLinkText(
        context,
        text: widget.post.message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
        onTapNonLink: widget.onPostTap,
      ),
    );
  }

  Widget _buildMediaIndicator(BuildContext context) {
    if (_media.length <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_media.length, (index) {
          final isActive = index == _currentMediaIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: isActive ? 14 : 6,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    final theme = Theme.of(context);

    final likedByCurrentUser =
    listeningProvider.isPostLikedByCurrentUser(widget.post.id);

    final providerBookmarked =
    listeningProvider.isPostBookmarkedByCurrentUser(widget.post.id);

    final bookmarkedByCurrentUser = _optimisticBookmarked ?? providerBookmarked;

    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleLikePost,
            icon: likedByCurrentUser
                ? const Icon(Icons.favorite)
                : const Icon(Icons.favorite_border),
            color: likedByCurrentUser ? Colors.red : iconColor,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openNewCommentBox,
            icon: const Icon(Icons.mode_comment_outlined),
            color: iconColor,
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openPrivateReflectionDialog,
            icon: const Icon(Icons.lock_outline_rounded),
            color: iconColor,
            splashRadius: 20,
            tooltip: 'private_reflection'.tr(),
          ),
          IconButton(
            onPressed: _sharePost,
            icon: const Icon(Icons.send_outlined),
            color: iconColor,
            splashRadius: 20,
            tooltip: 'share'.tr(),
          ),
          const Spacer(),
          IconButton(
            onPressed: _toggleBookmarkPost,
            icon: Icon(
              bookmarkedByCurrentUser ? Icons.bookmark : Icons.bookmark_border,
            ),
            color: iconColor,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    final likeCount = listeningProvider.getLikeCount(widget.post.id);

    // ✅ Uses posts.comment_count (no comment fetching here)
    final int commentCount = listeningProvider.getCommentCount(widget.post.id);

    return Column(
      children: [
        if (kShowSubtlePostSeparator)
          Container(
            height: 10,
            color: theme.colorScheme.surfaceContainerLowest,
          ),
        Material(
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildHeader(context),
              ),
              const SizedBox(height: 4),
              _buildImageOrText(context),
              _buildMediaIndicator(context),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildActionsRow(context),
              ),
              if (likeCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "likes".plural(
                      likeCount,
                      namedArgs: {"count": likeCount.toString()},
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (_media.isNotEmpty && widget.post.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildSelectableLinkText(
                    context,
                    text: '${widget.post.username} ${widget.post.message}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.35,
                    ),
                    onTapNonLink: widget.onPostTap,
                  ),
                ),
              const SizedBox(height: 4),

              // ✅ EXACT BEHAVIOR YOU WANT:
              // - show nothing when 0
              // - plural uses your "View all comments" key:
              //   one: "View 1 comment"
              //   other: "View all {count} comments"
              if (!widget.isInPostPage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GestureDetector(
                    onTap: commentCount > 0 ? widget.onPostTap : null,
                    child: Text(
                      commentCount == 0
                          ? 'No comments yet'.tr()
                          : 'View all comments'.plural(
                        commentCount,
                        namedArgs: {'count': commentCount.toString()},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: commentCount == 0
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 4),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: TimeAgoText(
                  createdAt: widget.post.createdAt,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoPostPlayer extends StatefulWidget {
  final String videoUrl;

  const _VideoPostPlayer({required this.videoUrl});

  @override
  State<_VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<_VideoPostPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);

        _controller.setLooping(true);
        _controller.setVolume(_muted ? 0.0 : 1.0);
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

    if (_muted) {
      _controller.setVolume(1.0);
    } else {
      _controller.setVolume(0.0);
    }

    setState(() => _muted = !_muted);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isPlaying = _controller.value.isPlaying;

    return VisibilityDetector(
      key: Key('video_${widget.videoUrl}'),
      onVisibilityChanged: (info) {
        final visibleFraction = info.visibleFraction;
        if (!_initialized) return;

        if (visibleFraction >= 0.6 && !_controller.value.isPlaying) {
          _controller.play();
          setState(() {});
        }

        if (visibleFraction < 0.3 && _controller.value.isPlaying) {
          _controller.pause();
          setState(() {});
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            if (!isPlaying)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleMute,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
