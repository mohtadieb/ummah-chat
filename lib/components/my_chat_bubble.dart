import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/fullscreen_image_page.dart';
import 'my_chat_video_bubble.dart';
import '../helper/post_share.dart';
import '../pages/post_page.dart';
import '../models/post.dart';
import '../models/post_media.dart';
import '../services/database/database_provider.dart';

enum ChatBubbleShape { single, first, middle, last }

class MyChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final ChatBubbleShape shape;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime createdAt;
  final bool isRead;
  final bool isDelivered;
  final bool isLikedByMe;
  final int likeCount;
  final bool isUploading;
  final bool isDeleted;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLikeTap;
  final String? senderName;
  final Color? senderColor;
  final String? replyAuthorName;
  final String? replySnippet;
  final bool replyHasMedia;
  final String? replyImageUrl;
  final String? replyPostId;
  final bool replyIsPostShare;
  final VoidCallback? onReplyTap;

  const MyChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.createdAt,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.isRead = false,
    this.isDelivered = false,
    this.isLikedByMe = false,
    this.likeCount = 0,
    this.isUploading = false,
    this.isDeleted = false,
    this.onDoubleTap,
    this.onLongPress,
    this.onLikeTap,
    this.senderName,
    this.senderColor,
    this.shape = ChatBubbleShape.single,
    this.replyAuthorName,
    this.replySnippet,
    this.replyHasMedia = false,
    this.replyImageUrl,
    this.replyPostId,
    this.replyIsPostShare = false,
    this.onReplyTap,
  });

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> effectiveImageUrls = imageUrls.isNotEmpty
        ? imageUrls
        : (imageUrl != null && imageUrl!.trim().isNotEmpty
        ? [imageUrl!]
        : <String>[]);

    final bool isPostShare =
        !isDeleted && PostShare.isPostShareMessage(message);
    final String? sharedPostId =
    isPostShare ? PostShare.extractPostId(message) : null;

    final bool hasImages = !isDeleted && effectiveImageUrls.isNotEmpty;
    final bool hasVideo =
        !isDeleted && videoUrl != null && videoUrl!.trim().isNotEmpty;
    final bool hasText =
        !isDeleted && !isPostShare && message.trim().isNotEmpty;

    final senderBgTop = const Color(0xFF4A8B61);
    final senderBgBottom = const Color(0xFF2F6E46);
    final senderText = Colors.white;

    final receiverBg = isDark ? const Color(0xFF161F1C) : const Color(0xFFFFFFFF);
    final receiverText = isDark ? const Color(0xFFF3F6F4) : const Color(0xFF14201A);
    final receiverBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colors.outline.withValues(alpha: 0.10);

    final textColor = isCurrentUser ? senderText : receiverText;
    final timeLabel = _formatTime(createdAt);

    IconData? tickIcon;
    Color? tickColor;

    if (isCurrentUser) {
      if (isRead) {
        tickIcon = Icons.done_all;
        tickColor = const Color(0xFFA7E0FF);
      } else if (isDelivered) {
        tickIcon = Icons.done_all;
        tickColor = Colors.white70;
      } else {
        tickIcon = Icons.check;
        tickColor = Colors.white70;
      }
    }

    const heartIcon = Icon(Icons.favorite, size: 12, color: Colors.pinkAccent);

    Widget? likeBadge;
    if (!isDeleted && likeCount > 0) {
      if (likeCount == 1) {
        likeBadge = AnimatedScale(
          scale: isLikedByMe ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: heartIcon,
          ),
        );
      } else {
        likeBadge = AnimatedScale(
          scale: isLikedByMe ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                heartIcon,
                const SizedBox(width: 4),
                Text(
                  likeCount.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final showSenderName =
        !isCurrentUser && senderName != null && senderName!.trim().isNotEmpty;

    Widget _buildSingleImage(
        BuildContext context,
        String url, {
          int initialIndex = 0,
          List<String>? allUrls,
        }) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FullscreenImagePage(
                imageUrls: allUrls ?? [url],
                initialIndex: initialIndex,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                height: 160,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 32),
              );
            },
          ),
        ),
      );
    }

    Widget _buildImageGrid(BuildContext context) {
      if (effectiveImageUrls.length == 1) {
        return _buildSingleImage(
          context,
          effectiveImageUrls.first,
          allUrls: effectiveImageUrls,
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: effectiveImageUrls.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final url = effectiveImageUrls[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FullscreenImagePage(
                      imageUrls: effectiveImageUrls,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 24),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    Widget _replyThumbShell({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 38, height: 38, child: child),
      );
    }

    Widget? _buildReplyThumb(BuildContext context) {
      final img = (replyImageUrl ?? '').trim();
      if (img.isNotEmpty) {
        return _replyThumbShell(
          child: Image.network(
            img,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 16),
            ),
          ),
        );
      }

      if (replyIsPostShare && (replyPostId ?? '').trim().isNotEmpty) {
        final postId = replyPostId!.trim();
        final db = context.read<DatabaseProvider>();

        return FutureBuilder<List<PostMedia>>(
          future: db.getPostMediaCached(postId),
          builder: (context, snap) {
            final media = snap.data ?? const <PostMedia>[];
            final firstImage = media
                .where((m) => m.type == 'image')
                .map((m) => m.url.trim())
                .where((u) => u.isNotEmpty)
                .cast<String?>()
                .toList()
                .firstWhere((u) => u != null, orElse: () => null);

            if (firstImage != null && firstImage.trim().isNotEmpty) {
              return _replyThumbShell(
                child: Image.network(
                  firstImage.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: const Icon(Icons.article_outlined, size: 16),
                  ),
                ),
              );
            }

            return _replyThumbShell(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: const Icon(Icons.article_outlined, size: 16),
              ),
            );
          },
        );
      }

      return null;
    }

    Widget _buildReplySharedPostLine(BuildContext context) {
      final postId = (replyPostId ?? '').trim();
      if (!replyIsPostShare || postId.isEmpty) {
        return Text(
          (replySnippet ?? '').trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontStyle: replyHasMedia ? FontStyle.italic : null,
            color: textColor.withValues(alpha: 0.88),
          ),
        );
      }

      final db = context.read<DatabaseProvider>();

      return FutureBuilder<Post?>(
        future: db.getPostById(postId),
        builder: (context, snap) {
          final caption = (snap.data?.message ?? '').trim();
          final line = caption.isNotEmpty ? caption : 'Shared post'.tr();

          return Text(
            line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: textColor.withValues(alpha: 0.88),
            ),
          );
        },
      );
    }

    final deletedText = isCurrentUser
        ? 'You deleted this message'.tr()
        : 'This message was deleted'.tr();

    final double verticalMargin =
    (shape == ChatBubbleShape.single || shape == ChatBubbleShape.first)
        ? 6
        : 2;

    const Radius r22 = Radius.circular(22);
    const Radius r14 = Radius.circular(14);
    const Radius r6 = Radius.circular(6);

    late Radius topLeft;
    late Radius topRight;
    late Radius bottomLeft;
    late Radius bottomRight;

    if (isCurrentUser) {
      switch (shape) {
        case ChatBubbleShape.single:
          topLeft = r22;
          topRight = r22;
          bottomLeft = r22;
          bottomRight = r6;
          break;
        case ChatBubbleShape.first:
          topLeft = r22;
          topRight = r22;
          bottomLeft = r14;
          bottomRight = r6;
          break;
        case ChatBubbleShape.middle:
          topLeft = r14;
          topRight = r14;
          bottomLeft = r14;
          bottomRight = r6;
          break;
        case ChatBubbleShape.last:
          topLeft = r14;
          topRight = r14;
          bottomLeft = r22;
          bottomRight = r6;
          break;
      }
    } else {
      switch (shape) {
        case ChatBubbleShape.single:
          topLeft = r22;
          topRight = r22;
          bottomLeft = r6;
          bottomRight = r22;
          break;
        case ChatBubbleShape.first:
          topLeft = r22;
          topRight = r22;
          bottomLeft = r6;
          bottomRight = r14;
          break;
        case ChatBubbleShape.middle:
          topLeft = r14;
          topRight = r14;
          bottomLeft = r6;
          bottomRight = r14;
          break;
        case ChatBubbleShape.last:
          topLeft = r14;
          topRight = r14;
          bottomLeft = r6;
          bottomRight = r22;
          break;
      }
    }

    final shouldShowReplyPreview =
        !isDeleted &&
            ((replyAuthorName != null && replyAuthorName!.trim().isNotEmpty) ||
                (replySnippet != null && replySnippet!.trim().isNotEmpty) ||
                ((replyImageUrl ?? '').trim().isNotEmpty) ||
                (replyIsPostShare && (replyPostId ?? '').trim().isNotEmpty));

    final bubble = Container(
      margin: EdgeInsets.symmetric(vertical: verticalMargin, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.77,
      ),
      decoration: BoxDecoration(
        gradient: isCurrentUser
            ? const LinearGradient(
          colors: [
            Color(0xFF4A8B61),
            Color(0xFF2F6E46),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isCurrentUser ? null : receiverBg,
        borderRadius: BorderRadius.only(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
        border: Border.all(
          color: isCurrentUser
              ? Colors.white.withValues(alpha: 0.08)
              : receiverBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSenderName && !isDeleted) ...[
            Text(
              senderName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: senderColor ?? colors.primary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (!isDeleted && shouldShowReplyPreview) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReplyTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.black.withValues(alpha: 0.12)
                      : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF4F7F5)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: isCurrentUser
                          ? Colors.white.withValues(alpha: 0.78)
                          : const Color(0xFF3D8A5A),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final thumb = _buildReplyThumb(context);
                        if (thumb == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, top: 1),
                          child: thumb,
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replyAuthorName != null &&
                              replyAuthorName!.trim().isNotEmpty)
                            Text(
                              replyAuthorName!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isCurrentUser
                                    ? Colors.white
                                    : const Color(0xFF2F6E46),
                              ),
                            ),
                          if (replyAuthorName != null &&
                              replyAuthorName!.trim().isNotEmpty)
                            const SizedBox(height: 2),
                          if (replyIsPostShare &&
                              (replyPostId ?? '').trim().isNotEmpty)
                            _buildReplySharedPostLine(context)
                          else if (replySnippet != null &&
                              replySnippet!.trim().isNotEmpty)
                            Text(
                              replySnippet!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle:
                                replyHasMedia ? FontStyle.italic : null,
                                color: textColor.withValues(alpha: 0.88),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isDeleted) ...[
            Text(
              deletedText,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
          ] else ...[
            if (hasVideo) ...[
              MyChatVideoBubble(
                videoUrl: videoUrl!,
                isUploading: isUploading,
                senderName: senderName,
                isCurrentUser: isCurrentUser,
              ),
              if (hasImages || hasText) const SizedBox(height: 6),
            ],
            if (hasImages) ...[
              _buildImageGrid(context),
              if (hasText) const SizedBox(height: 6),
            ],
            if (!isDeleted && isPostShare && sharedPostId != null) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostPage(
                        post: null,
                        postId: sharedPostId,
                        highlightPost: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? Colors.black.withValues(alpha: 0.12)
                        : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF5F8F6)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrentUser
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: textColor.withValues(alpha: 0.92),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shared a post'.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (hasText) ...[
              Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 5),
            ],
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isCurrentUser && tickIcon != null) ...[
                const SizedBox(width: 4),
                Icon(tickIcon, size: 14, color: tickColor),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (likeBadge != null)
              Positioned(
                bottom: -14,
                right: isCurrentUser ? 19 : null,
                left: isCurrentUser ? null : 19,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onLikeTap,
                  child: likeBadge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}