import 'package:supabase_flutter/supabase_flutter.dart';

/// 회사 사용자 권한 체크 서비스
class CompanyUserService {
  /// 사용자가 광고주로 전환할 수 있는 권한이 있는지 확인 (RPC 사용)
  static Future<bool> canConvertToAdvertiser(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final response =
          await supabase.rpc('can_convert_to_advertiser_safe') as bool;

      return response;
    } catch (e) {
      print('❌ 광고주 전환 권한 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 역할 조회 (RPC 사용)
  static Future<String?> getUserCompanyRole(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final response =
          await supabase.rpc('get_user_company_role_safe') as String?;

      return response;
    } catch (e) {
      print('❌ 사용자 회사 역할 조회 실패: $e');
      return null;
    }
  }

  /// 사용자가 회사에 속해있는지 확인 (RPC 사용)
  static Future<bool> isUserInCompany(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final response = await supabase.rpc('is_user_in_company_safe') as bool;

      return response;
    } catch (e) {
      print('❌ 사용자 회사 소속 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 ID 조회 (RPC 사용)
  static Future<String?> getUserCompanyId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final response =
          await supabase.rpc('get_user_company_id_safe') as String?;

      return response;
    } catch (e) {
      print('❌ 사용자 회사 ID 조회 실패: $e');
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
      final result = await supabase.rpc(
        'deactivate_manager_role',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
        },
      );
      if (result == null) {
        throw Exception('매니저 비활성화 실패: 응답이 없습니다.');
      }
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ 매니저 비활성화 실패: $e');
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
      final result = await supabase.rpc(
        'activate_manager_role',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
        },
      );
      if (result == null) {
        throw Exception('매니저 활성화 실패: 응답이 없습니다.');
      }
      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ 매니저 활성화 실패: $e');
      rethrow;
    }
  }
}
