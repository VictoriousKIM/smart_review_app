import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
          constraints: const BoxConstraints(minHeight: 140),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 제품 이미지
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: widget.campaign.productImageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.campaign.productImageUrl,
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
                              debugPrint(
                                '🖼️ 이미지 로딩 실패: ${widget.campaign.productImageUrl}',
                              );
                              debugPrint('에러: $error');
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                        Text(
                          widget.campaign.title.isNotEmpty
                              ? widget.campaign.title
                              : '제목 없음',
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
                        const SizedBox(height: 8),
                        // 상태 표시 (오픈 예정 / 모집중)
                        if (isUpcoming)
                          _buildUpcomingBadge()
                        else if (isRecruiting)
                          _buildRecruitingBadge(),
                        const SizedBox(height: 8),
                        // 참여자 수 및 신청 가능 여부
                        _buildParticipantsInfo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBadge() {
    return CountdownWidget(targetDate: widget.campaign.applyStartDate);
  }

  Widget _buildRecruitingBadge() {
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
            '신청 가능',
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

  Widget _buildParticipantsInfo() {
    final now = DateTimeUtils.nowKST();
    final isRecruiting =
        widget.campaign.status == CampaignStatus.active &&
        !widget.campaign.applyStartDate.isAfter(now) &&
        !widget.campaign.applyEndDate.isBefore(now);
    final isFull =
        widget.campaign.maxParticipants != null &&
        widget.campaign.currentParticipants >= widget.campaign.maxParticipants!;
    final canApply = isRecruiting && !isFull;

    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.people, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '참여자',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${widget.campaign.currentParticipants}${widget.campaign.maxParticipants != null ? '/${widget.campaign.maxParticipants}' : ''}명',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isFull ? Colors.red : Colors.black87,
                ),
              ),
              if (!canApply && isRecruiting) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '마감',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.campaign.productPrice > 0)
          _buildPriceRow(
            '제품 가격',
            '${widget.campaign.productPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
          ),
        if (widget.campaign.productPrice > 0) const SizedBox(height: 1),
        if (widget.campaign.campaignReward > 0)
          _buildPriceRow(
            '리뷰 보상',
            '${widget.campaign.campaignReward.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
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
    final platformName = _getPlatformName(widget.campaign.platform);

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
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
