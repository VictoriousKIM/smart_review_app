import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// 회사 정보 관리 서비스
class CompanyService {
  static const String _tableName = 'companies';

  /// 사용자 ID로 회사 정보 조회
  static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블을 통해 company_id 조회 (status='active'만)
      final companyUserResponse = await supabase
          .from('company_users')
          .select('company_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (companyUserResponse == null) {
        return null;
      }

      final companyId = companyUserResponse['company_id'];
      if (companyId == null) {
        return null;
      }

      // company_id로 회사 정보 조회
      final companyData = await supabase
          .from(_tableName)
          .select()
          .eq('id', companyId)
          .maybeSingle();

      return companyData;
    } catch (e) {
      print('❌ 사용자 회사 정보 조회 실패: $e');
      return null;
    }
  }

  /// 매니저 등록 요청
  static Future<Map<String, dynamic>> requestManagerRole({
    required String businessName,
    required String businessNumber,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final result = await supabase.rpc(
        'request_manager_role',
        params: {
          'p_business_name': businessName,
          'p_business_number': businessNumber,
        },
      );

      if (result == null) {
        throw Exception('매니저 등록 요청 실패: 응답이 없습니다.');
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      print('❌ 매니저 등록 요청 실패: $e');
      rethrow;
    }
  }

  /// 매니저 등록 요청 상태 조회 (pending 또는 rejected 상태)
  static Future<Map<String, dynamic>?> getPendingManagerRequest(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블에서 pending 또는 rejected 상태의 manager 역할 조회
      final companyUserResponse = await supabase
          .from('company_users')
          .select('company_id, status, created_at')
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'rejected'])
          .eq('company_role', 'manager')
          .maybeSingle();

      if (companyUserResponse == null) {
        return null;
      }

      final companyId = companyUserResponse['company_id'];
      if (companyId == null) {
        return null;
      }

      // 회사 정보 조회
      final companyData = await supabase
          .from(_tableName)
          .select()
          .eq('id', companyId)
          .maybeSingle();

      if (companyData == null) {
        return null;
      }

      return {
        ...companyData,
        'status': companyUserResponse['status'],
        'requested_at': companyUserResponse['created_at'],
      };
    } catch (e) {
      print('❌ 매니저 등록 요청 상태 조회 실패: $e');
      return null;
    }
  }

  /// 매니저 등록 요청 삭제
  static Future<void> cancelManagerRequest(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블에서 pending 상태의 manager 역할 삭제
      await supabase
          .from('company_users')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .eq('company_role', 'manager');
    } catch (e) {
      print('❌ 매니저 등록 요청 삭제 실패: $e');
      rethrow;
    }
  }

  /// 사용자가 신청한 리뷰어 요청 목록 조회
  static Future<List<Map<String, dynamic>>> getUserReviewerRequests() async {
    try {
      final supabase = Supabase.instance.client;
      // Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      final response = await supabase.rpc(
            'get_user_reviewer_requests',
            params: {'p_user_id': userId},
          );
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ 리뷰어 요청 목록 조회 실패: $e');
      rethrow;
    }
  }
}
