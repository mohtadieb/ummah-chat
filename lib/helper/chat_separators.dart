// lib/helper/chat_separators.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Check if two DateTimes fall on the same calendar day (local time)
bool isSameDay(DateTime a, DateTime b) {
  final aa = a.toLocal();
  final bb = b.toLocal();
  return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
}

/// Returns labels like:
/// - "Today"
/// - "Yesterday"
/// - "Monday" (within last week)
/// - "12 Nov 2025" (older)
String formatDayLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);

  final diffDays = today.difference(thatDay).inDays;

  if (diffDays == 0) return 'Today'.tr();
  if (diffDays == 1) return 'Yesterday'.tr();
  if (diffDays >= 2 && diffDays <= 6) {
    final weekdays = [
      'Monday'.tr(),
      'Tuesday'.tr(),
      'Wednesday'.tr(),
      'Thursday'.tr(),
      'Friday'.tr(),
      'Saturday'.tr(),
      'Sunday'.tr(),
    ];
    return weekdays[local.weekday - 1];
  }

  final monthNames = [
    'Jan'.tr(),
    'Feb'.tr(),
    'Mar'.tr(),
    'Apr'.tr(),
    'May'.tr(),
    'Jun'.tr(),
    'Jul'.tr(),
    'Aug'.tr(),
    'Sep'.tr(),
    'Oct'.tr(),
    'Nov'.tr(),
    'Dec'.tr(),
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = monthNames[local.month - 1];
  final year = local.year.toString();
  return '$day $month $year';
}

/// Bubble-style day separator used between message groups
Widget buildDayBubble({
  required BuildContext context,
  required DateTime date,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final label = formatDayLabel(date);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.08),
            width: 0.7,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ),
    ),
  );
}

/// Bubble that shows "x unread messages" between read & unread sections
Widget buildUnreadBubble({
  required BuildContext context,
  required int unreadCount,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  final label = "unread messages".plural(
    unreadCount,
    namedArgs: {"count": unreadCount.toString()},
  );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary.withValues(alpha: 0.9),
          ),
        ),
      ),
    ),
  );
}
