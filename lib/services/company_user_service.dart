import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// 회사 사용자 권한 체크 서비스
class CompanyUserService {
  /// 사용자가 광고주로 전환할 수 있는 권한이 있는지 확인 (RPC 사용)
  static Future<bool> canConvertToAdvertiser(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response = await supabase.rpc(
        'can_convert_to_advertiser_safe',
        params: {'p_user_id': userId},
      ) as bool;

      return response;
    } catch (e) {
      debugPrint('❌ 광고주 전환 권한 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 역할 조회 (RPC 사용)
  static Future<String?> getUserCompanyRole(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await supabase.rpc(
                'get_user_company_role_safe',
                params: {'p_user_id': userId},
              ) as String?;

      return response;
    } catch (e) {
      debugPrint('❌ 사용자 회사 역할 조회 실패: $e');
      return null;
    }
  }

  /// 사용자가 회사에 속해있는지 확인 (RPC 사용)
  static Future<bool> isUserInCompany(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response = await supabase.rpc(
        'is_user_in_company_safe',
        params: {'p_user_id': userId},
      ) as bool;

      return response;
    } catch (e) {
      debugPrint('❌ 사용자 회사 소속 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 ID 조회 (RPC 사용)
  static Future<String?> getUserCompanyId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response =
          await supabase.rpc(
                'get_user_company_id_safe',
                params: {'p_user_id': userId},
              ) as String?;

      return response;
    } catch (e) {
      debugPrint('❌ 사용자 회사 ID 조회 실패: $e');
      return null;
    }
  }

  /// 매니저 비활성화
  static Future<Map<String, dynamic>> deactivateManager({
    required String companyId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      final result = await supabase.rpc(
        'deactivate_manager_role',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
          'p_current_user_id': currentUserId,
        },
      );
      if (result == null) {
        throw Exception('매니저 비활성화 실패: 응답이 없습니다.');
      }
      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ 매니저 비활성화 실패: $e');
      rethrow;
    }
  }

  /// 매니저 활성화
  static Future<Map<String, dynamic>> activateManager({
    required String companyId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      final result = await supabase.rpc(
        'activate_manager_role',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
          'p_current_user_id': currentUserId,
        },
      );
      if (result == null) {
        throw Exception('매니저 활성화 실패: 응답이 없습니다.');
      }
      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ 매니저 활성화 실패: $e');
      rethrow;
    }
  }
}
