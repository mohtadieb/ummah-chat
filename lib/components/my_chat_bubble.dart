import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/fullscreen_image_page.dart';
import 'my_chat_video_bubble.dart';
import '../helper/post_share.dart';
import '../pages/post_page.dart';

// ✅ NEW: for reply shared-post preview
import '../models/post.dart';
import '../models/post_media.dart';
import '../services/database/database_provider.dart';

enum ChatBubbleShape { single, first, middle, last }

/// A simple chat bubble that adapts to the app's current theme.
///
/// - Uses Theme.of(context).colorScheme for colors
/// - Aligns right for current user, left for others
/// - Smooth rounded WhatsApp-style shape
/// - Shows timestamp + ticks (for current user's messages)
/// - Supports "like" with double-tap
/// - Can optionally show sender name (for group chats) inside the bubble
/// - 🖼 Can show one or multiple images above the text
/// - 🎥 Uses [MyChatVideoBubble] for video thumbnails
/// - 🆕 Shows an uploading indicator for pending video messages
/// - 🆕 Supports soft-delete ("This message was deleted")
/// - 🆕 Supports reply preview (small quoted box)
/// - ✅ Reply preview can show thumbnail for image replies and mini shared-post preview
class MyChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final ChatBubbleShape shape;

  /// Backwards-compatible single image URL (used when not using imageUrls).
  final String? imageUrl;

  /// 🖼 New: list of image URLs for multi-image batches.
  final List<String> imageUrls;

  /// 🎥 Optional video URL.
  final String? videoUrl;

  /// Time the message was created (used to show HH:mm)
  final DateTime createdAt;

  /// Whether the message has been read by the receiver (from DB)
  final bool isRead;

  /// Whether the message has been delivered to the receiver (from DB)
  final bool isDelivered;

  /// Whether *current user* has liked this message
  final bool isLikedByMe;

  /// Total like count (length of likedBy from DB)
  final int likeCount;

  /// 🆕 Whether the media is still uploading
  final bool isUploading;

  /// 🆕 Whether the message was soft-deleted
  final bool isDeleted;

  /// Optional double-tap handler (used to toggle like)
  final VoidCallback? onDoubleTap;

  /// Optional long-press handler (used for reply/delete menu)
  final VoidCallback? onLongPress;

  /// Optional tap handler for the like badge (heart)
  final VoidCallback? onLikeTap;

  /// Optional: sender display name (used in group chats or passed from ChatPage).
  final String? senderName;

  /// Optional: specific color for the sender name text.
  /// If null, a fallback color based on theme will be used.
  final Color? senderColor;

  /// 🆕 Reply preview fields (existing)
  final String? replyAuthorName;
  final String? replySnippet;
  final bool replyHasMedia;

  /// ✅ NEW: richer reply preview support
  /// If present, show a thumbnail in the reply quote.
  final String? replyImageUrl;

  /// If present, show a mini shared-post preview in the reply quote.
  final String? replyPostId;

  /// Convenience flag: replied message was a PostShare marker.
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

    // ✅ NEW
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

    // Effective image list: prefer imageUrls, fall back to single imageUrl.
    final List<String> effectiveImageUrls = imageUrls.isNotEmpty
        ? imageUrls
        : (imageUrl != null && imageUrl!.trim().isNotEmpty
              ? [imageUrl!]
              : <String>[]);

    // ✅ detect internal post share marker (current message)
    final bool isPostShare =
        !isDeleted && PostShare.isPostShareMessage(message);
    final String? sharedPostId = isPostShare
        ? PostShare.extractPostId(message)
        : null;

    // If deleted: never show images / videos / text content.
    final bool hasImages = !isDeleted && effectiveImageUrls.isNotEmpty;
    final bool hasVideo =
        !isDeleted && videoUrl != null && videoUrl!.trim().isNotEmpty;
    final bool hasText =
        !isDeleted && !isPostShare && message.trim().isNotEmpty;

    // 🟢 Sender bubble style
    final senderBg = const Color(0xFF467E55);
    final senderText = Colors.white;

    // ⚪ Receiver bubble style (theme-aware)
    final receiverBg = colors.tertiary;
    final receiverText = colors.inversePrimary;

    final bgColor = isCurrentUser ? senderBg : receiverBg;
    final textColor = isCurrentUser ? senderText : receiverText;

    // Build time + ticks row
    final timeLabel = _formatTime(createdAt);

    IconData? tickIcon;
    Color? tickColor;

    if (isCurrentUser) {
      if (isRead) {
        tickIcon = Icons.done_all;
        tickColor = Colors.lightBlueAccent;
      } else if (isDelivered) {
        tickIcon = Icons.done_all;
        tickColor = Colors.white70;
      } else {
        tickIcon = Icons.check;
        tickColor = Colors.white70;
      }
    }

    // ❤️ Like badge
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
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
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
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
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
                    fontWeight: FontWeight.w600,
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

    // ---------- IMAGE HELPERS ----------

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
          borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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

    // ---------- REPLY PREVIEW HELPERS ----------

    Widget _replyThumbShell({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 34, height: 34, child: child),
      );
    }

    Widget? _buildReplyThumb(BuildContext context) {
      // ✅ image reply thumb
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

      // ✅ shared post reply thumb (fetch first image)
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

      // nothing
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
            color: textColor.withValues(alpha: 0.9),
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
              color: textColor.withValues(alpha: 0.9),
            ),
          );
        },
      );
    }

    final deletedText = isCurrentUser
        ? 'You deleted this message'.tr()
        : 'This message was deleted'.tr();

    // Less vertical spacing when messages are merged in a chain
    final double verticalMargin =
        (shape == ChatBubbleShape.single || shape == ChatBubbleShape.first)
        ? 6
        : 2;

    const Radius r18 = Radius.circular(18);
    const Radius r10 = Radius.circular(10);
    const Radius r4 = Radius.circular(4);

    // Tail is on the side of the sender (current user = right, others = left)
    late Radius topLeft;
    late Radius topRight;
    late Radius bottomLeft;
    late Radius bottomRight;

    if (isCurrentUser) {
      switch (shape) {
        case ChatBubbleShape.single:
          topLeft = r18;
          topRight = r18;
          bottomLeft = r18;
          bottomRight = r4;
          break;
        case ChatBubbleShape.first:
          topLeft = r18;
          topRight = r18;
          bottomLeft = r10;
          bottomRight = r4;
          break;
        case ChatBubbleShape.middle:
          topLeft = r10;
          topRight = r10;
          bottomLeft = r10;
          bottomRight = r4;
          break;
        case ChatBubbleShape.last:
          topLeft = r10;
          topRight = r10;
          bottomLeft = r18;
          bottomRight = r4;
          break;
      }
    } else {
      switch (shape) {
        case ChatBubbleShape.single:
          topLeft = r18;
          topRight = r18;
          bottomLeft = r4;
          bottomRight = r18;
          break;
        case ChatBubbleShape.first:
          topLeft = r18;
          topRight = r18;
          bottomLeft = r4;
          bottomRight = r10;
          break;
        case ChatBubbleShape.middle:
          topLeft = r10;
          topRight = r10;
          bottomLeft = r4;
          bottomRight = r10;
          break;
        case ChatBubbleShape.last:
          topLeft = r10;
          topRight = r10;
          bottomLeft = r4;
          bottomRight = r18;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSenderName && !isDeleted) ...[
            Text(
              senderName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: senderColor ?? colors.primary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 2),
          ],

          // 🆕 Reply preview (quote box) — now tappable
          if (!isDeleted && shouldShowReplyPreview) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReplyTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.black.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: const Color(0xFF128C7E), width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumb (image or shared post)
                    Builder(
                      builder: (context) {
                        final thumb = _buildReplyThumb(context);
                        if (thumb == null) return const SizedBox(width: 0);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, top: 2),
                          child: thumb,
                        );
                      },
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyAuthorName != null &&
                              replyAuthorName!.trim().isNotEmpty)
                            const SizedBox(height: 1),
                          if (replyAuthorName != null &&
                              replyAuthorName!.trim().isNotEmpty)
                            const Text(''),
                          if (replyAuthorName != null &&
                              replyAuthorName!.trim().isNotEmpty)
                            Text(
                              replyAuthorName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF128C7E),
                              ),
                            ),
                          const SizedBox(height: 2),

                          // If replying to a shared post, show its caption/title.
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
                                fontStyle: replyHasMedia
                                    ? FontStyle.italic
                                    : null,
                                color: textColor.withValues(alpha: 0.9),
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
            // 🎥 Video
            if (hasVideo) ...[
              MyChatVideoBubble(
                videoUrl: videoUrl!,
                isUploading: isUploading,
                senderName: senderName,
                isCurrentUser: isCurrentUser,
              ),
              if (hasImages || hasText) const SizedBox(height: 6),
            ],

            // 🖼 Images
            if (hasImages) ...[
              _buildImageGrid(context),
              if (hasText) const SizedBox(height: 6),
            ],

            // 🆕 Internal shared post card (current message)
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? Colors.black.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shared a post'.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Caption / text
            if (hasText) ...[
              Text(
                message,
                style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
              ),
              const SizedBox(height: 4),
            ],
          ],

          // Time + ticks
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 11,
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
