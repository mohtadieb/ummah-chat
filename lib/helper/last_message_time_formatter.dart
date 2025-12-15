// lib/helper/last_message_time_formatter.dart
//
// Formats a DateTime into a compact "chat style" label:
// - Same day  → "HH:mm"
// - Last 7d   → "Mon", "Tue", ...
// - Older     → "dd/MM"

import 'package:easy_localization/easy_localization.dart';

String? formatLastMessageTime(DateTime? time) {
  if (time == null) return null;

  final now = DateTime.now();
  final local = time.toLocal();
  final difference = now.difference(local);

  // Same day → show HH:mm
  if (difference.inDays == 0 && local.day == now.day) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Within last 7 days → show weekday (Mon, Tue...)
  if (difference.inDays < 7) {
    final weekdays = ['Mon'.tr(), 'Tue'.tr(), 'Wed'.tr(), 'Thu'.tr(), 'Fri'.tr(), 'Sat'.tr(), 'Sun'.tr()];
    return weekdays[local.weekday - 1];
  }

  // Else → show dd/MM
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$d/$mo';
}
