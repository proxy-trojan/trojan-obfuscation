/// 将 [DateTime] 格式化为用户友好的相对或绝对时间字符串。
///
/// - 1 分钟内 → "刚刚"
/// - 1 小时内 → "X 分钟前"
/// - 24 小时内 → "X 小时前"
/// - 超过 24 小时 → "YYYY-MM-DD HH:mm"
String formatTimestamp(DateTime? dateTime, {DateTime? now}) {
  if (dateTime == null) return 'N/A';

  final currentTime = now ?? DateTime.now();
  final difference = currentTime.difference(dateTime);

  if (difference.isNegative) {
    return _formatAbsolute(dateTime);
  }

  if (difference.inSeconds < 60) {
    return '刚刚';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes 分钟前';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours 小时前';
  }

  return _formatAbsolute(dateTime);
}

String _formatAbsolute(DateTime dt) {
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-$month-$day $hour:$minute';
}
