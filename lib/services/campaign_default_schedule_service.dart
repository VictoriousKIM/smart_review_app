import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_time_utils.dart';

/// 캠페인 기본 일정 설정 서비스 (로컬스토리지)
class CampaignDefaultScheduleService {
  // SharedPreferences 키
  static const String _keyApplyStartDays = 'campaign_default_apply_start_days';
  static const String _keyApplyStartTime = 'campaign_default_apply_start_time';
  static const String _keyApplyEndDays = 'campaign_default_apply_end_days';
  static const String _keyApplyEndTime = 'campaign_default_apply_end_time';
  static const String _keyReviewStartDays = 'campaign_default_review_start_days';
  static const String _keyReviewStartTime = 'campaign_default_review_start_time';
  static const String _keyReviewEndDays = 'campaign_default_review_end_days';
  static const String _keyReviewEndTime = 'campaign_default_review_end_time';
  
  // 리뷰 설정 키
  static const String _keyReviewType = 'campaign_default_review_type';
  static const String _keyReviewTextLength = 'campaign_default_review_text_length';
  static const String _keyReviewImageCount = 'campaign_default_review_image_count';
  static const String _keyCampaignReward = 'campaign_default_campaign_reward';
  static const String _keyUseReviewKeywords = 'campaign_default_use_review_keywords';
  static const String _keyReviewKeywords = 'campaign_default_review_keywords';
  
  // 중복방지 설정 키
  static const String _keyPreventProductDuplicate = 'campaign_default_prevent_product_duplicate';
  static const String _keyPreventStoreDuplicate = 'campaign_default_prevent_store_duplicate';
  static const String _keyDuplicatePreventDays = 'campaign_default_duplicate_prevent_days';

  // 기본값
  static const int _defaultApplyStartDays = 0; // 오늘
  static const String _defaultApplyStartTime = '14:00';
  static const int _defaultApplyEndDays = 0; // 오늘
  static const String _defaultApplyEndTime = '18:00';
  static const int _defaultReviewStartDays = 2;
  static const String _defaultReviewStartTime = '08:00';
  static const int _defaultReviewEndDays = 5;
  static const String _defaultReviewEndTime = '20:00';
  
  // 리뷰 설정 기본값
  static const String _defaultReviewType = 'star_only';
  static const int _defaultReviewTextLength = 100;
  static const int _defaultReviewImageCount = 1;
  static const int _defaultCampaignReward = 0;
  static const bool _defaultUseReviewKeywords = false;
  static const String _defaultReviewKeywords = '';
  
  // 중복방지 설정 기본값
  static const bool _defaultPreventProductDuplicate = false;
  static const bool _defaultPreventStoreDuplicate = false;
  static const int _defaultDuplicatePreventDays = 0;

  /// 기본 일정 설정 모델
  static CampaignDefaultSchedule getDefaultSchedule() {
    return CampaignDefaultSchedule(
      applyStartDays: _defaultApplyStartDays,
      applyStartTime: _defaultApplyStartTime,
      applyEndDays: _defaultApplyEndDays,
      applyEndTime: _defaultApplyEndTime,
      reviewStartDays: _defaultReviewStartDays,
      reviewStartTime: _defaultReviewStartTime,
      reviewEndDays: _defaultReviewEndDays,
      reviewEndTime: _defaultReviewEndTime,
    );
  }

  /// 저장된 기본 일정 설정 로드
  static Future<CampaignDefaultSchedule> loadDefaultSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return CampaignDefaultSchedule(
        applyStartDays: prefs.getInt(_keyApplyStartDays) ?? _defaultApplyStartDays,
        applyStartTime: prefs.getString(_keyApplyStartTime) ?? _defaultApplyStartTime,
        applyEndDays: prefs.getInt(_keyApplyEndDays) ?? _defaultApplyEndDays,
        applyEndTime: prefs.getString(_keyApplyEndTime) ?? _defaultApplyEndTime,
        reviewStartDays: prefs.getInt(_keyReviewStartDays) ?? _defaultReviewStartDays,
        reviewStartTime: prefs.getString(_keyReviewStartTime) ?? _defaultReviewStartTime,
        reviewEndDays: prefs.getInt(_keyReviewEndDays) ?? _defaultReviewEndDays,
        reviewEndTime: prefs.getString(_keyReviewEndTime) ?? _defaultReviewEndTime,
      );
    } catch (e) {
      // 에러 발생 시 기본값 반환
      return getDefaultSchedule();
    }
  }
  
  /// 저장된 기본 리뷰 설정 로드
  static Future<CampaignDefaultReviewSettings> loadDefaultReviewSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return CampaignDefaultReviewSettings(
        reviewType: prefs.getString(_keyReviewType) ?? _defaultReviewType,
        reviewTextLength: prefs.getInt(_keyReviewTextLength) ?? _defaultReviewTextLength,
        reviewImageCount: prefs.getInt(_keyReviewImageCount) ?? _defaultReviewImageCount,
        campaignReward: prefs.getInt(_keyCampaignReward) ?? _defaultCampaignReward,
        useReviewKeywords: prefs.getBool(_keyUseReviewKeywords) ?? _defaultUseReviewKeywords,
        reviewKeywords: prefs.getString(_keyReviewKeywords) ?? _defaultReviewKeywords,
      );
    } catch (e) {
      return CampaignDefaultReviewSettings.getDefault();
    }
  }
  
  /// 기본 리뷰 설정 저장
  static Future<bool> saveDefaultReviewSettings(CampaignDefaultReviewSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyReviewType, settings.reviewType);
      await prefs.setInt(_keyReviewTextLength, settings.reviewTextLength);
      await prefs.setInt(_keyReviewImageCount, settings.reviewImageCount);
      await prefs.setInt(_keyCampaignReward, settings.campaignReward);
      await prefs.setBool(_keyUseReviewKeywords, settings.useReviewKeywords);
      await prefs.setString(_keyReviewKeywords, settings.reviewKeywords);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 저장된 기본 중복방지 설정 로드
  static Future<CampaignDefaultDuplicateSettings> loadDefaultDuplicateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return CampaignDefaultDuplicateSettings(
        preventProductDuplicate: prefs.getBool(_keyPreventProductDuplicate) ?? _defaultPreventProductDuplicate,
        preventStoreDuplicate: prefs.getBool(_keyPreventStoreDuplicate) ?? _defaultPreventStoreDuplicate,
        duplicatePreventDays: prefs.getInt(_keyDuplicatePreventDays) ?? _defaultDuplicatePreventDays,
      );
    } catch (e) {
      return CampaignDefaultDuplicateSettings.getDefault();
    }
  }
  
  /// 기본 중복방지 설정 저장
  static Future<bool> saveDefaultDuplicateSettings(CampaignDefaultDuplicateSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_keyPreventProductDuplicate, settings.preventProductDuplicate);
      await prefs.setBool(_keyPreventStoreDuplicate, settings.preventStoreDuplicate);
      await prefs.setInt(_keyDuplicatePreventDays, settings.duplicatePreventDays);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 기본 일정 설정 저장
  static Future<bool> saveDefaultSchedule(CampaignDefaultSchedule schedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_keyApplyStartDays, schedule.applyStartDays);
      await prefs.setString(_keyApplyStartTime, schedule.applyStartTime);
      await prefs.setInt(_keyApplyEndDays, schedule.applyEndDays);
      await prefs.setString(_keyApplyEndTime, schedule.applyEndTime);
      await prefs.setInt(_keyReviewStartDays, schedule.reviewStartDays);
      await prefs.setString(_keyReviewStartTime, schedule.reviewStartTime);
      await prefs.setInt(_keyReviewEndDays, schedule.reviewEndDays);
      await prefs.setString(_keyReviewEndTime, schedule.reviewEndTime);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 기본 일정 설정을 DateTime으로 변환
  static Map<String, DateTime> getDefaultDateTimes() {
    final schedule = getDefaultSchedule();
    return _scheduleToDateTimes(schedule);
  }

  /// 저장된 기본 일정 설정을 DateTime으로 변환
  static Future<Map<String, DateTime>> loadDefaultDateTimes() async {
    final schedule = await loadDefaultSchedule();
    return _scheduleToDateTimes(schedule);
  }

  /// 기본 일정 설정을 DateTime으로 변환 (내부 메서드)
  static Map<String, DateTime> _scheduleToDateTimes(CampaignDefaultSchedule schedule) {
    
    // 시간 파싱 (HH:mm 형식)
    final applyStartTimeParts = schedule.applyStartTime.split(':');
    final applyEndTimeParts = schedule.applyEndTime.split(':');
    final reviewStartTimeParts = schedule.reviewStartTime.split(':');
    final reviewEndTimeParts = schedule.reviewEndTime.split(':');
    
    final applyStartHour = int.parse(applyStartTimeParts[0]);
    final applyStartMinute = int.parse(applyStartTimeParts[1]);
    final applyEndHour = int.parse(applyEndTimeParts[0]);
    final applyEndMinute = int.parse(applyEndTimeParts[1]);
    final reviewStartHour = int.parse(reviewStartTimeParts[0]);
    final reviewStartMinute = int.parse(reviewStartTimeParts[1]);
    final reviewEndHour = int.parse(reviewEndTimeParts[0]);
    final reviewEndMinute = int.parse(reviewEndTimeParts[1]);
    
    // 신청 시작일시: 오늘 + applyStartDays일
    final applyStartDate = DateTimeUtils.nowKST().add(Duration(days: schedule.applyStartDays)).copyWith(
      hour: applyStartHour,
      minute: applyStartMinute,
      second: 0,
      millisecond: 0,
    );
    
    // 신청 종료일시: 오늘 + applyEndDays일
    final applyEndDate = DateTimeUtils.nowKST().add(Duration(days: schedule.applyEndDays)).copyWith(
      hour: applyEndHour,
      minute: applyEndMinute,
      second: 0,
      millisecond: 0,
    );
    
    // 리뷰 시작일시: 오늘 + reviewStartDays일
    final reviewStartDate = DateTimeUtils.nowKST().add(Duration(days: schedule.reviewStartDays)).copyWith(
      hour: reviewStartHour,
      minute: reviewStartMinute,
      second: 0,
      millisecond: 0,
    );
    
    // 리뷰 종료일시: 오늘 + reviewEndDays일
    final reviewEndDate = DateTimeUtils.nowKST().add(Duration(days: schedule.reviewEndDays)).copyWith(
      hour: reviewEndHour,
      minute: reviewEndMinute,
      second: 0,
      millisecond: 0,
    );
    
    return {
      'applyStart': applyStartDate,
      'applyEnd': applyEndDate,
      'reviewStart': reviewStartDate,
      'reviewEnd': reviewEndDate,
    };
  }
}

/// 기본 일정 설정 모델
class CampaignDefaultSchedule {
  final int applyStartDays; // 오늘로부터 며칠 후
  final String applyStartTime; // HH:mm 형식
  final int applyEndDays; // 오늘로부터 며칠 후
  final String applyEndTime; // HH:mm 형식
  final int reviewStartDays; // 오늘로부터 며칠 후
  final String reviewStartTime; // HH:mm 형식
  final int reviewEndDays; // 오늘로부터 며칠 후
  final String reviewEndTime; // HH:mm 형식

  CampaignDefaultSchedule({
    required this.applyStartDays,
    required this.applyStartTime,
    required this.applyEndDays,
    required this.applyEndTime,
    required this.reviewStartDays,
    required this.reviewStartTime,
    required this.reviewEndDays,
    required this.reviewEndTime,
  });

  /// 기본값으로 복사
  CampaignDefaultSchedule copyWith({
    int? applyStartDays,
    String? applyStartTime,
    int? applyEndDays,
    String? applyEndTime,
    int? reviewStartDays,
    String? reviewStartTime,
    int? reviewEndDays,
    String? reviewEndTime,
  }) {
    return CampaignDefaultSchedule(
      applyStartDays: applyStartDays ?? this.applyStartDays,
      applyStartTime: applyStartTime ?? this.applyStartTime,
      applyEndDays: applyEndDays ?? this.applyEndDays,
      applyEndTime: applyEndTime ?? this.applyEndTime,
      reviewStartDays: reviewStartDays ?? this.reviewStartDays,
      reviewStartTime: reviewStartTime ?? this.reviewStartTime,
      reviewEndDays: reviewEndDays ?? this.reviewEndDays,
      reviewEndTime: reviewEndTime ?? this.reviewEndTime,
    );
  }
}

/// 기본 리뷰 설정 모델
class CampaignDefaultReviewSettings {
  final String reviewType;
  final int reviewTextLength;
  final int reviewImageCount;
  final int campaignReward;
  final bool useReviewKeywords;
  final String reviewKeywords;

  CampaignDefaultReviewSettings({
    required this.reviewType,
    required this.reviewTextLength,
    required this.reviewImageCount,
    required this.campaignReward,
    required this.useReviewKeywords,
    required this.reviewKeywords,
  });
  
  static CampaignDefaultReviewSettings getDefault() {
    return CampaignDefaultReviewSettings(
      reviewType: 'star_only',
      reviewTextLength: 100,
      reviewImageCount: 1,
      campaignReward: 0,
      useReviewKeywords: false,
      reviewKeywords: '',
    );
  }
  
  CampaignDefaultReviewSettings copyWith({
    String? reviewType,
    int? reviewTextLength,
    int? reviewImageCount,
    int? campaignReward,
    bool? useReviewKeywords,
    String? reviewKeywords,
  }) {
    return CampaignDefaultReviewSettings(
      reviewType: reviewType ?? this.reviewType,
      reviewTextLength: reviewTextLength ?? this.reviewTextLength,
      reviewImageCount: reviewImageCount ?? this.reviewImageCount,
      campaignReward: campaignReward ?? this.campaignReward,
      useReviewKeywords: useReviewKeywords ?? this.useReviewKeywords,
      reviewKeywords: reviewKeywords ?? this.reviewKeywords,
    );
  }
}

/// 기본 중복방지 설정 모델
class CampaignDefaultDuplicateSettings {
  final bool preventProductDuplicate;
  final bool preventStoreDuplicate;
  final int duplicatePreventDays;

  CampaignDefaultDuplicateSettings({
    required this.preventProductDuplicate,
    required this.preventStoreDuplicate,
    required this.duplicatePreventDays,
  });
  
  static CampaignDefaultDuplicateSettings getDefault() {
    return CampaignDefaultDuplicateSettings(
      preventProductDuplicate: false,
      preventStoreDuplicate: false,
      duplicatePreventDays: 0,
    );
  }
  
  CampaignDefaultDuplicateSettings copyWith({
    bool? preventProductDuplicate,
    bool? preventStoreDuplicate,
    int? duplicatePreventDays,
  }) {
    return CampaignDefaultDuplicateSettings(
      preventProductDuplicate: preventProductDuplicate ?? this.preventProductDuplicate,
      preventStoreDuplicate: preventStoreDuplicate ?? this.preventStoreDuplicate,
      duplicatePreventDays: duplicatePreventDays ?? this.duplicatePreventDays,
    );
  }
}

