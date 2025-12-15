import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
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
    final created = widget.createdAt.toUtc();
    final diff = now.difference(created);

    if (diff.inSeconds < 5) {
      return 'Just now'.tr();
    }

    if (diff.inSeconds < 60) {
      return 'seconds_ago'.tr(args: ['${diff.inSeconds}']);
    }

    if (diff.inMinutes < 60) {
      return 'minutes_ago'.tr(args: ['${diff.inMinutes}']);
    }

    if (diff.inHours < 24) {
      return 'hours_ago'.tr(args: ['${diff.inHours}']);
    }

    if (diff.inDays < 7) {
      return 'days_ago'.tr(args: ['${diff.inDays}']);
    }

    // Older than a week, show full date (non-localized numeric format)
    final d = widget.createdAt.day.toString().padLeft(2, '0');
    final m = widget.createdAt.month.toString().padLeft(2, '0');
    final y = widget.createdAt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    return Text(getTimeAgo(), style: widget.style);
  }
}
