import 'package:flutter/foundation.dart';
import '../services/company_user_service.dart';

/// 사용자 타입 및 역할 판단 헬퍼 클래스
/// 
/// 리뷰어/광고주 구분 로직을 중앙화하여 일관성 있는 판단을 제공합니다.
/// 
/// 리뷰어 판단 조건:
/// 1. company_users 테이블에 레코드가 없음
/// 2. company_users.status != 'active'
/// 3. company_users.company_role = 'reviewer' AND status = 'active'
/// 
/// 광고주 판단 조건:
/// 1. company_users 테이블에 레코드가 있음
/// 2. company_users.status = 'active'
/// 3. company_users.company_role IN ('owner', 'manager')
class UserTypeHelper {
  /// 현재 사용자가 리뷰어인지 확인
  /// 
  /// 리뷰어 조건:
  /// 1. company_users 테이블에 레코드가 없음
  /// 2. company_users.status != 'active'
  /// 3. company_users.company_role = 'reviewer' AND status = 'active'
  /// 
  /// 반환값: true면 리뷰어, false면 광고주 또는 기타
  static Future<bool> isReviewer(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      
      // 레코드가 없거나 status != 'active'인 경우
      if (companyRole == null) {
        return true;
      }
      
      // company_role = 'reviewer'인 경우
      if (companyRole == 'reviewer') {
        return true;
      }
      
      // company_role이 'owner' 또는 'manager'인 경우는 광고주
      return false;
    } catch (e) {
      debugPrint('❌ 리뷰어 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주인지 확인
  /// 
  /// 광고주 조건:
  /// 1. company_users 테이블에 레코드가 있음
  /// 2. company_users.status = 'active'
  /// 3. company_users.company_role IN ('owner', 'manager')
  /// 
  /// 반환값: true면 광고주, false면 리뷰어
  static Future<bool> isAdvertiser(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      
      // 레코드가 없거나 status != 'active'인 경우
      if (companyRole == null) {
        return false;
      }
      
      // company_role이 'owner' 또는 'manager'인 경우
      return companyRole == 'owner' || companyRole == 'manager';
    } catch (e) {
      debugPrint('❌ 광고주 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주 owner인지 확인
  /// 
  /// 반환값: true면 광고주 owner, false면 그 외
  static Future<bool> isAdvertiserOwner(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      return companyRole == 'owner';
    } catch (e) {
      debugPrint('❌ 광고주 owner 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주 manager인지 확인
  /// 
  /// 반환값: true면 광고주 manager, false면 그 외
  static Future<bool> isAdvertiserManager(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      return companyRole == 'manager';
    } catch (e) {
      debugPrint('❌ 광고주 manager 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자의 company_role 반환
  /// 
  /// 반환값:
  /// - 'owner': 광고주 owner
  /// - 'manager': 광고주 manager
  /// - 'reviewer': 리뷰어 (회사에 속한)
  /// - null: 리뷰어 (회사에 속하지 않은)
  static Future<String?> getCompanyRole(String userId) async {
    return await CompanyUserService.getUserCompanyRole(userId);
  }
  
  /// 라우팅 경로에서 userType 문자열 추출
  /// 
  /// 반환값: 'reviewer', 'advertiser', 또는 'user'
  static String getUserTypeFromPath(String path) {
    if (path.contains('/reviewer/')) return 'reviewer';
    if (path.contains('/advertiser/')) return 'advertiser';
    return 'user';
  }
}

