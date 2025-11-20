import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/campaign_application_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../utils/date_time_utils.dart';

class ReviewerApplicationsScreen extends ConsumerStatefulWidget {
  const ReviewerApplicationsScreen({super.key});

  @override
  ConsumerState<ReviewerApplicationsScreen> createState() =>
      _ReviewerApplicationsScreenState();
}

class _ReviewerApplicationsScreenState
    extends ConsumerState<ReviewerApplicationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];
  final CampaignApplicationService _applicationService =
      CampaignApplicationService();

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _applicationService.getUserApplications();

      if (response.success && response.data != null) {
        setState(() {
          _applications = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _applications = [];
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error ?? '신청 내역을 불러올 수 없습니다')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _applications = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('캠페인 신청내역'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
          ? _buildEmptyState()
          : _buildApplicationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '신청한 캠페인이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 캠페인에 참여해보세요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: '캠페인 둘러보기',
            onPressed: () {
              Navigator.pop(context);
            },
            backgroundColor: const Color(0xFF137fec),
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final application = _applications[index];
        return _buildApplicationCard(application);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final campaign = application['campaigns'] as Map<String, dynamic>?;
    if (campaign == null) return const SizedBox.shrink();

    final status = application['status'] as String;
    final appliedAt = DateTimeUtils.parseKST(application['applied_at'] as String);

    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = '선정됨';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = '미선정';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = '완료';
        break;
      default:
        statusColor = Colors.orange;
        statusText = '심사중';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    campaign['title'] ?? '제목 없음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '신청일: ${appliedAt.toString().split(' ')[0]}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '보상: ${(campaign['campaign_reward'] ?? campaign['review_reward'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            if (application['application_message'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '신청 메시지: ${application['application_message']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (application['rejection_reason'] != null) ...[
              const SizedBox(height: 8),
              Text(
                '거절 사유: ${application['rejection_reason']}',
                style: TextStyle(fontSize: 12, color: Colors.red[600]),
              ),
            ],
            if (status == 'approved') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: '리뷰 작성하기',
                  onPressed: () {
                    // TODO: 리뷰 작성 화면으로 이동
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('리뷰 작성 기능은 준비 중입니다')),
                    );
                  },
                  backgroundColor: const Color(0xFF137fec),
                  textColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
