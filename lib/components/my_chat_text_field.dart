import 'package:flutter/material.dart';

/// WhatsApp-style chat input field (theme-aware)
/// - 🎤 Mic when empty and no attachment
/// - 📤 Send when typing OR when there's an attachment
/// - Animated icon transition
/// - Adapts to light/dark mode using Theme.of(context).colorScheme
class MyChatTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSendPressed;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onEmojiPressed;

  /// 🆕 If true, the send button becomes active even if text is empty.
  final bool hasPendingAttachment;

  const MyChatTextField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSendPressed,
    this.onAttachmentPressed,
    this.onEmojiPressed,
    this.hasPendingAttachment = false,
  });

  @override
  State<MyChatTextField> createState() => _MyChatTextFieldState();
}

class _MyChatTextFieldState extends State<MyChatTextField> {
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final bool canSend =
        !_isTextEmpty || widget.hasPendingAttachment; // 🆕 send enabled if text OR attachment

    final bool showMicIcon =
        _isTextEmpty && !widget.hasPendingAttachment; // mic only when nothing to send

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiary, // background behind text field
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // 😀 Emoji button
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: colors.primary),
            onPressed: widget.onEmojiPressed,
          ),

          // 💬 Input field
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(color: colors.inversePrimary),
              decoration: InputDecoration(
                hintText: "Message",
                hintStyle: TextStyle(color: colors.primary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // 📎 Attachment button
          IconButton(
            icon: Icon(Icons.attach_file, color: colors.primary),
            onPressed: widget.onAttachmentPressed,
          ),

          // 🎤 or 📤 Animated icon button (WhatsApp-style green)
          const SizedBox(width: 4),
          GestureDetector(
            onTap: canSend ? widget.onSendPressed : null,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF128C7E), // WhatsApp green
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  showMicIcon ? Icons.mic : Icons.send,
                  key: ValueKey(showMicIcon),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
