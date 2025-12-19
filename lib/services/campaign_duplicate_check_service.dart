import 'package:supabase_flutter/supabase_flutter.dart';

/// 캠페인 중복 체크 서비스
/// 
/// 상품 중복 및 스토어 중복 체크를 수행합니다.
class CampaignDuplicateCheckService {
  final SupabaseClient _supabase;

  CampaignDuplicateCheckService(this._supabase);

  /// 사용자가 참여한 캠페인 목록 조회 (중복 체크용)
  /// 
  /// [userId] 사용자 ID
  /// [preventDays] 중복 금지 기간 (일). 0이면 기간 제한 없음
  /// [excludeCampaignId] 제외할 캠페인 ID (현재 신청하려는 캠페인)
  Future<List<Map<String, dynamic>>> getUserParticipatedCampaigns({
    required String userId,
    int preventDays = 0,
    String? excludeCampaignId,
  }) async {
    final now = DateTime.now();
    final cutoffDate = preventDays > 0
        ? now.subtract(Duration(days: preventDays))
        : null;

    var query = _supabase
        .from('campaign_action_logs')
        .select('''
          campaign_id,
          campaigns!inner(
            id,
            title,
            seller,
            prevent_product_duplicate,
            prevent_store_duplicate,
            duplicate_prevent_days,
            apply_end_date,
            created_at
          )
        ''')
        .eq('user_id', userId)
        .inFilter('status', [
          'approved',
          'purchased',
          'review_submitted',
          'review_approved',
          'payment_completed',
          'visit_completed',
          'visit_verified',
          'article_submitted',
          'article_approved',
        ]);

    if (excludeCampaignId != null) {
      query = query.neq('campaign_id', excludeCampaignId);
    }

    final logs = await query;

    // 중복 금지 기간 적용
    if (cutoffDate != null) {
      return logs.where((log) {
        final campaign = log['campaigns'];
        // apply_end_date를 우선 사용하고, 없으면 created_at 사용
        final campaignDate = campaign['apply_end_date'] ?? campaign['created_at'];
        if (campaignDate == null) return false;

        final campaignDateTime = DateTime.parse(campaignDate);
        return campaignDateTime.isAfter(cutoffDate);
      }).toList();
    }

    return logs;
  }

  /// 상품 중복 체크
  /// 
  /// [userId] 사용자 ID
  /// [campaignTitle] 신청하려는 캠페인의 title
  /// [preventDays] 중복 금지 기간 (일)
  /// [excludeCampaignId] 제외할 캠페인 ID
  Future<bool> checkProductDuplicate({
    required String userId,
    required String campaignTitle,
    int preventDays = 0,
    String? excludeCampaignId,
  }) async {
    final participatedCampaigns = await getUserParticipatedCampaigns(
      userId: userId,
      preventDays: preventDays,
      excludeCampaignId: excludeCampaignId,
    );

    // prevent_product_duplicate = true인 캠페인 중에서 title이 같은 것 찾기
    final duplicateCampaigns = participatedCampaigns.where((log) {
      final campaign = log['campaigns'];
      if (campaign['prevent_product_duplicate'] != true) return false;

      final participatedTitle = campaign['title'] as String?;
      if (participatedTitle == null) return false;

      // title 비교 (대소문자 무시, 공백 제거)
      return _normalizeString(participatedTitle) ==
          _normalizeString(campaignTitle);
    }).toList();

    return duplicateCampaigns.isNotEmpty;
  }

  /// 스토어 중복 체크
  /// 
  /// [userId] 사용자 ID
  /// [seller] 신청하려는 캠페인의 seller
  /// [preventDays] 중복 금지 기간 (일)
  /// [excludeCampaignId] 제외할 캠페인 ID
  Future<bool> checkStoreDuplicate({
    required String userId,
    required String? seller,
    int preventDays = 0,
    String? excludeCampaignId,
  }) async {
    if (seller == null || seller.trim().isEmpty) {
      return false; // seller가 없으면 중복 체크 불가
    }

    final participatedCampaigns = await getUserParticipatedCampaigns(
      userId: userId,
      preventDays: preventDays,
      excludeCampaignId: excludeCampaignId,
    );

    // prevent_store_duplicate = true인 캠페인 중에서 seller가 같은 것 찾기
    final duplicateCampaigns = participatedCampaigns.where((log) {
      final campaign = log['campaigns'];
      if (campaign['prevent_store_duplicate'] != true) return false;

      final participatedSeller = campaign['seller'] as String?;
      if (participatedSeller == null) return false;

      // seller 비교 (대소문자 무시, 공백 제거)
      return _normalizeString(participatedSeller) == _normalizeString(seller);
    }).toList();

    return duplicateCampaigns.isNotEmpty;
  }

  /// 캠페인 중복 체크 (상품 + 스토어)
  /// 
  /// [userId] 사용자 ID
  /// [campaign] 신청하려는 캠페인 정보
  /// [excludeCampaignId] 제외할 캠페인 ID
  /// 
  /// Returns: 중복 여부와 중복 타입을 반환
  Future<Map<String, dynamic>> checkCampaignDuplicate({
    required String userId,
    required Map<String, dynamic> campaign,
    String? excludeCampaignId,
  }) async {
    final preventProductDuplicate =
        campaign['prevent_product_duplicate'] ?? false;
    final preventStoreDuplicate = campaign['prevent_store_duplicate'] ?? false;
    final duplicatePreventDays = campaign['duplicate_prevent_days'] ?? 0;

    // 중복 체크가 필요 없는 경우
    if (!preventProductDuplicate && !preventStoreDuplicate) {
      return {
        'isDuplicate': false,
        'duplicateType': null,
        'message': null,
      };
    }

    // 상품 중복 체크
    if (preventProductDuplicate) {
      final campaignTitle = campaign['title'] as String?;
      if (campaignTitle != null && campaignTitle.trim().isNotEmpty) {
        final isProductDuplicate = await checkProductDuplicate(
          userId: userId,
          campaignTitle: campaignTitle,
          preventDays: duplicatePreventDays,
          excludeCampaignId: excludeCampaignId,
        );

        if (isProductDuplicate) {
          return {
            'isDuplicate': true,
            'duplicateType': 'product',
            'message': '동일한 상품에 대한 중복 참여는 불가능합니다.',
          };
        }
      }
    }

    // 스토어 중복 체크
    if (preventStoreDuplicate) {
      final seller = campaign['seller'] as String?;
      if (seller != null && seller.trim().isNotEmpty) {
        final isStoreDuplicate = await checkStoreDuplicate(
          userId: userId,
          seller: seller,
          preventDays: duplicatePreventDays,
          excludeCampaignId: excludeCampaignId,
        );

        if (isStoreDuplicate) {
          return {
            'isDuplicate': true,
            'duplicateType': 'store',
            'message': '동일한 스토어에 대한 중복 참여는 불가능합니다.',
          };
        }
      }
    }

    return {
      'isDuplicate': false,
      'duplicateType': null,
      'message': null,
    };
  }

  /// 문자열 정규화 (대소문자 무시, 공백 제거)
  String _normalizeString(String str) {
    return str.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

