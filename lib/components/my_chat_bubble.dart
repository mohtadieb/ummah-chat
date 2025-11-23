import 'package:flutter/material.dart';

/// A chat bubble that supports:
/// - Single or multiple images
/// - Caption / text
/// - Ticks (sent/delivered/read)
/// - Likes (heart badge)
/// - Optional senderName / senderColor for group chats
class MyChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;

  /// Optional single image URL (legacy).
  final String? imageUrl;

  /// Optional multiple image URLs for a single bubble.
  /// If provided, takes precedence over [imageUrl].
  final List<String>? imageUrls;

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

  /// Optional double-tap handler (used to toggle like)
  final VoidCallback? onDoubleTap;

  /// Optional tap handler for the like badge (heart)
  final VoidCallback? onLikeTap;

  /// Optional: sender display name (used in group chats).
  /// For DMs you can leave this null.
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
    this.imageUrls,
    this.isRead = false,
    this.isDelivered = false,
    this.isLikedByMe = false,
    this.likeCount = 0,
    this.onDoubleTap,
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

  /// All effective media URLs for this bubble
  List<String> _effectiveImageUrls() {
    // If imageUrls is provided, use it
    final base = imageUrls ??
        (imageUrl != null && imageUrl!.trim().isNotEmpty
            ? <String>[imageUrl!]
            : <String>[]);

    return base
        .where((u) => u.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool get _hasText => message.trim().isNotEmpty;

  void _openFullscreenGallery(BuildContext context, List<String> urls, int index) {
    if (urls.isEmpty) return;

    final pageController = PageController(initialPage: index);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: PageView.builder(
              controller: pageController,
              itemCount: urls.length,
              itemBuilder: (context, i) {
                final url = urls[i];
                return InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) {
                      return const Icon(Icons.broken_image, size: 64, color: Colors.white70);
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> urls) {
    if (urls.length == 1) {
      final url = urls.first;
      return GestureDetector(
        onTap: () => _openFullscreenGallery(context, urls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: 180,
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
                height: 180,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 32),
              );
            },
          ),
        ),
      );
    }

    // 2+ images → simple grid
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: urls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemBuilder: (context, index) {
          final url = urls[index];
          return GestureDetector(
            onTap: () => _openFullscreenGallery(context, urls, index),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 24),
                );
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final mediaUrls = _effectiveImageUrls();
    final hasImages = mediaUrls.isNotEmpty;

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
      // sent / delivered / read logic
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

    // ❤️ Like badge: white circle OR white pill depending on count
    Widget? likeBadge;
    if (likeCount > 0) {
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
                  color: Colors.black.withOpacity(0.06),
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
                  color: Colors.black.withOpacity(0.06),
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

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          // 🧑‍🤝‍🧑 Sender name inside bubble for group chats
          if (showSenderName) ...[
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

          // 🖼 Images (one or many)
          if (hasImages) ...[
            _buildImageGrid(context, mediaUrls),
            if (_hasText) const SizedBox(height: 6),
          ],

          // The actual message text (caption or normal text)
          if (_hasText) ...[
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

          // Time + (optional) ticks
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            if (likeBadge != null)
              Positioned(
                bottom: -14, // slight overlap, not blocking ticks
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
