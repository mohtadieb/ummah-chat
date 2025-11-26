import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// A compact voice message bubble that shows:
/// - Play / pause button
/// - Scrubbable slider
/// - Duration label
///
/// It does NOT handle ticks / time / likes – those are handled by the
/// outer MyChatBubble that wraps this widget.
class MyVoiceMessageBubble extends StatefulWidget {
  /// Public URL to the audio file in Supabase Storage
  final String audioUrl;

  /// Whether this bubble belongs to the current user
  /// (used only for coloring)
  final bool isCurrentUser;

  /// Optional duration in seconds from the DB.
  /// If null, we fall back to the actual audio duration once loaded.
  final int? durationSeconds;

  const MyVoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isCurrentUser,
    this.durationSeconds,
  });

  @override
  State<MyVoiceMessageBubble> createState() => _MyVoiceMessageBubbleState();
}

class _MyVoiceMessageBubbleState extends State<MyVoiceMessageBubble> {
  late final AudioPlayer _player;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  /// Initialize the audio source and attach listeners
  Future<void> _init() async {
    try {
      // ✅ Use AudioSource.uri instead of setUrl to avoid stale cached audio.
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(widget.audioUrl)),
        preload: true,
      );

      // If duration is known immediately, store it.
      final d = _player.duration;
      if (d != null) {
        setState(() {
          _duration = d;
        });
      }

      // Listen to duration updates (sometimes it’s only known after a bit).
      _player.durationStream.listen((d) {
        if (!mounted || d == null) return;
        setState(() {
          _duration = d;
        });
      });

      // Track playback position
      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
        });
      });

      // Track player state to update play/pause icon and reset on complete
      _player.playerStateStream.listen((state) {
        if (!mounted) return;

        final playing = state.playing;
        final completed =
            state.processingState == ProcessingState.completed;

        setState(() {
          _isPlaying = playing && !completed;

          if (completed) {
            // Reset to start when finished
            _player.seek(Duration.zero);
            _position = Duration.zero;
          }
        });
      });
    } catch (e) {
      debugPrint('Error init audio player: $e');
    }
  }

  /// 🔑 IMPORTANT:
  /// When Flutter reuses this State for a different message (new audioUrl),
  /// we must reload the source so it doesn't keep playing the old audio.
  @override
  void didUpdateWidget(covariant MyVoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audioUrl != widget.audioUrl) {
      _player
          .stop()
          .then(
            (_) => _player.setAudioSource(
          AudioSource.uri(Uri.parse(widget.audioUrl)),
          preload: true,
        ),
      )
          .then((_) {
        if (!mounted) return;
        setState(() {
          _duration = _player.duration ?? Duration.zero;
          _position = Duration.zero;
          _isPlaying = false;
        });
      }).catchError(
            (e) => debugPrint('Error updating audio source: $e'),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Format a Duration as m:ss
  String _format(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🎨 Bubble colors based on who sent it
    // Outgoing: primary
    // Incoming: a solid, visible container color instead of something that looks transparent
    final Color bubbleColor;
    final Color textColor;

    if (widget.isCurrentUser) {
      bubbleColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else {
      // Use a filled, contrasting color for received audio bubbles
      bubbleColor = theme.colorScheme.secondaryContainer;
      textColor = theme.colorScheme.onSecondaryContainer;
    }

    // Prefer the duration from DB, fall back to the real audio duration, and
    // guarantee at least 1s to avoid division-by-zero for the slider.
    final effectiveDuration = widget.durationSeconds != null
        ? Duration(seconds: widget.durationSeconds!)
        : (_duration == Duration.zero
        ? const Duration(seconds: 1)
        : _duration);

    final totalSeconds =
    effectiveDuration.inSeconds == 0 ? 1 : effectiveDuration.inSeconds;

    final progress = (_position.inSeconds / totalSeconds)
        .clamp(0.0, 1.0); // keep slider value safe

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ▶ / ⏸ button
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: textColor,
            ),
            onPressed: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.play();
              }
            },
          ),

          const SizedBox(width: 4),

          // Scrubbable slider
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: progress,
                onChanged: (value) {
                  final clamped = value.clamp(0.0, 1.0);
                  final newPos =
                      effectiveDuration * clamped; // Duration * double
                  _player.seek(newPos);
                },
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Duration label (e.g. 0:08)
          Text(
            _format(effectiveDuration),
            style: theme.textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
