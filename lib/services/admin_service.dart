import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user.dart' as app_user;
import '../utils/date_time_utils.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 관리자 전용: 사용자 목록 조회
  /// TODO: RPC 함수로 변경 권장 (admin_get_users)
  Future<List<app_user.User>> getUsers({
    String? searchQuery,
    String? userTypeFilter,
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // users 테이블과 auth.users, company_users, sns_connections 조인
      var query = _supabase
          .from('users')
          .select('''
            *,
            auth.users!inner(email),
            company_users!left(company_id, company_role, status),
            sns_connections!left(*)
          ''');

      // 검색 (이메일, display_name)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // 검색은 별도로 처리 (auth.users와 조인 시 복잡함)
        // TODO: RPC 함수에서 처리 권장
      }

      // 필터링
      if (userTypeFilter != null && userTypeFilter.isNotEmpty) {
        query = query.eq('user_type', userTypeFilter);
      }

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      // 정렬 및 페이지네이션
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<app_user.User>((data) {
        // auth.users에서 이메일 추출
        final authUser = (data['auth.users'] as List?)?.first;
        final email = authUser?['email'] as String? ?? '';
        
        // company_users에서 company_id, company_role 추출 (JOIN된 경우)
        final companyUser = data['company_users'] as List?;
        String? companyId;
        app_user.CompanyRole? companyRole;
        if (companyUser != null && companyUser.isNotEmpty) {
          final cu = companyUser.first as Map<String, dynamic>;
          companyId = cu['company_id'] as String?;
          if (cu['company_role'] != null) {
            companyRole = app_user.CompanyRole.values.firstWhere(
              (e) => e.name == cu['company_role'],
              orElse: () => app_user.CompanyRole.manager,
            );
          }
        }
        
        // sns_connections 추출 (JOIN된 경우)
        final snsConnectionsList = data['sns_connections'] as List?;
        app_user.SNSConnections? snsConnections;
        if (snsConnectionsList != null && snsConnectionsList.isNotEmpty) {
          snsConnections = app_user.SNSConnections.fromJson(
            snsConnectionsList.map((e) => e as Map<String, dynamic>).toList(),
          );
        }
        
        // User 객체 생성 (이메일 포함)
        return app_user.User(
          uid: data['id'] as String,
          email: email,
          displayName: data['display_name'] as String?,
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String? ?? data['created_at'] as String),
          level: data['level'], // nullable로 변경됨
          reviewCount: data['review_count'], // nullable로 변경됨
          userType: app_user.UserType.values.firstWhere(
            (e) => e.name == (data['user_type'] as String?)?.toLowerCase(),
            orElse: () => app_user.UserType.user,
          ),
          companyId: companyId,
          companyRole: companyRole,
          snsConnections: snsConnections,
          status: data['status'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('사용자 목록 조회 실패: $e');
        // 조인 실패 시 간단한 쿼리로 재시도 (JOIN 없이)
        try {
          var query = _supabase.from('users').select('*');
        
        if (userTypeFilter != null && userTypeFilter.isNotEmpty) {
          query = query.eq('user_type', userTypeFilter);
        }
        if (statusFilter != null && statusFilter.isNotEmpty) {
          query = query.eq('status', statusFilter);
        }
        
        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        // 이메일은 별도로 조회하지 않고 빈 문자열로 처리 (TODO: RPC 함수에서 처리)
        final users = <app_user.User>[];
        for (final data in response) {
          final userId = data['id'] as String;
          
          // company_users에서 company_id, company_role 추출
          final companyUser = data['company_users'] as List?;
          String? companyId;
          app_user.CompanyRole? companyRole;
          if (companyUser != null && companyUser.isNotEmpty) {
            final cu = companyUser.first as Map<String, dynamic>;
            companyId = cu['company_id'] as String?;
            if (cu['company_role'] != null) {
              companyRole = app_user.CompanyRole.values.firstWhere(
                (e) => e.name == cu['company_role'],
                orElse: () => app_user.CompanyRole.manager,
              );
            }
          }
          
          // sns_connections 추출
          final snsConnectionsList = data['sns_connections'] as List?;
          app_user.SNSConnections? snsConnections;
          if (snsConnectionsList != null && snsConnectionsList.isNotEmpty) {
            snsConnections = app_user.SNSConnections.fromJson(
              snsConnectionsList.map((e) => e as Map<String, dynamic>).toList(),
            );
          }
          
          users.add(app_user.User(
            uid: userId,
            email: '', // TODO: auth.users에서 이메일 조회 필요 (RPC 함수 권장)
            displayName: data['display_name'] as String?,
            createdAt: DateTime.parse(data['created_at'] as String),
            updatedAt: DateTime.parse(data['updated_at'] as String? ?? data['created_at'] as String),
            level: data['level'], // nullable로 변경됨
            reviewCount: data['review_count'], // nullable로 변경됨
            userType: app_user.UserType.values.firstWhere(
              (e) => e.name == (data['user_type'] as String?)?.toLowerCase(),
              orElse: () => app_user.UserType.user,
            ),
            companyId: companyId,
            companyRole: companyRole,
            snsConnections: snsConnections,
            status: data['status'] as String?,
          ));
        }
        return users;
      } catch (e2) {
        debugPrint('사용자 목록 조회 재시도 실패: $e2');
        rethrow;
      }
    }
  }

  /// 관리자 전용: 사용자 총 개수 조회
  Future<int> getUsersCount({
    String? searchQuery,
    String? userTypeFilter,
    String? statusFilter,
  }) async {
    try {
      var query = _supabase.from('users').select('id');

      if (userTypeFilter != null && userTypeFilter.isNotEmpty) {
        query = query.eq('user_type', userTypeFilter);
      }

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      debugPrint('사용자 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 관리자 전용: 사용자 상태 변경
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _supabase
          .from('users')
          .update({'status': status, 'updated_at': DateTimeUtils.toIso8601StringKST(DateTimeUtils.nowKST())})
          .eq('id', userId);
      
      debugPrint('사용자 상태 변경 성공: $userId -> $status');
    } catch (e) {
      debugPrint('사용자 상태 변경 실패: $e');
      rethrow;
    }
  }
}

