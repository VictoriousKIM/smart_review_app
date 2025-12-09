import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AccountDeletionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ===========================================
  // 1. 계정 삭제 요청
  // ===========================================

  /// 계정 삭제 요청 (사용자)
  static Future<void> requestAccountDeletion({required String reason}) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      await _supabase.rpc(
        'request_account_deletion',
        params: {'p_user_id': userId, 'p_reason': reason},
      );
    } catch (e) {
      debugPrint('Error requesting account deletion: $e');
      rethrow;
    }
  }

  // ===========================================
  // 2. 계정 삭제 전 확인
  // ===========================================

  /// 계정 삭제 가능 여부 확인 (RPC 사용)
  static Future<Map<String, dynamic>> checkDeletionEligibility() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // RPC 함수 호출
      final response =
          await _supabase.rpc('check_deletion_eligibility_safe')
              as Map<String, dynamic>;

      return response;
    } catch (e) {
      debugPrint('Error checking deletion eligibility: $e');
      return {
        'canDelete': false,
        'errors': ['삭제 가능 여부를 확인할 수 없습니다: $e'],
      };
    }
  }

  // ===========================================
  // 3. 계정 삭제 전 데이터 백업
  // ===========================================

  /// 계정 삭제 전 사용자 데이터 백업 (RPC 사용)
  static Future<Map<String, dynamic>> backupUserData() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // RPC 함수 호출
      final response =
          await _supabase.rpc('backup_user_data_safe') as Map<String, dynamic>;

      return response;
    } catch (e) {
      debugPrint('Error backing up user data: $e');
      rethrow;
    }
  }

  // ===========================================
  // 4. 계정 삭제 상태 확인
  // ===========================================

  /// 계정 삭제 상태 확인 (RPC 사용)
  static Future<bool> isAccountDeleted() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return false;
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      final response =
          await _supabase.rpc(
                'is_account_deleted_safe',
                params: {'p_user_id': userId},
              )
              as bool;

      return response;
    } catch (e) {
      debugPrint('Error checking account deletion status: $e');
      return false;
    }
  }

  /// 삭제 요청 상태 확인 (RPC 사용)
  static Future<bool> hasDeletionRequest() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return false;
      }

      // RPC 함수 호출
      final response = await _supabase.rpc('has_deletion_request_safe') as bool;

      return response;
    } catch (e) {
      debugPrint('Error checking deletion request status: $e');
      return false;
    }
  }

  // ===========================================
  // 5. 계정 삭제 취소
  // ===========================================

  /// 계정 삭제 요청 취소 (RPC 사용)
  static Future<void> cancelDeletionRequest() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // RPC 함수 호출
      await _supabase.rpc('cancel_deletion_request_safe');
    } catch (e) {
      debugPrint('Error canceling deletion request: $e');
      rethrow;
    }
  }

  // ===========================================
  // 헬퍼 메서드
  // ===========================================

  /// 삭제된 사용자 ID 목록 가져오기
  // TODO: 향후 삭제된 사용자 조회 기능 구현 시 사용 예정
  // ignore: unused_element
  /*
  static Future<List<String>> _getDeletedUserIds() async {
    try {
      final response = await _supabase.from('deleted_users').select('id');

      return response.map((user) => user['id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting deleted user IDs: $e');
      return [];
    }
  }
  */
}
