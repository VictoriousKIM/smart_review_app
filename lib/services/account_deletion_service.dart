import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ===========================================
  // 1. 계정 삭제 요청
  // ===========================================

  /// 계정 삭제 요청 (사용자)
  static Future<void> requestAccountDeletion({required String reason}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      await _supabase.rpc(
        'request_account_deletion',
        params: {'p_user_id': user.id, 'p_reason': reason},
      );
    } catch (e) {
      print('Error requesting account deletion: $e');
      rethrow;
    }
  }

  // ===========================================
  // 2. 계정 삭제 전 확인
  // ===========================================

  /// 계정 삭제 가능 여부 확인
  static Future<Map<String, dynamic>> checkDeletionEligibility() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // 사용자 정보 조회
      final userResponse = await _supabase
          .from('users')
          .select('user_type')
          .eq('id', user.id)
          .single();

      // 사용자의 회사 정보 조회 (status='active'만)
      final companyResponse = await _supabase
          .from('company_users')
          .select('company_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      final companyId = companyResponse?['company_id'];

      // 삭제 요청 상태 확인 (deleted_users 테이블에서)
      final deletionRequestResponse = await _supabase
          .from('deleted_users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      // 포인트 정보 조회
      final walletsResponse = await _supabase
          .from('point_wallets')
          .select('wallet_type, current_points')
          .or('user_id.eq.${user.id},user_id.eq.${companyId ?? ''}');

      // 활성 캠페인 조회
      final campaignsResponse = await _supabase
          .from('campaigns')
          .select('id, title, status')
          .eq('user_id', user.id)
          .eq('status', 'active');

      // 회사 오너 수 확인 (회사 소유자인 경우)
      int otherOwnersCount = 0;
      if (companyId != null) {
        final deletedUserIds = await _getDeletedUserIds();

        // company_users 테이블에서 해당 회사의 오너들 조회 (status='active'만)
        final companyOwnersResponse = await _supabase
            .from('company_users')
            .select('user_id')
            .eq('company_id', companyId)
            .eq('company_role', 'owner')
            .eq('status', 'active');

        // users 테이블에서 다른 오너 정보 조회 (자신 제외)
        final ownerIds = companyOwnersResponse
            .map((owner) => owner['user_id'])
            .where((id) => id != user.id)
            .toList();
        
        final ownersResponse = await _supabase
            .from('users')
            .select('id')
            .inFilter('id', ownerIds);

        // 삭제된 사용자들을 제외
        final filteredOwners = ownersResponse
            .where((owner) => !deletedUserIds.contains(owner['id']))
            .toList();

        otherOwnersCount = filteredOwners.length;
      }

      // 포인트 계산
      int personalPoints = 0;
      int companyPoints = 0;
      for (final wallet in walletsResponse) {
        if (wallet['wallet_type'] == 'reviewer') {
          personalPoints = wallet['current_points'] ?? 0;
        } else if (wallet['wallet_type'] == 'company') {
          companyPoints = wallet['current_points'] ?? 0;
        }
      }

      return {
        'canDelete': true,
        'hasDeletionRequest': deletionRequestResponse != null,
        'userType': userResponse['user_type'],
        'companyId': companyId,
        'personalPoints': personalPoints,
        'companyPoints': companyPoints,
        'activeCampaigns': campaignsResponse.length,
        'otherOwnersCount': otherOwnersCount,
        'warnings': <String>[],
        'errors': <String>[],
      };
    } catch (e) {
      print('Error checking deletion eligibility: $e');
      return {
        'canDelete': false,
        'errors': ['삭제 가능 여부를 확인할 수 없습니다: $e'],
      };
    }
  }

  // ===========================================
  // 3. 계정 삭제 전 데이터 백업
  // ===========================================

  /// 계정 삭제 전 사용자 데이터 백업
  static Future<Map<String, dynamic>> backupUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // 사용자 기본 정보
      final userData = await _supabase
          .from('users')
          .select('*')
          .eq('id', user.id)
          .single();

      // 포인트 지갑 정보
      final walletsData = await _supabase
          .from('point_wallets')
          .select('*')
          .eq('user_id', user.id);

      // 포인트 로그
      final pointLogsData = await _supabase
          .from('point_logs')
          .select('*')
          .inFilter('wallet_id', walletsData.map((w) => w['id']).toList());

      // 캠페인 정보
      final campaignsData = await _supabase
          .from('campaigns')
          .select('*')
          .eq('user_id', user.id);

      // 캠페인 로그
      final campaignLogsData = await _supabase
          .from('campaign_action_logs')
          .select('*')
          .eq('user_id', user.id);

      // 알림 정보
      final notificationsData = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id);

      return {
        'user': userData,
        'wallets': walletsData,
        'pointLogs': pointLogsData,
        'campaigns': campaignsData,
        'campaignLogs': campaignLogsData,
        'notifications': notificationsData,
        'backupDate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error backing up user data: $e');
      rethrow;
    }
  }

  // ===========================================
  // 4. 계정 삭제 상태 확인
  // ===========================================

  /// 계정 삭제 상태 확인
  static Future<bool> isAccountDeleted() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _supabase
          .from('deleted_users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking account deletion status: $e');
      return false;
    }
  }

  /// 삭제 요청 상태 확인
  static Future<bool> hasDeletionRequest() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _supabase
          .from('deleted_users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking deletion request status: $e');
      return false;
    }
  }

  // ===========================================
  // 5. 계정 삭제 취소
  // ===========================================

  /// 계정 삭제 요청 취소
  static Future<void> cancelDeletionRequest() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // deleted_users 테이블에서 해당 사용자 삭제
      await _supabase.from('deleted_users').delete().eq('id', user.id);
    } catch (e) {
      print('Error canceling deletion request: $e');
      rethrow;
    }
  }

  // ===========================================
  // 헬퍼 메서드
  // ===========================================

  /// 삭제된 사용자 ID 목록 가져오기
  static Future<List<String>> _getDeletedUserIds() async {
    try {
      final response = await _supabase.from('deleted_users').select('id');

      return response.map((user) => user['id'] as String).toList();
    } catch (e) {
      print('Error getting deleted user IDs: $e');
      return [];
    }
  }
}
