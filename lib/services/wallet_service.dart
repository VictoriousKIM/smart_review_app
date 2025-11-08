import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet_models.dart';
import '../config/supabase_config.dart';

/// 지갑 및 포인트 관리 서비스 (완전 분리 버전)
class WalletService {
  static final _supabase = SupabaseConfig.client;

  // ==================== 지갑 조회 ====================

  /// 개인 지갑 조회
  static Future<UserWallet?> getUserWallet() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return null;
      }

      final response = await _supabase.rpc(
        'get_user_wallet',
        params: {'p_user_id': userId},
      ) as List;

      if (response.isEmpty) {
        print('ℹ️ 개인 지갑이 없습니다');
        return null;
      }

      final wallet = UserWallet.fromJson(response.first as Map<String, dynamic>);
      print('✅ 개인 지갑 조회 성공: ${wallet.currentPoints}P');
      return wallet;
    } catch (e) {
      print('❌ 개인 지갑 조회 실패: $e');
      return null;
    }
  }

  /// 회사 지갑 목록 조회
  static Future<List<CompanyWallet>> getCompanyWallets() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      final response = await _supabase.rpc(
        'get_user_company_wallets',
        params: {'p_user_id': userId},
      ) as List;

      final wallets = response
          .map((e) => CompanyWallet.fromJson(e as Map<String, dynamic>))
          .toList();

      print('✅ 회사 지갑 조회 성공: ${wallets.length}개');
      return wallets;
    } catch (e) {
      print('❌ 회사 지갑 조회 실패: $e');
      return [];
    }
  }

  /// 특정 회사의 지갑 조회
  static Future<CompanyWallet?> getCompanyWalletByCompanyId(
    String companyId,
  ) async {
    try {
      final wallets = await getCompanyWallets();
      return wallets.firstWhere(
        (w) => w.companyId == companyId,
        orElse: () => throw Exception('해당 회사의 지갑을 찾을 수 없습니다'),
      );
    } catch (e) {
      print('❌ 회사 지갑 조회 실패: $e');
      return null;
    }
  }

  // ==================== 포인트 내역 조회 ====================

  /// 개인 포인트 내역 조회
  static Future<List<UserPointLog>> getUserPointHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      final response = await _supabase.rpc(
        'get_user_point_history',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset,
        },
      ) as List;

      final logs = response
          .map((e) => UserPointLog.fromJson(e as Map<String, dynamic>))
          .toList();

      print('✅ 개인 포인트 내역 조회 성공: ${logs.length}건');
      return logs;
    } catch (e) {
      print('❌ 개인 포인트 내역 조회 실패: $e');
      return [];
    }
  }

  /// 회사 포인트 내역 조회
  static Future<List<CompanyPointLog>> getCompanyPointHistory({
    required String companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_company_point_history',
        params: {
          'p_company_id': companyId,
          'p_limit': limit,
          'p_offset': offset,
        },
      ) as List;

      final logs = response
          .map((e) => CompanyPointLog.fromJson(e as Map<String, dynamic>))
          .toList();

      print('✅ 회사 포인트 내역 조회 성공: ${logs.length}건');
      return logs;
    } catch (e) {
      print('❌ 회사 포인트 내역 조회 실패: $e');
      
      // 권한 없음 에러 처리
      if (e.toString().contains('Unauthorized')) {
        throw Exception('회사 포인트 내역을 조회할 권한이 없습니다');
      }
      
      return [];
    }
  }

  // ==================== 포인트 통계 ====================

  /// 개인 포인트 월별 통계
  static Future<Map<String, int>> getUserMonthlyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final logs = await getUserPointHistory(limit: 1000);
      
      final stats = <String, int>{};
      for (final log in logs) {
        if (log.createdAt.isAfter(startDate) && 
            log.createdAt.isBefore(endDate)) {
          final monthKey = '${log.createdAt.year}-${log.createdAt.month.toString().padLeft(2, '0')}';
          stats[monthKey] = (stats[monthKey] ?? 0) + log.amount;
        }
      }
      
      return stats;
    } catch (e) {
      print('❌ 월별 통계 조회 실패: $e');
      return {};
    }
  }

  /// 회사 포인트 사용자별 통계
  static Future<Map<String, int>> getCompanyUserStats({
    required String companyId,
  }) async {
    try {
      final logs = await getCompanyPointHistory(
        companyId: companyId,
        limit: 1000,
      );
      
      final stats = <String, int>{};
      for (final log in logs) {
        if (log.createdByUserName != null) {
          stats[log.createdByUserName!] = 
              (stats[log.createdByUserName!] ?? 0) + log.amount.abs();
        }
      }
      
      return stats;
    } catch (e) {
      print('❌ 사용자별 통계 조회 실패: $e');
      return {};
    }
  }

  // ==================== 포인트 검증 ====================

  /// 캠페인 생성 가능 여부 확인
  static Future<bool> canCreateCampaign({
    required String companyId,
    required int reviewReward,
    required int maxParticipants,
  }) async {
    try {
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) return false;

      final requiredPoints = reviewReward * maxParticipants;
      return wallet.currentPoints >= requiredPoints;
    } catch (e) {
      print('❌ 캠페인 생성 가능 여부 확인 실패: $e');
      return false;
    }
  }

  /// 필요한 포인트 계산
  static int calculateRequiredPoints({
    required int reviewReward,
    required int maxParticipants,
  }) {
    return reviewReward * maxParticipants;
  }

  /// 부족한 포인트 계산
  static Future<int> calculateShortage({
    required String companyId,
    required int reviewReward,
    required int maxParticipants,
  }) async {
    try {
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) return reviewReward * maxParticipants;

      final required = calculateRequiredPoints(
        reviewReward: reviewReward,
        maxParticipants: maxParticipants,
      );
      
      final shortage = required - wallet.currentPoints;
      return shortage > 0 ? shortage : 0;
    } catch (e) {
      print('❌ 부족 포인트 계산 실패: $e');
      return 0;
    }
  }

  // ==================== 포인트 포맷팅 ====================

  /// 포인트 포맷팅 (천단위 콤마)
  static String formatPoints(int points) {
    return points.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// 포인트 변화량 포맷팅 (+/- 표시)
  static String formatPointsChange(int points) {
    if (points > 0) {
      return '+${formatPoints(points)} P';
    } else {
      return '${formatPoints(points)} P';
    }
  }
}

