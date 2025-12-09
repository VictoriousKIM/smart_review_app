import '../models/wallet_models.dart';
import '../models/point_transfer.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

/// 지갑 및 포인트 관리 서비스 (완전 분리 버전)
class WalletService {
  static final _supabase = SupabaseConfig.client;

  // ==================== 지갑 조회 ====================

  /// 개인 지갑 조회 (RPC 사용)
  static Future<UserWallet?> getUserWallet() async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return null;
      }

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await _supabase.rpc(
                'get_user_wallet_current_safe',
                params: {'p_user_id': userId},
              )
              as Map<String, dynamic>?;

      if (response == null) {
        print('ℹ️ 개인 지갑이 없습니다');
        return null;
      }

      final wallet = UserWallet.fromJson({
        'wallet_id': response['id'],
        'id': response['id'],
        'user_id': response['user_id'],
        'current_points': response['current_points'],
        'withdraw_bank_name': response['withdraw_bank_name'],
        'withdraw_account_number': response['withdraw_account_number'],
        'withdraw_account_holder': response['withdraw_account_holder'],
        'created_at': response['created_at'],
        'updated_at': response['updated_at'],
      });
      print('✅ 개인 지갑 조회 성공: ${wallet.currentPoints}P');
      return wallet;
    } catch (e) {
      print('❌ 개인 지갑 조회 실패: $e');
      return null;
    }
  }

  /// 회사 지갑 목록 조회 (RPC 사용)
  static Future<List<CompanyWallet>> getCompanyWallets() async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await _supabase.rpc(
                'get_company_wallets_safe',
                params: {'p_user_id': userId},
              )
              as List;

      if (response.isEmpty) {
        return [];
      }

      final wallets = response
          .map(
            (walletData) =>
                CompanyWallet.fromJson(walletData as Map<String, dynamic>),
          )
          .toList();

      print('✅ 회사 지갑 조회 성공: ${wallets.length}개');
      return wallets;
    } catch (e) {
      print('❌ 회사 지갑 조회 실패: $e');
      return [];
    }
  }

  /// 특정 회사의 지갑 조회 (RPC 사용)
  static Future<CompanyWallet?> getCompanyWalletByCompanyId(
    String companyId,
  ) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return null;
      }

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await _supabase.rpc(
                'get_company_wallet_by_company_id_safe',
                params: {'p_company_id': companyId, 'p_user_id': userId},
              )
              as Map<String, dynamic>?;

      if (response == null) {
        return null;
      }

      return CompanyWallet.fromJson(response);
    } catch (e) {
      print('❌ 회사 지갑 조회 실패: $e');
      return null;
    }
  }

  // ==================== 포인트 내역 조회 ====================

  /// 개인 포인트 내역 조회 (통합: 캠페인 + 현금 거래)
  static Future<List<Map<String, dynamic>>> getUserPointHistoryUnified({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      final response =
          await _supabase.rpc(
                'get_user_point_history_unified',
                params: {
                  'p_user_id': userId,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final logs = response.map((e) => e as Map<String, dynamic>).toList();

      print('✅ 개인 포인트 내역 통합 조회 성공: ${logs.length}건');
      return logs;
    } catch (e) {
      print('❌ 개인 포인트 내역 통합 조회 실패: $e');
      return [];
    }
  }

  /// 개인 포인트 내역 조회 (point_transactions 테이블, RPC 사용)
  static Future<List<UserPointLog>> getUserPointHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await _supabase.rpc(
                'get_user_point_history_safe',
                params: {
                  'p_user_id': userId,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

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

  /// 회사 포인트 내역 조회 (통합: 캠페인 + 현금 거래)
  static Future<List<Map<String, dynamic>>> getCompanyPointHistoryUnified({
    required String companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await _supabase.rpc(
                'get_company_point_history_unified',
                params: {
                  'p_company_id': companyId,
                  'p_user_id': userId,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final logs = response.map((e) => e as Map<String, dynamic>).toList();

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

  /// 회사 포인트 내역 조회 (기존 메서드 - 호환성 유지)
  static Future<List<CompanyPointLog>> getCompanyPointHistory({
    required String companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response =
          await _supabase.rpc(
                'get_company_point_history',
                params: {
                  'p_company_id': companyId,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

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
          final monthKey =
              '${log.createdAt.year}-${log.createdAt.month.toString().padLeft(2, '0')}';
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
    required int campaignReward,
    required int maxParticipants,
  }) async {
    try {
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) return false;

      final requiredPoints = campaignReward * maxParticipants;
      return wallet.currentPoints >= requiredPoints;
    } catch (e) {
      print('❌ 캠페인 생성 가능 여부 확인 실패: $e');
      return false;
    }
  }

  /// 필요한 포인트 계산
  static int calculateRequiredPoints({
    required int campaignReward,
    required int maxParticipants,
  }) {
    return campaignReward * maxParticipants;
  }

  /// 부족한 포인트 계산
  static Future<int> calculateShortage({
    required String companyId,
    required int campaignReward,
    required int maxParticipants,
  }) async {
    try {
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) return campaignReward * maxParticipants;

      final required = calculateRequiredPoints(
        campaignReward: campaignReward,
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

  // ==================== 계좌정보 관리 ====================

  /// 개인 지갑 계좌정보 업데이트
  static Future<void> updateUserWalletAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 지갑 조회
      final wallet = await getUserWallet();
      if (wallet == null) {
        throw Exception('지갑을 찾을 수 없습니다');
      }

      // RPC 함수 호출 (fallback 제거)
      await _supabase.rpc(
        'update_user_wallet_account',
        params: {
          'p_wallet_id': wallet.id,
          'p_bank_name': bankName,
          'p_account_number': accountNumber,
          'p_account_holder': accountHolder,
        },
      );
      print('✅ 개인 지갑 계좌정보 업데이트 성공 (RPC)');
    } catch (e) {
      print('❌ 개인 지갑 계좌정보 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 회사 지갑 계좌정보 업데이트 (오너 전용)
  static Future<void> updateCompanyWalletAccount({
    required String companyId,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 지갑 조회
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) {
        throw Exception('회사 지갑을 찾을 수 없습니다');
      }

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행, fallback 제거)
      await _supabase.rpc(
        'update_company_wallet_account',
        params: {
          'p_wallet_id': wallet.id,
          'p_company_id': companyId,
          'p_bank_name': bankName,
          'p_account_number': accountNumber,
          'p_account_holder': accountHolder,
        },
      );
      print('✅ 회사 지갑 계좌정보 업데이트 성공 (RPC)');
    } catch (e) {
      print('❌ 회사 지갑 계좌정보 업데이트 실패: $e');
      rethrow;
    }
  }

  // ==================== 포인트 거래 생성 ====================

  /// 포인트 지갑 간 이동 (회사 소유자만 가능, point_transfers 테이블 사용)
  static Future<Map<String, dynamic>> transferPointsBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    String? description,
  }) async {
    try {
      final response =
          await _supabase.rpc(
                'transfer_points_between_wallets',
                params: {
                  'p_from_wallet_id': fromWalletId,
                  'p_to_wallet_id': toWalletId,
                  'p_amount': amount,
                  'p_description': description,
                },
              )
              as Map<String, dynamic>;

      print('✅ 포인트 이동 성공: $amount P');
      return response;
    } catch (e) {
      print('❌ 포인트 이동 실패: $e');
      rethrow;
    }
  }

  /// 포인트 이동 내역 조회 (point_transfers 전용)
  static Future<List<PointTransfer>> getUserTransfers({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      final response =
          await _supabase.rpc(
                'get_user_transfers',
                params: {
                  'p_user_id': userId,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final transfers = response
          .map((e) => PointTransfer.fromJson(e as Map<String, dynamic>))
          .toList();

      print('✅ 포인트 이동 내역 조회 성공: ${transfers.length}건');
      return transfers;
    } catch (e) {
      print('❌ 포인트 이동 내역 조회 실패: $e');
      return [];
    }
  }

  /// 캠페인 거래 생성
  static Future<String> createPointTransaction({
    required String walletId,
    required String transactionType, // 'earn' or 'spend'
    required int amount,
    String? campaignId,
    String? relatedEntityType,
    String? relatedEntityId,
    String? description,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_point_transaction',
        params: {
          'p_wallet_id': walletId,
          'p_transaction_type': transactionType,
          'p_amount': amount,
          'p_campaign_id': campaignId,
          'p_related_entity_type': relatedEntityType,
          'p_related_entity_id': relatedEntityId,
          'p_description': description,
        },
      );

      print('✅ 캠페인 거래 생성 성공: $response');
      return response as String;
    } catch (e) {
      print('❌ 캠페인 거래 생성 실패: $e');
      rethrow;
    }
  }

  /// 현금 거래 생성
  static Future<String> createPointCashTransaction({
    required String walletId,
    required String transactionType, // 'deposit' or 'withdraw'
    required int pointAmount,
    required int cashAmount,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? description,
    // 영수증 관련 파라미터
    String? receiptType, // 'cash_receipt', 'tax_invoice', 'none'
    String? cashReceiptRecipientType, // 'individual', 'business'
    String? cashReceiptName,
    String? cashReceiptPhone,
    String? cashReceiptBusinessName,
    String? cashReceiptBusinessNumber,
    String? taxInvoiceRepresentative,
    String? taxInvoiceCompanyName,
    String? taxInvoiceBusinessNumber,
    String? taxInvoiceEmail,
    String? taxInvoicePostalCode,
    String? taxInvoiceAddress,
    String? taxInvoiceDetailAddress,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_cash_transaction',
        params: {
          'p_wallet_id': walletId,
          'p_transaction_type': transactionType,
          'p_point_amount': pointAmount,
          'p_cash_amount': cashAmount,
          'p_payment_method': paymentMethod,
          'p_bank_name': bankName,
          'p_account_number': accountNumber,
          'p_account_holder': accountHolder,
          'p_description': description,
          // 영수증 관련 파라미터
          'p_receipt_type': receiptType,
          'p_cash_receipt_recipient_type': cashReceiptRecipientType,
          'p_cash_receipt_name': cashReceiptName,
          'p_cash_receipt_phone': cashReceiptPhone,
          'p_cash_receipt_business_name': cashReceiptBusinessName,
          'p_cash_receipt_business_number': cashReceiptBusinessNumber,
          'p_tax_invoice_representative': taxInvoiceRepresentative,
          'p_tax_invoice_company_name': taxInvoiceCompanyName,
          'p_tax_invoice_business_number': taxInvoiceBusinessNumber,
          'p_tax_invoice_email': taxInvoiceEmail,
          'p_tax_invoice_postal_code': taxInvoicePostalCode,
          'p_tax_invoice_address': taxInvoiceAddress,
          'p_tax_invoice_detail_address': taxInvoiceDetailAddress,
        },
      );

      print('✅ 현금 거래 생성 성공: $response');
      return response as String;
    } catch (e) {
      print('❌ 현금 거래 생성 실패: $e');
      rethrow;
    }
  }

  /// 현금 거래 상태 업데이트 (Admin 전용)
  static Future<bool> updatePointCashTransactionStatus({
    required String transactionId,
    required String status, // 'approved', 'rejected'
    String? rejectionReason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_cash_transaction_status',
        params: {
          'p_transaction_id': transactionId,
          'p_status': status,
          'p_rejection_reason': rejectionReason,
        },
      );

      print('✅ 현금 거래 상태 업데이트 성공: $status');
      return response as bool;
    } catch (e) {
      print('❌ 현금 거래 상태 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 대기중인 현금 거래 목록 조회 (Admin 전용)
  static Future<List<Map<String, dynamic>>> getPendingCashTransactions({
    String? status, // 'pending', 'approved', 'rejected', 'cancelled'
    String? transactionType, // 'deposit', 'withdraw'
    String? userType, // 'advertiser', 'reviewer'
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response =
          await _supabase.rpc(
                'get_pending_cash_transactions',
                params: {
                  'p_status': status,
                  'p_transaction_type': transactionType,
                  'p_user_type': userType,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final transactions = response
          .map((e) => e as Map<String, dynamic>)
          .toList();

      print('✅ 대기중인 현금 거래 목록 조회 성공: ${transactions.length}건');
      return transactions;
    } catch (e) {
      print('❌ 대기중인 현금 거래 목록 조회 실패: $e');
      if (e.toString().contains('Unauthorized')) {
        throw Exception('관리자 권한이 필요합니다');
      }
      rethrow;
    }
  }

  /// 현금 거래 취소 (pending 상태만 가능)
  static Future<bool> cancelCashTransaction({
    required String transactionId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'cancel_cash_transaction',
        params: {'p_transaction_id': transactionId},
      );

      print('✅ 현금 거래 취소 성공');
      return response as bool;
    } catch (e) {
      print('❌ 현금 거래 취소 실패: $e');
      rethrow;
    }
  }
}
