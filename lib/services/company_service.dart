import 'package:supabase_flutter/supabase_flutter.dart';

/// 회사 정보 관리 서비스
class CompanyService {
  static const String _tableName = 'companies';

  /// 사용자 ID로 회사 정보 조회
  static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블을 통해 company_id 조회
      final companyUserResponse = await supabase
          .from('company_users')
          .select('company_id')
          .eq('user_id', userId)
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
}
