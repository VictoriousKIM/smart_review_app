import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// 회사 정보 관리 서비스
class CompanyService {
  /// 광고주 회사 정보 조회 (RPC 함수 사용)
  /// owner, manager 역할만 조회 (광고주 전용 기능용)
  /// 데이터베이스 레벨에서 필터링되므로 안전
  static Future<Map<String, dynamic>?> getAdvertiserCompanyByUserId(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // get_advertiser_company_by_user_id RPC 함수 직접 사용
      // 이 함수는 owner/manager 역할만 반환하도록 데이터베이스 레벨에서 구현되어 있음
      final response = await supabase.rpc(
        'get_advertiser_company_by_user_id',
        params: {'p_user_id': userId},
      );

      if (response == null) {
        return null;
      }

      // RPC 함수는 TABLE을 반환하므로 첫 번째 행을 반환
      final companyList = response as List;
      if (companyList.isEmpty) {
        return null;
      }

      return companyList[0] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ 광고주 회사 정보 조회 실패: $e');
      return null;
    }
  }

  /// 사용자 ID로 회사 정보 조회 (RPC 함수 사용)
  /// owner/manager 역할만 조회 (reviewer 제외)
  /// RLS 정책과 RPC 함수에서 필터링되므로 안전
  static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // get_advertiser_company_by_user_id RPC 함수 사용
      // 이 함수는 owner/manager 역할만 반환하도록 구현되어 있음
      final response = await supabase.rpc(
        'get_advertiser_company_by_user_id',
        params: {'p_user_id': userId},
      );

      if (response == null) {
        return null;
      }

      // RPC 함수는 TABLE을 반환하므로 첫 번째 행을 반환
      final companyList = response as List;
      if (companyList.isEmpty) {
        return null;
      }

      return companyList[0] as Map<String, dynamic>;
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

  /// 매니저 등록 요청 상태 조회 (RPC 함수 사용)
  /// pending 또는 rejected 상태
  /// 데이터베이스 레벨에서 필터링되므로 안전
  static Future<Map<String, dynamic>?> getPendingManagerRequest(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (jsonb 반환)
      final response = await supabase.rpc(
        'get_pending_manager_request_safe',
        params: {'p_user_id': userId},
      );

      if (response == null) {
        return null;
      }

      // jsonb 반환이므로 Map으로 변환
      final result = response as Map<String, dynamic>;
      if (result.isEmpty) {
        return null;
      }

      // 기존 형식과 호환되도록 변환
      return {
        'id': result['id'],
        'business_name': result['business_name'],
        'business_number': result['business_number'],
        'status': result['status'],
        'requested_at': result['requested_at'],
      };
    } catch (e) {
      debugPrint('❌ 매니저 등록 요청 상태 조회 실패: $e');
      return null;
    }
  }

  /// 매니저 등록 요청 삭제 (RPC 함수 사용)
  /// 데이터베이스 레벨에서 권한 체크 및 삭제 수행
  static Future<void> cancelManagerRequest(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출 (jsonb 반환)
      final response = await supabase.rpc(
        'cancel_manager_request_safe',
        params: {'p_user_id': userId},
      );

      // 응답 확인 (기존 함수는 jsonb를 반환)
      if (response == null) {
        throw Exception('매니저 등록 요청 삭제 실패: 응답이 없습니다.');
      }
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

  /// 사업자명으로 회사 검색 (RPC 함수 사용)
  /// 데이터베이스 레벨에서 검색 수행
  static Future<List<Map<String, dynamic>>> searchCompaniesByName(
    String businessName,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // RPC 함수 호출
      final response = await supabase.rpc(
        'search_companies_by_name',
        params: {
          'p_business_name': businessName.trim(),
        },
      );

      if (response == null) {
        return [];
      }

      // TABLE 반환이므로 List로 변환
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ 회사 검색 실패: $e');
      return [];
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
