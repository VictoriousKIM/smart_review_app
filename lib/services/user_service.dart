import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// 사용자 통계 및 레벨 계산 서비스
class UserService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  
  // 메모리 캐시
  final Map<String, Map<String, int>> _statsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// 사용자 통계 한 번에 가져오기 (최적화)
  /// 
  /// 반환값:
  /// - level: 사용자 레벨 (완료된 캠페인 수 / 10 + 1)
  /// - reviewCount: 리뷰 수 (review_submitted 또는 review_approved 상태)
  /// - completedCampaigns: 완료된 캠페인 수 (payment_completed 상태)
  Future<Map<String, int>> getUserStats(String userId, {bool forceRefresh = false}) async {
    // 캐시 확인
    if (!forceRefresh && _statsCache.containsKey(userId)) {
      final cacheTime = _cacheTimestamps[userId];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < _cacheDuration) {
        return _statsCache[userId]!;
      }
    }
    
    // 계산 및 캐싱
    final stats = await _calculateUserStats(userId);
    _statsCache[userId] = stats;
    _cacheTimestamps[userId] = DateTime.now();
    
    return stats;
  }
  
  Future<Map<String, int>> _calculateUserStats(String userId) async {
    try {
      // RPC 함수 호출 (Custom JWT 세션 지원)
      final response = await _supabase.rpc(
        'get_user_stats_safe',
        params: {
          'p_user_id': userId,
        },
      ) as Map<String, dynamic>;
      
      return {
        'level': (response['level'] as num).toInt(),
        'reviewCount': (response['reviewCount'] as num).toInt(),
        'completedCampaigns': (response['completedCampaigns'] as num).toInt(),
      };
    } catch (e) {
      print('사용자 통계 계산 실패: $e');
      return {
        'level': 1,
        'reviewCount': 0,
        'completedCampaigns': 0,
      };
    }
  }
  
  /// 사용자 레벨 계산
  /// 레벨 = 완료된 캠페인 수 / 10 + 1
  Future<int> getUserLevel(String userId) async {
    final stats = await getUserStats(userId);
    return stats['level'] ?? 1;
  }
  
  /// 사용자 리뷰 수 계산
  Future<int> getUserReviewCount(String userId) async {
    final stats = await getUserStats(userId);
    return stats['reviewCount'] ?? 0;
  }
  
  /// 캐시 무효화
  void invalidateCache(String userId) {
    _statsCache.remove(userId);
    _cacheTimestamps.remove(userId);
  }
  
  /// 모든 캐시 무효화
  void invalidateAllCache() {
    _statsCache.clear();
    _cacheTimestamps.clear();
  }
}

