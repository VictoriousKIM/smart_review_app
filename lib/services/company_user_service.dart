import 'package:supabase_flutter/supabase_flutter.dart';

/// 회사 사용자 권한 체크 서비스
class CompanyUserService {
  /// 사용자가 광고주로 전환할 수 있는 권한이 있는지 확인
  /// company_users 테이블에서 company_role이 'owner' 또는 'manager'인지 확인
  static Future<bool> canConvertToAdvertiser(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블에서 사용자의 역할 확인 (status='active'만)
      final response = await supabase
          .from('company_users')
          .select('company_role')
          .eq('user_id', userId)
          .eq('status', 'active')
          .or('company_role.eq.owner,company_role.eq.manager')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ 광고주 전환 권한 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 역할 조회
  static Future<String?> getUserCompanyRole(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // status='active'만 조회
      final response = await supabase
          .from('company_users')
          .select('company_role')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      return response?['company_role'] as String?;
    } catch (e) {
      print('❌ 사용자 회사 역할 조회 실패: $e');
      return null;
    }
  }

  /// 사용자가 회사에 속해있는지 확인
  static Future<bool> isUserInCompany(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // status='active'만 조회 (복합 키 사용으로 id 제거)
      final response = await supabase
          .from('company_users')
          .select('company_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ 사용자 회사 소속 확인 실패: $e');
      return false;
    }
  }

  /// 사용자의 회사 ID 조회
  static Future<String?> getUserCompanyId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // status='active'만 조회
      final response = await supabase
          .from('company_users')
          .select('company_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      return response?['company_id'] as String?;
    } catch (e) {
      print('❌ 사용자 회사 ID 조회 실패: $e');
      return null;
    }
  }
}

