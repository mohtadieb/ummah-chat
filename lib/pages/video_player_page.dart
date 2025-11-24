// lib/pages/video_player_page.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  /// Optional hero tag to match the preview bubble
  final String? heroTag;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.heroTag,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..setLooping(true);

    _controller.addListener(_onVideoChanged);

    _controller
        .initialize()
        .timeout(const Duration(seconds: 10))
        .then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _duration = _controller.value.duration;
      });
      _controller.play();
    }).catchError((e) {
      debugPrint('Video init error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load video.';
      });
    });
  }

  void _onVideoChanged() {
    if (!mounted || !_controller.value.isInitialized) return;

    setState(() {
      _isPlaying = _controller.value.isPlaying;
      _position = _controller.value.position;
      _duration = _controller.value.duration;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget content;

    if (_errorMessage != null) {
      content = Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: colors.onSurface, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    } else if (!_isInitialized) {
      content = Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    } else {
      final videoChild = AspectRatio(
        aspectRatio: _controller.value.aspectRatio == 0
            ? 16 / 9
            : _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            GestureDetector(
              onTap: _togglePlayPause,
              child: AnimatedOpacity(
                opacity: _isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
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
        ),
      );

      final heroWrapped = widget.heroTag == null
          ? videoChild
          : Hero(
        tag: widget.heroTag!,
        child: videoChild,
      );

      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: heroWrapped,
            ),
          ),
          const SizedBox(height: 12),
          if (_duration.inMilliseconds > 0) ...[
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                      color:
                      colors.onSurface.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _position.inMilliseconds
                          .toDouble()
                          .clamp(
                        0.0,
                        _duration.inMilliseconds
                            .toDouble(),
                      ),
                      min: 0.0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        final newPos = Duration(
                          milliseconds: value.toInt(),
                        );
                        _controller.seekTo(newPos);
                      },
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      color:
                      colors.onSurface.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Video',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: content,
            ),
          ),
        ),
      ),
      floatingActionButton:
      _isInitialized && _errorMessage == null
          ? FloatingActionButton(
        onPressed: _togglePlayPause,
        backgroundColor: colors.primary,
        child: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      )
          : null,
    );
  }
}
