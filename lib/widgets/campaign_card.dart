import 'package:flutter/material.dart';
import '../models/campaign.dart';

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback? onTap;

  const CampaignCard({super.key, required this.campaign, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          child: Row(
            children: [
              // 제품 이미지
              SizedBox(
                width: 140,
                height: 140,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: campaign.productImageUrl.isNotEmpty
                      ? Container(
                          width: 140,
                          height: 140,
                          color: Colors.grey[100],
                          child: Image.network(
                            campaign.productImageUrl,
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // 디버깅 로그
                            debugPrint('🖼️ 이미지 로딩 실패: ${campaign.productImageUrl}');
                            debugPrint('에러: $error');
                            return Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '이미지\n로딩 실패',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                          ),
                        )
                      : Container(
                          width: 140,
                          height: 140,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                ),
              ),
              // 캠페인 정보
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Text(
                        campaign.title.isNotEmpty ? campaign.title : '제목 없음',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // 가격 정보
                      _buildPriceInfo(),
                      const SizedBox(height: 8),
                      // 플랫폼 정보
                      _buildPlatformInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (campaign.productPrice != null && campaign.productPrice! > 0)
          _buildPriceRow(
            '제품 가격',
            '${campaign.productPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
          ),
        if (campaign.productPrice != null && campaign.productPrice! > 0)
          const SizedBox(height: 1),
        if (campaign.campaignReward > 0)
          _buildPriceRow(
            '리뷰 보상',
            '${campaign.campaignReward.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
            isReward: true,
          ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isReward = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isReward ? const Color(0xFF137fec) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformInfo() {
    final platformName = _getPlatformName(campaign.platform);
    
    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('플랫폼', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(
            platformName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlatformName(String? platform) {
    if (platform == null || platform.isEmpty || platform.trim().isEmpty) {
      return '알 수 없음';
    }
    
    switch (platform.toLowerCase().trim()) {
      case 'coupang':
        return '쿠팡';
      case 'naver':
        return '네이버 쇼핑';
      case '11st':
      case '11번가':
        return '11번가';
      case 'visit':
      case '방문형':
        return '방문형';
      default:
        // 알 수 없는 플랫폼이면 원본 값 반환 (디버깅용)
        debugPrint('⚠️ 알 수 없는 플랫폼: $platform');
        return platform;
    }
  }
}
