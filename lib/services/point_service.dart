import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/point_models.dart';

class PointService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ===========================================
  // 1. 포인트 지갑 관련
  // ===========================================

  /// 사용자의 모든 지갑 조회
  static Future<List<UserWalletInfo>> getUserWallets(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_wallets',
        params: {'p_user_id': userId},
      );

      if (response is List) {
        return response.map((json) => UserWalletInfo.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting user wallets: $e');
      rethrow;
    }
  }

  /// 지갑 정보 조회
  static Future<PointWallet?> getWalletInfo(String walletId) async {
    try {
      final response = await _supabase.rpc(
        'get_wallet_info',
        params: {'p_wallet_id': walletId},
      );

      if (response is List && response.isNotEmpty) {
        return PointWallet.fromJson(response.first);
      }
      return null;
    } catch (e) {
      print('Error getting wallet info: $e');
      rethrow;
    }
  }

  // ===========================================
  // 2. 포인트 충전 관련
  // ===========================================

  /// 포인트 충전 요청
  static Future<String> requestPointCharge({
    required String userId,
    required int amount,
    required double cashAmount,
    String paymentMethod = '신용카드',
  }) async {
    try {
      final response = await _supabase.rpc(
        'request_point_charge',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_cash_amount': cashAmount,
          'p_payment_method': paymentMethod,
        },
      );

      return response.toString();
    } catch (e) {
      print('Error requesting point charge: $e');
      rethrow;
    }
  }

  /// 결제 완료 처리 (PG사 웹훅에서 호출)
  static Future<void> completePointCharge(String transactionId) async {
    try {
      await _supabase.rpc(
        'complete_point_charge',
        params: {'p_transaction_id': transactionId},
      );
    } catch (e) {
      print('Error completing point charge: $e');
      rethrow;
    }
  }

  // ===========================================
  // 3. 포인트 출금 관련
  // ===========================================

  /// 개인 지갑 출금 요청
  static Future<String> requestPersonalWithdrawal({
    required String userId,
    required int amount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'request_personal_withdrawal',
        params: {'p_user_id': userId, 'p_amount': amount},
      );

      return response.toString();
    } catch (e) {
      print('Error requesting personal withdrawal: $e');
      rethrow;
    }
  }

  /// 회사 지갑 출금 요청 (오너 전용)
  static Future<String> requestCompanyWithdrawal({
    required String userId,
    required int amount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'request_company_withdrawal',
        params: {'p_user_id': userId, 'p_amount': amount},
      );

      return response.toString();
    } catch (e) {
      print('Error requesting company withdrawal: $e');
      rethrow;
    }
  }

  /// 출금 승인
  static Future<void> approveWithdrawal({
    required String transactionId,
    required String approverId,
  }) async {
    try {
      await _supabase.rpc(
        'approve_withdrawal',
        params: {
          'p_transaction_id': transactionId,
          'p_approver_id': approverId,
        },
      );
    } catch (e) {
      print('Error approving withdrawal: $e');
      rethrow;
    }
  }

  // ===========================================
  // 4. 포인트 이동 관련 (오너 전용)
  // ===========================================

  /// 개인 → 회사 포인트 이동
  static Future<void> transferPersonalToCompany({
    required String userId,
    required int amount,
    String? description,
  }) async {
    try {
      await _supabase.rpc(
        'transfer_personal_to_company',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_description': description,
        },
      );
    } catch (e) {
      print('Error transferring personal to company: $e');
      rethrow;
    }
  }

  /// 회사 → 개인 포인트 이동
  static Future<void> transferCompanyToPersonal({
    required String userId,
    required int amount,
    String? description,
  }) async {
    try {
      await _supabase.rpc(
        'transfer_company_to_personal',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_description': description,
        },
      );
    } catch (e) {
      print('Error transferring company to personal: $e');
      rethrow;
    }
  }

  /// 포인트 이동 내역 조회
  static Future<List<TransferHistory>> getTransferHistory(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_transfer_history',
        params: {'p_user_id': userId},
      );

      if (response is List) {
        return response.map((json) => TransferHistory.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting transfer history: $e');
      rethrow;
    }
  }

  // ===========================================
  // 5. 포인트 로그 관련
  // ===========================================

  /// 지갑별 포인트 로그 조회
  static Future<List<PointLog>> getWalletLogs({
    required String walletId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_wallet_logs',
        params: {'p_wallet_id': walletId, 'p_limit': limit, 'p_offset': offset},
      );

      if (response is List) {
        return response.map((json) => PointLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting wallet logs: $e');
      rethrow;
    }
  }

  // ===========================================
  // 6. 캠페인 관련
  // ===========================================

  /// 캠페인 생성
  static Future<String> createCampaign({
    required String companyId,
    required String userId,
    required String title,
    required int rewardPerReview,
    required int maxReviews,
    String? description,
    String campaignType = 'reviewer',
    int productPrice = 0,
    String platform = 'coupang',
    String? platformLogoUrl,
    String? productImageUrl,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_campaign',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
          'p_title': title,
          'p_reward_per_review': rewardPerReview,
          'p_max_reviews': maxReviews,
          'p_description': description,
          'p_campaign_type': campaignType,
          'p_product_price': productPrice,
          'p_platform': platform,
          'p_platform_logo_url': platformLogoUrl,
          'p_product_image_url': productImageUrl,
          'p_start_date': startDate?.toIso8601String(),
          'p_end_date': endDate?.toIso8601String(),
        },
      );

      return response.toString();
    } catch (e) {
      print('Error creating campaign: $e');
      rethrow;
    }
  }

  /// 리뷰 보상 지급
  static Future<void> rewardReview({
    required String campaignId,
    required String reviewerId,
    Map<String, dynamic>? reviewData,
  }) async {
    try {
      await _supabase.rpc(
        'reward_review',
        params: {
          'p_campaign_id': campaignId,
          'p_reviewer_id': reviewerId,
          'p_review_data': reviewData ?? {},
        },
      );
    } catch (e) {
      print('Error rewarding review: $e');
      rethrow;
    }
  }

  // ===========================================
  // 7. 관리자 기능
  // ===========================================

  /// 관리자 권한 확인
  static Future<bool> isAdmin(String userId) async {
    try {
      final response = await _supabase.rpc(
        'is_admin',
        params: {'p_user_id': userId},
      );
      return response == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// 시스템 전체 현황 조회 (관리자 전용)
  static Future<SystemStats?> getSystemOverview(String adminId) async {
    try {
      final response = await _supabase.rpc(
        'admin_get_system_overview',
        params: {'p_admin_id': adminId},
      );

      if (response is List && response.isNotEmpty) {
        return SystemStats.fromJson(response.first);
      }
      return null;
    } catch (e) {
      print('Error getting system overview: $e');
      rethrow;
    }
  }

  /// 긴급 포인트 조정 (관리자 전용)
  static Future<void> adminAdjustPoints({
    required String adminId,
    required String walletId,
    required int amount,
    required String reason,
  }) async {
    try {
      await _supabase.rpc(
        'admin_adjust_points',
        params: {
          'p_admin_id': adminId,
          'p_wallet_id': walletId,
          'p_amount': amount,
          'p_reason': reason,
        },
      );
    } catch (e) {
      print('Error adjusting points: $e');
      rethrow;
    }
  }

  /// 사용자 역할 변경 (관리자 전용)
  static Future<void> adminChangeUserRole({
    required String adminId,
    required String userId,
    required String newRole,
  }) async {
    try {
      await _supabase.rpc(
        'admin_change_user_role',
        params: {
          'p_admin_id': adminId,
          'p_user_id': userId,
          'p_new_role': newRole,
        },
      );
    } catch (e) {
      print('Error changing user role: $e');
      rethrow;
    }
  }

  // ===========================================
  // 8. 검증 및 감사
  // ===========================================

  /// 지갑 포인트 검증
  static Future<PointVerificationResult?> verifyWalletPoints(
    String walletId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'verify_wallet_points',
        params: {'p_wallet_id': walletId},
      );

      if (response is List && response.isNotEmpty) {
        return PointVerificationResult.fromJson(response.first);
      }
      return null;
    } catch (e) {
      print('Error verifying wallet points: $e');
      rethrow;
    }
  }

  /// 전체 시스템 포인트 검증
  static Future<List<Map<String, dynamic>>> verifyAllPoints() async {
    try {
      final response = await _supabase.rpc('verify_all_points');

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error verifying all points: $e');
      rethrow;
    }
  }

  // ===========================================
  // 9. 통계 및 리포트
  // ===========================================

  /// 일일 포인트 거래 통계
  static Future<Map<String, dynamic>?> getDailyPointStats([
    DateTime? date,
  ]) async {
    try {
      final response = await _supabase.rpc(
        'get_daily_point_stats',
        params: {
          'p_date': (date ?? DateTime.now()).toIso8601String().split('T')[0],
        },
      );

      if (response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      print('Error getting daily point stats: $e');
      rethrow;
    }
  }

  /// 월별 포인트 거래 통계
  static Future<Map<String, dynamic>?> getMonthlyPointStats({
    int? year,
    int? month,
  }) async {
    try {
      final now = DateTime.now();
      final response = await _supabase.rpc(
        'get_monthly_point_stats',
        params: {'p_year': year ?? now.year, 'p_month': month ?? now.month},
      );

      if (response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      print('Error getting monthly point stats: $e');
      rethrow;
    }
  }
}
