import 'dart:async';
import 'package:flutter/material.dart';

/*
TIME AGO TEXT

Displays a "time ago" string like:
- Just now
- 10s ago
- 5m ago
- 3h ago
- 2d ago
- or full date if older than a week
*/

class TimeAgoText extends StatefulWidget {
  /// The createdAt DateTime from Supabase
  final DateTime createdAt;

  /// Optional TextStyle
  final TextStyle? style;

  const TimeAgoText({
    super.key,
    required this.createdAt,
    this.style,
  });

  @override
  State<TimeAgoText> createState() => _TimeAgoTextState();
}

class _TimeAgoTextState extends State<TimeAgoText> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Timer updates the text every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String getTimeAgo() {
    final now = DateTime.now().toUtc();
    final diff = now.difference(widget.createdAt.toUtc());

    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    // Older than a week, show full date
    return '${widget.createdAt.day}/${widget.createdAt.month}/${widget.createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(getTimeAgo(), style: widget.style);
  }
}
