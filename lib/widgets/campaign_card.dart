import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cloudflare_workers_service.dart';
import '../models/campaign.dart';
import '../utils/date_time_utils.dart';

class CampaignCard extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onTap;

  const CampaignCard({super.key, required this.campaign, this.onTap});

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard> {
  @override
  Widget build(BuildContext context) {
    final now = DateTimeUtils.nowKST();
    final isUpcoming = widget.campaign.applyStartDate.isAfter(now);
    final isRecruiting =
        !isUpcoming &&
        widget.campaign.status == CampaignStatus.active &&
        !widget.campaign.applyEndDate.isBefore(now) &&
        (widget.campaign.maxParticipants == null ||
            widget.campaign.currentParticipants <
                widget.campaign.maxParticipants!);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isUpcoming ? null : widget.onTap, // 오픈 예정일 때는 비활성화
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 170, // ✅ 고정 높이 설정
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제품 이미지
              SizedBox(
                width: 130, // ✅ 너비 약간 조정
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: widget.campaign.productImageUrl.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            // R2 URL을 Workers 프록시 URL로 변환
                            final imageUrl =
                                CloudflareWorkersService.convertToProxyUrl(
                                  widget.campaign.productImageUrl,
                                );
                            debugPrint('🖼️ 캠페인 카드 이미지 URL 변환:');
                            debugPrint(
                              '   원본: ${widget.campaign.productImageUrl}',
                            );
                            debugPrint('   변환: $imageUrl');

                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 140,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                width: 140,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                // 디버깅 로그
                                debugPrint('🖼️ 이미지 로딩 실패:');
                                debugPrint(
                                  '   원본 URL: ${widget.campaign.productImageUrl}',
                                );
                                debugPrint('   변환된 URL: $imageUrl');
                                debugPrint('   실제 사용된 URL: $url');
                                debugPrint('   에러: $error');
                                return Container(
                                  width: 140,
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
                            );
                          },
                        )
                      : Container(
                          width: 140,
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
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // 1. 상단 라벨 레이어 (신청가능, 플랫폼, 배송여부, 지급여부)
                      _buildTopLabels(isRecruiting, isUpcoming),
                      const SizedBox(height: 6),
                      // 2. 제목 (볼드체)
                      Expanded(
                        child: Text(
                          widget.campaign.title.isNotEmpty
                              ? widget.campaign.title
                              : '제목 없음',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 3. 제품가격, 리뷰보상
                      _buildPriceInfo(),
                      const SizedBox(height: 6),
                      // 4. 신청인원
                      _buildParticipantsInfo(),
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

  Widget _buildTopLabels(bool isRecruiting, bool isUpcoming) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        // 신청 가능 여부
        if (isUpcoming)
          _buildSmallLabel('오픈 예정', Colors.orange)
        else if (isRecruiting)
          _buildSmallLabel('신청 가능', Colors.green)
        else
          _buildSmallLabel('마감', Colors.red),

        // 플랫폼
        _buildSmallLabel(
          _getPlatformName(widget.campaign.platform),
          Colors.grey[700]!,
        ),

        // 배송 여부
        _buildSmallLabel(
          _getProvisionTypeName(widget.campaign.productProvisionType),
          Colors.blueGrey,
        ),

        // 지급 여부
        _buildSmallLabel(
          widget.campaign.paymentMethod == 'direct' ? '광고사지급' : '플랫폼지급',
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSmallLabel(String text, Color color) {
    final isOutline =
        color == Colors.green || color == Colors.orange || color == Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOutline
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOutline ? color : color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOutline ? color.withValues(alpha: 0.9) : color,
        ),
      ),
    );
  }

  String _getProvisionTypeName(String? type) {
    // DB에 한글로 저장되므로 그대로 반환
    if (type == null || type.isEmpty) {
      return '실배송';
    }
    return type;
  }

  Widget _buildParticipantsInfo() {
    final isFull =
        widget.campaign.maxParticipants != null &&
        widget.campaign.currentParticipants >= widget.campaign.maxParticipants!;

    return Row(
      children: [
        Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('신청인원', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const Spacer(),
        Text(
          '${widget.campaign.currentParticipants.toString().padLeft(2, '0')}${widget.campaign.maxParticipants != null ? '/${widget.campaign.maxParticipants.toString().padLeft(2, '0')}' : ''}명',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isFull ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInfo() {
    return Column(
      children: [
        _buildPriceRow(
          '제품 가격',
          '${widget.campaign.productPrice.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}원',
        ),
        const SizedBox(height: 2),
        _buildPriceRow(
          '리뷰 보상',
          '${widget.campaign.campaignReward.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}P',
          isReward: true,
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isReward = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isReward ? const Color(0xFF137fec) : Colors.black87,
          ),
        ),
      ],
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

/// 카운트다운 전용 위젯 (성능 최적화: CampaignCard 전체 리빌드 방지)
class CountdownWidget extends StatelessWidget {
  final DateTime targetDate;

  const CountdownWidget({super.key, required this.targetDate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTimeUtils.nowKST(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTimeUtils.nowKST();
        final difference = targetDate.difference(now);

        if (difference.isNegative) {
          // 오픈 시간 도달
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  '지금 신청 가능!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          );
        }

        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Text(
                hours > 0
                    ? '$hours시간 ${minutes.toString().padLeft(2, '0')}분 후 오픈'
                    : '$minutes분 ${seconds.toString().padLeft(2, '0')}초 후 오픈',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
