// lib/helper/last_message_time_formatter.dart
//
// Formats a DateTime into a compact "chat style" label:
// - Same day  → "HH:mm"
// - Last 7d   → "Mon", "Tue", ...
// - Older     → "dd/MM"

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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }

  // Else → show dd/MM
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$d/$mo';
}
