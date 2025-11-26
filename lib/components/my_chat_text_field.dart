import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp-style chat input field (theme-aware)
/// - 🎤 Mic when empty and no attachment
/// - 📤 Send when typing OR when there's an attachment
/// - Tap sends text (only when there *is* text / attachment)
/// - Press & hold mic to record voice messages
/// - Breathing animation + haptic feedback while recording
/// - Slide away while holding mic to cancel recording
class MyChatTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSendPressed;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onEmojiPressed;

  /// If true, the send button becomes active even if text is empty.
  final bool hasPendingAttachment;

  /// Whether a voice recording is currently active
  final bool isRecording;

  /// Label to show while recording (e.g. "Recording… 0:05")
  final String? recordingLabel;

  /// Called when user presses down on the mic (start recording)
  final VoidCallback? onMicLongPressStart;

  /// Called when user releases the mic (stop recording & send)
  final VoidCallback? onMicLongPressEnd;

  /// Called when user slides away from the mic while holding and then releases
  /// (stop recording & discard, do NOT send)
  final VoidCallback? onMicCancel;

  const MyChatTextField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSendPressed,
    this.onAttachmentPressed,
    this.onEmojiPressed,
    this.hasPendingAttachment = false,
    this.isRecording = false,
    this.recordingLabel,
    this.onMicLongPressStart,
    this.onMicLongPressEnd,
    this.onMicCancel,
  });

  @override
  State<MyChatTextField> createState() => _MyChatTextFieldState();
}

class _MyChatTextFieldState extends State<MyChatTextField>
    with SingleTickerProviderStateMixin {
  bool _isTextEmpty = true;
  late final AnimationController _pulseController;

  // For slide-to-cancel
  Offset? _micStartGlobalPosition;
  bool _didSlideToCancel = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(covariant MyChatTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start/stop breathing animation when recording flag changes
    if (!oldWidget.isRecording && widget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (oldWidget.isRecording && !widget.isRecording) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  void _handleTextChange() {
    final isNowEmpty = widget.controller.text.trim().isEmpty;
    if (isNowEmpty != _isTextEmpty) {
      setState(() => _isTextEmpty = isNowEmpty);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Send enabled if there is text OR an attachment
    final bool canSend = !_isTextEmpty || widget.hasPendingAttachment;

    // Mic is visible only when nothing to send
    final bool showMicIcon = _isTextEmpty && !widget.hasPendingAttachment;

    return Row(
      children: [
        // 🟢 The pill: emoji + (text OR recording indicator) + attachment
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: colors.tertiary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                // 😀 Emoji button
                IconButton(
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: widget.onEmojiPressed,
                ),

                // 💬 Input field OR recording indicator
                Expanded(
                  child: widget.isRecording && widget.recordingLabel != null
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            // 👉 Only the label you pass in (e.g. "Recording… 0:05")
                            widget.recordingLabel!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.text,
                    minLines: 1,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.inversePrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Message",
                      hintStyle: TextStyle(fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                // 📎 Attachment button
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: colors.primary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: widget.onAttachmentPressed,
                ),
              ],
            ),
          ),
        ),

        // 🔵 Separate mic/send button
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,

            // 👉 Short tap: only send when there is something to send
            onTap: (!showMicIcon && !widget.isRecording && canSend)
                ? () {
              widget.onSendPressed();
            }
                : null,

            // 👉 Press & hold mic: use pan events so we can detect slide distance
            onPanDown: showMicIcon && widget.onMicLongPressStart != null
                ? (details) {
              _micStartGlobalPosition = details.globalPosition;
              _didSlideToCancel = false;
              HapticFeedback.mediumImpact();
              widget.onMicLongPressStart!.call();
            }
                : null,

            onPanUpdate: showMicIcon && widget.isRecording
                ? (details) {
              if (_micStartGlobalPosition == null) return;
              final dx = details.globalPosition.dx -
                  _micStartGlobalPosition!.dx;
              final dy = details.globalPosition.dy -
                  _micStartGlobalPosition!.dy;
              final distance = sqrt(dx * dx + dy * dy);

              // You can tweak this threshold if needed
              const cancelThreshold = 60.0;

              if (!_didSlideToCancel && distance > cancelThreshold) {
                _didSlideToCancel = true;
                HapticFeedback.heavyImpact();
              }
            }
                : null,

            onPanEnd: showMicIcon
                ? (details) {
              // If we slid far enough → cancel
              if (_didSlideToCancel &&
                  widget.onMicCancel != null &&
                  widget.isRecording) {
                widget.onMicCancel!.call();
              } else if (widget.onMicLongPressEnd != null &&
                  widget.isRecording) {
                // Otherwise → normal send
                widget.onMicLongPressEnd!.call();
              }

              _micStartGlobalPosition = null;
              _didSlideToCancel = false;
            }
                : null,

            onPanCancel: showMicIcon
                ? () {
              // Treat an unexpected cancel as a cancel of the recording
              if (widget.onMicCancel != null && widget.isRecording) {
                widget.onMicCancel!.call();
              }
              _micStartGlobalPosition = null;
              _didSlideToCancel = false;
            }
                : null,

            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // 🔎 Bigger base scale while recording + breathing pulse
                final double baseScale = widget.isRecording ? 1.4 : 1.0;
                final double pulse = widget.isRecording
                    ? (0.08 * _pulseController.value)
                    : 0.0;
                final double scale = baseScale + pulse;

                return Transform.scale(scale: scale, child: child);
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF128C7E), // WhatsApp green
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    showMicIcon ? Icons.mic : Icons.send,
                    key: ValueKey(showMicIcon),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
