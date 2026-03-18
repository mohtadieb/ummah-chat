// lib/components/my_post_tile.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../helper/navigate_pages.dart';
import '../helper/time_ago_text.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../pages/fullscreen_image_page.dart';
import '../pages/share/share_post_to_friend_page.dart';
import '../pages/share/share_post_to_group_page.dart';
import '../services/database/database_provider.dart';
import '../components/my_input_alert_box.dart';
import '../services/auth/auth_service.dart';
import 'my_confirmation_box.dart';

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

  Future<void> _shareExternally() async {
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
        if (firstUrl != null) firstUrl,
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

  Future<void> _openShareChooser() async {
    final cs = Theme.of(context).colorScheme;

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
                      builder: (_) => SharePostToFriendPage(post: widget.post),
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
                      builder: (_) => SharePostToGroupPage(post: widget.post),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: cs.primary),
                title: Text('Share externally'.tr()),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareExternally();
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

    if (widget.post.userId != currentUserId) {
      widget.onUserTap?.call();
      return;
    }

    goToOwnProfileTab(context);
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

      // allow taller portrait images to expand vertically
      return ratio.clamp(0.45, 1.4);
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
            fontWeight: FontWeight.w700,
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        GestureDetector(
          onTap: _handleUserTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                backgroundImage: (widget.post.profilePhotoUrl != null &&
                    widget.post.profilePhotoUrl!.trim().isNotEmpty)
                    ? NetworkImage(widget.post.profilePhotoUrl!.trim())
                    : null,
                child: (widget.post.profilePhotoUrl == null ||
                    widget.post.profilePhotoUrl!.trim().isEmpty)
                    ? Text(
                  widget.post.name.isNotEmpty
                      ? widget.post.name[0].toUpperCase()
                      : '@',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.post.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600,
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
          color: cs.onSurface.withValues(alpha: 0.7),
        ),
      ],
    );
  }

  Widget _buildTextOnlyContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: _buildSelectableLinkText(
        context,
        text: widget.post.message,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: cs.onSurface,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
        onTapNonLink: widget.onPostTap,
      ),
    );
  }

  Widget _buildImageOrText(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!_mediaReady) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_media.isNotEmpty) {
      final aspectRatio = _currentMediaAspectRatio();

      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
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
                      color: theme.colorScheme.surfaceContainerHigh,
                      alignment: Alignment.center,
                      child: Text('Failed to load media'.tr()),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
    }

    return _buildTextOnlyContent(context);
  }

  Widget _buildMediaIndicator(BuildContext context) {
    if (_media.length <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_media.length, (index) {
          final isActive = index == _currentMediaIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: isActive ? 16 : 6,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required VoidCallback onTap,
    required Widget icon,
    String? tooltip,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final likedByCurrentUser =
    listeningProvider.isPostLikedByCurrentUser(widget.post.id);

    final providerBookmarked =
    listeningProvider.isPostBookmarkedByCurrentUser(widget.post.id);

    final bookmarkedByCurrentUser = _optimisticBookmarked ?? providerBookmarked;

    final iconColor = cs.onSurface.withValues(alpha: 0.88);

    return Row(
      children: [
        _buildActionButton(
          context: context,
          onTap: _toggleLikePost,
          tooltip: 'like'.tr(),
          icon: Icon(
            likedByCurrentUser ? Icons.favorite : Icons.favorite_border,
            color: likedByCurrentUser ? Colors.red : iconColor,
          ),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          context: context,
          onTap: _openNewCommentBox,
          tooltip: 'comment'.tr(),
          icon: Icon(Icons.mode_comment_outlined, color: iconColor),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          context: context,
          onTap: _openPrivateReflectionDialog,
          tooltip: 'private_reflection'.tr(),
          icon: Icon(Icons.lock_outline_rounded, color: iconColor),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          context: context,
          onTap: _openShareChooser,
          tooltip: 'share'.tr(),
          icon: Icon(Icons.send_outlined, color: iconColor),
        ),
        const Spacer(),
        _buildActionButton(
          context: context,
          onTap: _toggleBookmarkPost,
          tooltip: 'save'.tr(),
          icon: Icon(
            bookmarkedByCurrentUser ? Icons.bookmark : Icons.bookmark_border,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final likeCount = listeningProvider.getLikeCount(widget.post.id);
    final int commentCount = listeningProvider.getCommentCount(widget.post.id);

    return Column(
      children: [
        if (kShowSubtlePostSeparator) const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceContainerHigh,
                cs.surfaceContainer,
              ],
            ),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  _buildImageOrText(context),
                  _buildMediaIndicator(context),
                  const SizedBox(height: 12),
                  _buildActionsRow(context),
                  if (likeCount > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      "likes".plural(
                        likeCount,
                        namedArgs: {"count": likeCount.toString()},
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                  if (_media.isNotEmpty && widget.post.message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSelectableLinkText(
                      context,
                      text: '${widget.post.username} ${widget.post.message}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                      onTapNonLink: widget.onPostTap,
                    ),
                  ],
                  if (!widget.isInPostPage) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
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
                              ? cs.onSurface.withValues(alpha: 0.55)
                              : cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TimeAgoText(
                    createdAt: widget.post.createdAt,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SharePostToChatPage {}

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