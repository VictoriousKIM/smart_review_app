/// 한국 시간대 (KST, UTC+9)
class DateTimeUtils {
  /// 한국 시간대 오프셋 (9시간)
  static const Duration kstOffset = Duration(hours: 9);

  /// 현재 시간을 한국 시간으로 반환
  static DateTime nowKST() {
    return DateTime.now().toUtc().add(kstOffset);
  }

  /// UTC 시간을 한국 시간으로 변환
  static DateTime toKST(DateTime utcTime) {
    if (utcTime.isUtc) {
      return utcTime.add(kstOffset);
    }
    // 이미 로컬 시간인 경우, UTC로 변환 후 KST로 변환
    return utcTime.toUtc().add(kstOffset);
  }

  /// 문자열을 파싱하여 한국 시간으로 반환
  static DateTime parseKST(String dateString) {
    try {
      // ISO8601 형식 파싱
      final dateTime = DateTime.parse(dateString);
      // UTC로 간주하고 KST로 변환
      if (dateTime.isUtc || !dateString.contains('Z') && !dateString.contains('+')) {
        return dateTime.toUtc().add(kstOffset);
      }
      return toKST(dateTime);
    } catch (e) {
      // 파싱 실패 시 현재 한국 시간 반환
      return nowKST();
    }
  }

  /// 한국 시간을 ISO8601 문자열로 변환 (UTC로 저장)
  static String toIso8601StringKST(DateTime kstTime) {
    // KST에서 UTC로 변환
    final utcTime = kstTime.subtract(kstOffset);
    return utcTime.toUtc().toIso8601String();
  }

  /// 한국 시간을 포맷팅 (YYYY-MM-DD HH:mm)
  static String formatKST(DateTime kstTime) {
    return '${kstTime.year}-${kstTime.month.toString().padLeft(2, '0')}-${kstTime.day.toString().padLeft(2, '0')} '
        '${kstTime.hour.toString().padLeft(2, '0')}:${kstTime.minute.toString().padLeft(2, '0')}';
  }

  /// 한국 시간을 포맷팅 (YYYY-MM-DD HH:mm:ss)
  static String formatKSTWithSeconds(DateTime kstTime) {
    return '${kstTime.year}-${kstTime.month.toString().padLeft(2, '0')}-${kstTime.day.toString().padLeft(2, '0')} '
        '${kstTime.hour.toString().padLeft(2, '0')}:${kstTime.minute.toString().padLeft(2, '0')}:${kstTime.second.toString().padLeft(2, '0')}';
  }

  /// 상대 시간 포맷팅 (오늘, 어제, N일 전 등)
  static String formatRelativeKST(DateTime kstTime) {
    final now = nowKST();
    final difference = now.difference(kstTime);

    if (difference.inDays == 0) {
      return '오늘 ${kstTime.hour.toString().padLeft(2, '0')}:${kstTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제 ${kstTime.hour.toString().padLeft(2, '0')}:${kstTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${kstTime.month}/${kstTime.day}';
    }
  }
}

