// lib/components/my_chat_bubble.dart
import 'package:flutter/material.dart';

import '../pages/fullscreen_image_page.dart';
import 'my_chat_video_bubble.dart';

/// A simple chat bubble that adapts to the app's current theme.
///
/// - Uses Theme.of(context).colorScheme for colors
/// - Aligns right for current user, left for others
/// - Smooth rounded WhatsApp-style shape
/// - Shows timestamp + ticks (for current user's messages)
/// - Supports "like" with double-tap
/// - Can optionally show sender name (for group chats) inside the bubble
/// - 🖼 Can show one or multiple images above the text
/// - 🎥 Uses [ChatVideoBubble] for video thumbnails
/// - 🆕 Shows an uploading indicator for pending video messages
/// - 🆕 Supports soft-delete ("This message was deleted")
class MyChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;

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

  /// Optional long-press handler (used to delete message)
  final VoidCallback? onLongPress;

  /// Optional tap handler for the like badge (heart)
  final VoidCallback? onLikeTap;

  /// Optional: sender display name (used in group chats or passed from ChatPage).
  final String? senderName;

  /// Optional: specific color for the sender name text.
  /// If null, a fallback color based on theme will be used.
  final Color? senderColor;

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
    this.isDeleted = false, // 🆕 default
    this.onDoubleTap,
    this.onLongPress,
    this.onLikeTap,
    this.senderName,
    this.senderColor,
  });

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m'; // WhatsApp-style short time
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

    // If deleted: never show images / videos / text content.
    final bool hasImages = !isDeleted && effectiveImageUrls.isNotEmpty;
    final bool hasVideo = !isDeleted && videoUrl != null && videoUrl!.trim().isNotEmpty;
    final bool hasText = !isDeleted && message.trim().isNotEmpty;

    // 🟢 Sender (current user) bubble style
    final senderBg = const Color(0xFF128C7E); // WhatsApp green
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

    // ❤️ Heart icon – same style for you vs others
    const heartIcon = Icon(
      Icons.favorite,
      size: 12,
      color: Colors.pinkAccent,
    );

    // ❤️ Like badge: only if NOT deleted
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
              borderRadius: BorderRadius.circular(20), // pill shape
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

    final deletedText = isCurrentUser
        ? 'You deleted this message'
        : 'This message was deleted';

    // ---------- FULL BUBBLE ----------

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft:
          isCurrentUser ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight:
          isCurrentUser ? const Radius.circular(4) : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(1, 2),
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
                fontWeight: FontWeight.w600,
                color: senderColor ?? colors.primary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 2),
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
            // 🎥 Video preview (tap → fullscreen overlay)
            if (hasVideo) ...[
              MyChatVideoBubble(
                videoUrl: videoUrl!,
                isUploading: isUploading,
                senderName: senderName,
                isCurrentUser: isCurrentUser,
              ),
              if (hasImages || hasText) const SizedBox(height: 6),
            ],

            // 🖼 Images (single or grid)
            if (hasImages) ...[
              _buildImageGrid(context),
              if (hasText) const SizedBox(height: 6),
            ],

            // Caption / text
            if (hasText) ...[
              Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.3,
                ),
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
                Icon(
                  tickIcon,
                  size: 14,
                  color: tickColor,
                ),
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
