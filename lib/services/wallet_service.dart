import '../models/wallet_models.dart';
import '../models/point_transfer.dart';
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

      // wallets 테이블에서 직접 조회
      final response = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .isFilter('company_id', null)
          .maybeSingle();

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

  /// 회사 지갑 목록 조회
  static Future<List<CompanyWallet>> getCompanyWallets() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ 로그인되지 않음');
        return [];
      }

      // company_users를 통해 접근 가능한 회사 조회
      final companyUsers = await _supabase
          .from('company_users')
          .select('company_id, company_role, status')
          .eq('user_id', userId)
          .eq('status', 'active')
          .inFilter('company_role', ['owner', 'manager']);

      if (companyUsers.isEmpty) {
        return [];
      }

      final companyIds = companyUsers
          .map((cu) => cu['company_id'] as String)
          .toList();

      // wallets 테이블에서 회사 지갑 조회 (계좌정보 포함)
      final walletsResponse = await _supabase
          .from('wallets')
          .select('''
            id,
            company_id,
            current_points,
            withdraw_bank_name,
            withdraw_account_number,
            withdraw_account_holder,
            companies!inner(id, business_name)
          ''')
          .inFilter('company_id', companyIds);

      // company_users 정보와 조인하여 최종 결과 생성
      final wallets = <CompanyWallet>[];
      for (final walletData in walletsResponse) {
        final companyId = walletData['company_id'] as String;
        final companyUser = companyUsers.firstWhere(
          (cu) => cu['company_id'] == companyId,
        );
        final company = walletData['companies'] as Map<String, dynamic>;

        wallets.add(
          CompanyWallet.fromJson({
            'wallet_id': walletData['id'],
            'id': walletData['id'],
            'company_id': companyId,
            'company_name': company['business_name'],
            'current_points': walletData['current_points'],
            'user_role': companyUser['company_role'],
            'status': companyUser['status'],
            'withdraw_bank_name': walletData['withdraw_bank_name'],
            'withdraw_account_number': walletData['withdraw_account_number'],
            'withdraw_account_holder': walletData['withdraw_account_holder'],
          }),
        );
      }

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

  /// 개인 포인트 내역 조회 (point_transactions 테이블)
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

      // 지갑 조회
      final wallet = await getUserWallet();
      if (wallet == null) {
        print('ℹ️ 개인 지갑이 없습니다');
        return [];
      }

      // point_transactions 테이블에서 직접 조회
      final response = await _supabase
          .from('point_transactions')
          .select('*')
          .eq('wallet_id', wallet.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final logs = response
          .map((e) => UserPointLog.fromJson(e))
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

  // ==================== 계좌정보 관리 ====================

  /// 개인 지갑 계좌정보 업데이트
  static Future<void> updateUserWalletAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 지갑 조회
      final wallet = await getUserWallet();
      if (wallet == null) {
        throw Exception('지갑을 찾을 수 없습니다');
      }

      // RPC 함수 시도, 실패 시 직접 업데이트
      bool rpcSuccess = false;
      try {
        print('🔄 RPC 함수 호출 시도...');
        await _supabase.rpc(
          'update_user_wallet_account',
          params: {
            'p_wallet_id': wallet.id,
            'p_bank_name': bankName,
            'p_account_number': accountNumber,
            'p_account_holder': accountHolder,
          },
        );
        rpcSuccess = true;
        print('✅ 개인 지갑 계좌정보 업데이트 성공 (RPC)');
      } catch (rpcError) {
        // RPC 함수가 없거나 실패하면 직접 업데이트
        print('⚠️ RPC 함수 실패, 직접 업데이트 시도: $rpcError');
        print('⚠️ RPC 에러 타입: ${rpcError.runtimeType}');
        rpcSuccess = false;
      }

      if (!rpcSuccess) {
        try {
          print('🔄 직접 업데이트 시도...');
          await _supabase
              .from('wallets')
              .update({
                'withdraw_bank_name': bankName,
                'withdraw_account_number': accountNumber,
                'withdraw_account_holder': accountHolder,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', wallet.id)
              .eq('user_id', userId);
          print('✅ 개인 지갑 계좌정보 업데이트 성공 (직접 업데이트)');
        } catch (updateError) {
          print('❌ 직접 업데이트도 실패: $updateError');
          print('❌ 직접 업데이트 에러 타입: ${updateError.runtimeType}');
          rethrow;
        }
      }
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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 지갑 조회
      final wallet = await getCompanyWalletByCompanyId(companyId);
      if (wallet == null) {
        throw Exception('회사 지갑을 찾을 수 없습니다');
      }

      // 권한 확인: owner만 가능
      final companyUsers = await _supabase
          .from('company_users')
          .select('company_role')
          .eq('company_id', companyId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .eq('company_role', 'owner')
          .maybeSingle();

      if (companyUsers == null) {
        throw Exception('계좌정보는 회사 소유자만 수정할 수 있습니다');
      }

      // RPC 함수 시도, 실패 시 직접 업데이트
      bool rpcSuccess = false;
      try {
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
        rpcSuccess = true;
        print('✅ 회사 지갑 계좌정보 업데이트 성공 (RPC)');
      } catch (rpcError) {
        // RPC 함수가 없거나 실패하면 직접 업데이트
        print('⚠️ RPC 함수 실패, 직접 업데이트 시도: $rpcError');
        rpcSuccess = false;
      }

      if (!rpcSuccess) {
        try {
          await _supabase
              .from('wallets')
              .update({
                'withdraw_bank_name': bankName,
                'withdraw_account_number': accountNumber,
                'withdraw_account_holder': accountHolder,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', wallet.id)
              .eq('company_id', companyId);
          print('✅ 회사 지갑 계좌정보 업데이트 성공 (직접 업데이트)');
        } catch (updateError) {
          print('❌ 직접 업데이트도 실패: $updateError');
          rethrow;
        }
      }
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
      final userId = _supabase.auth.currentUser?.id;
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
    required int amount,
    double? cashAmount,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? description,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_point_cash_transaction',
        params: {
          'p_wallet_id': walletId,
          'p_transaction_type': transactionType,
          'p_amount': amount,
          'p_cash_amount': cashAmount,
          'p_payment_method': paymentMethod,
          'p_bank_name': bankName,
          'p_account_number': accountNumber,
          'p_account_holder': accountHolder,
          'p_description': description,
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
    required String status, // 'approved', 'rejected', 'completed'
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
}
