// lib/components/chat_video_bubble.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'my_chat_video_fullscreen.dart';

/// Inline video *thumbnail* for a chat bubble:
/// - Shows thumbnail + play icon
/// - Shows duration label (e.g. "0:12")
/// - If [isUploading] = true: shows a progress bar + disables tap
/// - On tap → fullscreen dialog with real video player + scrubber
class MyChatVideoBubble extends StatefulWidget {
  final String videoUrl;
  final bool isUploading;

  /// Used for fullscreen header
  final String? senderName;
  final bool isCurrentUser;

  const MyChatVideoBubble({
    super.key,
    required this.videoUrl,
    required this.isUploading,
    required this.senderName,
    required this.isCurrentUser,
  });

  @override
  State<MyChatVideoBubble> createState() => _MyChatVideoBubbleState();
}

class _MyChatVideoBubbleState extends State<MyChatVideoBubble> {
  Uint8List? _thumb;
  bool _thumbLoading = true;

  Duration? _duration; // for bottom-right "0:12" label

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _loadDuration();
  }

  Future<void> _loadThumbnail() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 60,
      );
      if (!mounted) return;
      setState(() {
        _thumb = data;
        _thumbLoading = false;
      });
    } catch (e) {
      debugPrint('Video thumbnail error: $e');
      if (!mounted) return;
      setState(() {
        _thumbLoading = false;
      });
    }
  }

  Future<void> _loadDuration() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _duration = controller.value.duration;
      });
      await controller.dispose();
    } catch (e) {
      debugPrint('Video duration load error: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _openFullscreen() async {
    if (widget.isUploading) {
      // Ignore taps while still uploading
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close video',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MyChatVideoFullscreenPlayer(
          videoUrl: widget.videoUrl,
          senderName: widget.senderName,
          isCurrentUser: widget.isCurrentUser,
        );
      },
      transitionBuilder: (context, anim, secondary, child) {
        // Smooth pop-in / pop-out (WhatsApp-style)
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return Transform.scale(
          scale: 0.9 + 0.1 * curved.value,
          child: Opacity(
            opacity: anim.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const aspectRatio = 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10), // slightly thinner corners
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          onTap: _openFullscreen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: thumbnail or gradient
              if (_thumb != null)
                Image.memory(
                  _thumb!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

              // Light overlay for contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Play button (hidden while uploading)
              if (!widget.isUploading)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Little spinner while just loading thumbnail
              if (_thumbLoading)
                const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // Duration label bottom-right (e.g. "0:12")
              if (_duration != null)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(_duration!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Upload progress bar along the bottom
              if (widget.isUploading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.black.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
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
