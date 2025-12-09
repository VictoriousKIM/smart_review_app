import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user.dart' as app_user;

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 관리자 전용: 사용자 목록 조회 (RPC 사용)
  Future<List<app_user.User>> getUsers({
    String? searchQuery,
    String? userTypeFilter,
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // RPC 함수 호출
      final response =
          await _supabase.rpc(
                'admin_get_users',
                params: {
                  'p_search_query': searchQuery,
                  'p_user_type_filter': userTypeFilter,
                  'p_status_filter': statusFilter,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      return response.map<app_user.User>((data) {
        final userData = data as Map<String, dynamic>;

        // company_users 배열 처리
        final companyUsersList = userData['company_users'] as List?;
        String? companyId;
        app_user.CompanyRole? companyRole;
        if (companyUsersList != null && companyUsersList.isNotEmpty) {
          final cu = companyUsersList.first as Map<String, dynamic>;
          companyId = cu['company_id'] as String?;
          if (cu['company_role'] != null) {
            companyRole = app_user.CompanyRole.values.firstWhere(
              (e) => e.name == cu['company_role'],
              orElse: () => app_user.CompanyRole.manager,
            );
          }
        }

        // sns_connections 배열 처리
        final snsConnectionsList = userData['sns_connections'] as List?;
        app_user.SNSConnections? snsConnections;
        if (snsConnectionsList != null && snsConnectionsList.isNotEmpty) {
          snsConnections = app_user.SNSConnections.fromJson(
            snsConnectionsList.map((e) => e as Map<String, dynamic>).toList(),
          );
        }

        // User 객체 생성
        return app_user.User(
          uid: userData['uid'] as String,
          email: userData['email'] as String? ?? '',
          displayName: userData['display_name'] as String?,
          createdAt: DateTime.parse(userData['created_at'] as String),
          updatedAt: DateTime.parse(
            userData['updated_at'] as String? ??
                userData['created_at'] as String,
          ),
          level: userData['level'],
          reviewCount: userData['review_count'],
          userType: app_user.UserType.values.firstWhere(
            (e) => e.name == (userData['user_type'] as String?)?.toLowerCase(),
            orElse: () => app_user.UserType.user,
          ),
          companyId: companyId,
          companyRole: companyRole,
          snsConnections: snsConnections,
          status: userData['status'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('사용자 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 관리자 전용: 사용자 총 개수 조회 (RPC 사용)
  Future<int> getUsersCount({
    String? searchQuery,
    String? userTypeFilter,
    String? statusFilter,
  }) async {
    try {
      // RPC 함수 호출
      final response =
          await _supabase.rpc(
                'admin_get_users_count',
                params: {
                  'p_search_query': searchQuery,
                  'p_user_type_filter': userTypeFilter,
                  'p_status_filter': statusFilter,
                },
              )
              as int;

      return response;
    } catch (e) {
      debugPrint('사용자 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 관리자 전용: 사용자 상태 변경 (RPC 사용)
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      await _supabase.rpc(
        'admin_update_user_status',
        params: {'p_target_user_id': userId, 'p_status': status},
      );

      debugPrint('사용자 상태 변경 성공: $userId -> $status');
    } catch (e) {
      debugPrint('사용자 상태 변경 실패: $e');
      rethrow;
    }
  }
}
