import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyChatTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSendPressed;
  final VoidCallback? onAttachmentPressed;

  /// Kept for backwards compatibility, but no emoji button is rendered anymore.
  final VoidCallback? onEmojiPressed;

  final bool hasPendingAttachment;
  final bool isRecording;
  final String? recordingLabel;
  final VoidCallback? onMicLongPressStart;
  final VoidCallback? onMicLongPressEnd;
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

  Offset? _micStartGlobalPosition;
  bool _didSlideToCancel = false;

  @override
  void initState() {
    super.initState();
    _isTextEmpty = widget.controller.text.trim().isEmpty;
    widget.controller.addListener(_handleTextChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(covariant MyChatTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool canSend = !_isTextEmpty || widget.hasPendingAttachment;
    final bool showMicIcon = _isTextEmpty && !widget.hasPendingAttachment;

    final pillColor = isDark ? const Color(0xFF121A17) : Colors.white;
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colors.outline.withValues(alpha: 0.10);

    final inputTextColor = colors.onSurface;
    final hintColor = colors.onSurface.withValues(alpha: 0.52);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: pillBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.isRecording && widget.recordingLabel != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.recordingLabel!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5,
                      style: TextStyle(
                        color: inputTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: "Message".tr(),
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.attach_file_rounded,
                  onTap: widget.onAttachmentPressed,
                  iconColor: colors.primary,
                  backgroundColor: colors.primary.withValues(alpha: 0.08),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: (!showMicIcon && !widget.isRecording && canSend)
              ? widget.onSendPressed
              : null,
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
            final dx =
                details.globalPosition.dx - _micStartGlobalPosition!.dx;
            final dy =
                details.globalPosition.dy - _micStartGlobalPosition!.dy;
            final distance = sqrt(dx * dx + dy * dy);

            const cancelThreshold = 60.0;

            if (!_didSlideToCancel && distance > cancelThreshold) {
              _didSlideToCancel = true;
              HapticFeedback.heavyImpact();
            }
          }
              : null,
          onPanEnd: showMicIcon
              ? (_) {
            if (_didSlideToCancel &&
                widget.onMicCancel != null &&
                widget.isRecording) {
              widget.onMicCancel!.call();
            } else if (widget.onMicLongPressEnd != null &&
                widget.isRecording) {
              widget.onMicLongPressEnd!.call();
            }

            _micStartGlobalPosition = null;
            _didSlideToCancel = false;
          }
              : null,
          onPanCancel: showMicIcon
              ? () {
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
              final double baseScale = widget.isRecording ? 1.4 : 1.0;
              final double pulse =
              widget.isRecording ? (0.08 * _pulseController.value) : 0.0;
              return Transform.scale(
                scale: baseScale + pulse,
                child: child,
              );
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4A8B61),
                    Color(0xFF2F6E46),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F6E46).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  showMicIcon ? Icons.mic_rounded : Icons.send_rounded,
                  key: ValueKey(showMicIcon),
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color backgroundColor;

  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}