// lib/components/chat_video_fullscreen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen overlay video player:
/// - Pops in with a small scale + fade animation (handled by showGeneralDialog)
/// - Autoplays on open
/// - Stops + disposes on close
/// - Has scrubber + time indicators
/// - Shows sender name in top bar
/// - Supports swipe-down or tap to dismiss
class MyChatVideoFullscreenPlayer extends StatefulWidget {
  final String videoUrl;
  final String? senderName;
  final bool isCurrentUser;

  const MyChatVideoFullscreenPlayer({
    super.key,
    required this.videoUrl,
    required this.senderName,
    required this.isCurrentUser,
  });

  @override
  State<MyChatVideoFullscreenPlayer> createState() =>
      _MyChatVideoFullscreenPlayerState();
}

class _MyChatVideoFullscreenPlayerState extends State<MyChatVideoFullscreenPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;

    controller.addListener(_onVideoChanged);

    try {
      await controller.initialize();
      if (!mounted) return;

      controller.setLooping(true);
      controller.play();

      setState(() {
        _isInitialized = true;
        _isPlaying = true;
        _duration = controller.value.duration;
      });
    } catch (e) {
      debugPrint('Fullscreen video init error: $e');
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _isPlaying = false;
      });
    }
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }

    final val = controller.value;
    setState(() {
      _isPlaying = val.isPlaying;
      _position = val.position;
      _duration = val.duration;
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _headerTitle {
    if (widget.isCurrentUser) return 'You'.tr();
    if (widget.senderName != null && widget.senderName!.trim().isNotEmpty) {
      return widget.senderName!;
    }
    return 'Contact'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final controller = _controller;
    final aspectRatio = (controller != null &&
        controller.value.isInitialized &&
        controller.value.aspectRatio != 0)
        ? controller.value.aspectRatio
        : 16 / 9;

    final showSlider = _isInitialized && _duration.inMilliseconds > 0;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap anywhere on dark background (outside controls) to close
        onTap: () => Navigator.of(context).pop(),
        onVerticalDragUpdate: (details) {
          // Simple TikTok-style swipe-down to dismiss
          if (details.primaryDelta != null && details.primaryDelta! > 12) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // Dark background
            Container(color: Colors.black87),

            // Main content inside SafeArea, full height, no overflow
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar with sender name + close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Video area – takes all remaining space, shrinks on small screens
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: _isInitialized && controller != null
                            ? Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(controller),
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: AnimatedOpacity(
                                opacity: _isPlaying ? 0.0 : 1.0,
                                duration:
                                const Duration(milliseconds: 200),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                            : Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom scrubber + time labels
                  if (showSlider)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: 0.0,
                              max: _duration.inMilliseconds.toDouble(),
                              value: _position.inMilliseconds
                                  .clamp(0, _duration.inMilliseconds)
                                  .toDouble(),
                              onChanged: (value) {
                                final c = _controller;
                                if (c == null) return;
                                final newPos = Duration(
                                  milliseconds: value.toInt(),
                                );
                                c.seekTo(newPos);
                              },
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
