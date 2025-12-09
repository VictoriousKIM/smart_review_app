import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// 회사 정보 관리 서비스
class CompanyService {
  /// 광고주 회사 정보 조회 (기존 RPC 함수 조합 사용)
  /// owner, manager 역할만 조회 (광고주 전용 기능용)
  static Future<Map<String, dynamic>?> getAdvertiserCompanyByUserId(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. 사용자 역할 확인 (기존 작동하는 RPC 사용)
      final companyRole =
          await supabase.rpc(
                'get_user_company_role_safe',
                params: {'p_user_id': userId},
              )
              as String?;

      // owner 또는 manager가 아니면 null 반환
      if (companyRole != 'owner' && companyRole != 'manager') {
        return null;
      }

      // 2. 회사 ID 조회 (기존 작동하는 RPC 사용)
      final companyId =
          await supabase.rpc(
                'get_user_company_id_safe',
                params: {'p_user_id': userId},
              )
              as String?;

      if (companyId == null) {
        return null;
      }

      // 3. 회사 정보 조회 (RLS 정책이 있으므로 안전)
      final companyData = await supabase
          .from('companies')
          .select()
          .eq('id', companyId)
          .maybeSingle();

      return companyData;
    } catch (e) {
      debugPrint('❌ 광고주 회사 정보 조회 실패: $e');
      return null;
    }
  }

  /// 사용자 ID로 회사 정보 조회 (기존 RPC 함수 조합 사용)
  /// 리뷰어도 광고주로 등록할 수 있도록 모든 역할의 회사 정보 반환
  static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. 회사 ID 조회 (기존 작동하는 RPC 사용)
      final companyId =
          await supabase.rpc(
                'get_user_company_id_safe',
                params: {'p_user_id': userId},
              )
              as String?;

      if (companyId == null) {
        return null;
      }

      // 2. 회사 정보 조회 (RLS 정책이 있으므로 안전)
      final companyData = await supabase
          .from('companies')
          .select()
          .eq('id', companyId)
          .maybeSingle();

      return companyData;
    } catch (e) {
      debugPrint('❌ 사용자 회사 정보 조회 실패: $e');
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

      // Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // RPC 함수 호출
      final result = await supabase.rpc(
        'request_manager_role',
        params: {
          'p_business_name': businessName,
          'p_business_number': businessNumber,
          'p_user_id': userId,
        },
      );

      if (result == null) {
        throw Exception('매니저 등록 요청 실패: 응답이 없습니다.');
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ 매니저 등록 요청 실패: $e');
      rethrow;
    }
  }

  /// 매니저 등록 요청 상태 조회 (기존 RPC 함수 조합 사용)
  /// pending 또는 rejected 상태
  static Future<Map<String, dynamic>?> getPendingManagerRequest(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블에서 pending 또는 rejected 상태의 manager 역할 조회
      // RLS 정책이 있으므로 안전
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

      final companyId = companyUserResponse['company_id'] as String?;
      if (companyId == null) {
        return null;
      }

      // 회사 정보 조회 (RLS 정책이 있으므로 안전)
      final companyData = await supabase
          .from('companies')
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
      debugPrint('❌ 매니저 등록 요청 상태 조회 실패: $e');
      return null;
    }
  }

  /// 매니저 등록 요청 삭제 (RLS 정책 활용)
  static Future<void> cancelManagerRequest(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // pending 상태의 manager 역할 삭제
      // RLS 정책이 있으므로 안전 (사용자 본인의 요청만 삭제 가능)
      await supabase
          .from('company_users')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .eq('company_role', 'manager');
    } catch (e) {
      debugPrint('❌ 매니저 등록 요청 삭제 실패: $e');
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

      debugPrint('🔍 리뷰어 요청 목록 조회 시작 - userId: $userId');

      final response = await supabase.rpc(
        'get_user_reviewer_requests',
        params: {'p_user_id': userId},
      );

      final requests = (response as List).cast<Map<String, dynamic>>();
      debugPrint('✅ 리뷰어 요청 목록 조회 성공 - 개수: ${requests.length}');
      if (requests.isNotEmpty) {
        debugPrint('📋 조회된 요청 목록:');
        for (var request in requests) {
          debugPrint(
            '  - company_id: ${request['company_id']}, company_name: ${request['company_name']}, status: ${request['status']}',
          );
        }
      } else {
        debugPrint('⚠️ 조회된 요청이 없습니다.');
      }

      return requests;
    } catch (e) {
      debugPrint('❌ 리뷰어 요청 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 회사의 auto_approve_reviewers 값 업데이트
  static Future<Map<String, dynamic>> updateAutoApproveReviewers({
    required String companyId,
    required bool autoApproveReviewers,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final result = await supabase.rpc(
        'update_company_auto_approve_reviewers',
        params: {
          'p_company_id': companyId,
          'p_auto_approve_reviewers': autoApproveReviewers,
        },
      );

      if (result == null) {
        throw Exception('리뷰어 자동승인 설정 업데이트 실패: 응답이 없습니다.');
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ 리뷰어 자동승인 설정 업데이트 실패: $e');
      rethrow;
    }
  }
}
