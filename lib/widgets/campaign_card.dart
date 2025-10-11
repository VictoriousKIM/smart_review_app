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
                      ? Image.network(
                          campaign.productImageUrl,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
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
        _buildPriceRow(
          '제품 가격',
          '${campaign.productPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
        ),
        const SizedBox(height: 1),
        _buildPriceRow(
          '리뷰 비용',
          '${campaign.reviewReward.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
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
    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('플랫폼', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Row(
            children: [
              if (campaign.platformLogoUrl.isNotEmpty)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Image.network(
                    campaign.platformLogoUrl,
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(width: 14, height: 14);
                    },
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                _getPlatformName(
                  campaign.platform.isNotEmpty ? campaign.platform : '알 수 없음',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'coupang':
        return '쿠팡';
      case 'naver':
        return '네이버 쇼핑';
      case '11st':
        return '11번가';
      case 'visit':
        return '방문형';
      default:
        return platform;
    }
  }
}
