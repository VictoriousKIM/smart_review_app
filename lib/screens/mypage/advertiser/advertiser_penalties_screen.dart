import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserPenaltiesScreen extends ConsumerStatefulWidget {
  const AdvertiserPenaltiesScreen({super.key});

  @override
  ConsumerState<AdvertiserPenaltiesScreen> createState() =>
      _AdvertiserPenaltiesScreenState();
}

class _AdvertiserPenaltiesScreenState
    extends ConsumerState<AdvertiserPenaltiesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _penalties = [];
  Map<String, dynamic> _penaltySummary = {};

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _penaltySummary = {
        'totalPenalties': 2,
        'activePenalties': 1,
        'totalDeduction': 50000,
        'currentStatus': 'warning',
        'statusText': '경고 상태',
      };

      _penalties = [
        {
          'id': '1',
          'type': 'late_review',
          'typeText': '리뷰 지연',
          'description': '헤드폰 리뷰 캠페인에서 리뷰 제출이 3일 지연되었습니다.',
          'amount': 30000,
          'date': '2024-01-15',
          'status': 'active',
          'statusText': '적용중',
          'campaignTitle': '헤드폰 리뷰 캠페인',
          'participantName': '김리뷰',
        },
        {
          'id': '2',
          'type': 'poor_quality',
          'typeText': '저품질 리뷰',
          'description': '스마트폰 리뷰 캠페인에서 부적절한 리뷰 내용이 발견되었습니다.',
          'amount': 20000,
          'date': '2024-01-10',
          'status': 'resolved',
          'statusText': '해결됨',
          'campaignTitle': '스마트폰 리뷰 캠페인',
          'participantName': '박테스터',
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('페널티 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPenaltiesContent(),
    );
  }

  Widget _buildPenaltiesContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 페널티 요약 카드
          _buildSummaryCard(),

          const SizedBox(height: 24),

          // 페널티 내역
          _buildPenaltiesList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    Color statusColor;
    switch (_penaltySummary['currentStatus']) {
      case 'warning':
        statusColor = Colors.orange;
        break;
      case 'suspended':
        statusColor = Colors.red;
        break;
      case 'normal':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_outlined, color: statusColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '페널티 현황',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '총 페널티',
                  '${_penaltySummary['totalPenalties']}건',
                  Icons.list_alt_outlined,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '적용중',
                  '${_penaltySummary['activePenalties']}건',
                  Icons.schedule_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '총 차감액',
                  '${_penaltySummary['totalDeduction'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  Icons.account_balance_wallet_outlined,
                  Colors.red,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _penaltySummary['statusText'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '현재 상태',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildPenaltiesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '페널티 내역',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        if (_penalties.isEmpty)
          _buildEmptyState()
        else
          ..._penalties.map((penalty) => _buildPenaltyCard(penalty)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.green[400]),
          const SizedBox(height: 16),
          Text(
            '페널티 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '모든 캠페인이 정상적으로 진행되고 있습니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyCard(Map<String, dynamic> penalty) {
    Color statusColor;
    switch (penalty['status']) {
      case 'active':
        statusColor = Colors.red;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
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
                    penalty['typeText'],
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
                    penalty['statusText'],
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
            Text(
              penalty['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  penalty['campaignTitle'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  penalty['participantName'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '발생일: ${penalty['date']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.account_balance_wallet, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  '차감: ${penalty['amount'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (penalty['status'] == 'active') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: '이의제기',
                  onPressed: () => _appealPenalty(penalty),
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF137fec),
                  borderColor: const Color(0xFF137fec),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _appealPenalty(Map<String, dynamic> penalty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('페널티 이의제기'),
        content: const Text('페널티 이의제기 기능은 준비 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
