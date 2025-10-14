import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserParticipantsScreen extends ConsumerStatefulWidget {
  const AdvertiserParticipantsScreen({super.key});

  @override
  ConsumerState<AdvertiserParticipantsScreen> createState() =>
      _AdvertiserParticipantsScreenState();
}

class _AdvertiserParticipantsScreenState
    extends ConsumerState<AdvertiserParticipantsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _participants = [
        {
          'id': '1',
          'name': '김리뷰',
          'email': 'kim@example.com',
          'status': 'approved',
          'statusText': '승인됨',
          'appliedAt': '2024-01-15',
          'campaignTitle': '새로운 스마트폰 리뷰 캠페인',
          'reviewSubmitted': true,
          'rating': 5,
        },
        {
          'id': '2',
          'name': '박테스터',
          'email': 'park@example.com',
          'status': 'pending',
          'statusText': '심사중',
          'appliedAt': '2024-01-16',
          'campaignTitle': '새로운 스마트폰 리뷰 캠페인',
          'reviewSubmitted': false,
          'rating': 0,
        },
        {
          'id': '3',
          'name': '이평가',
          'email': 'lee@example.com',
          'status': 'rejected',
          'statusText': '거절됨',
          'appliedAt': '2024-01-14',
          'campaignTitle': '헤드폰 리뷰 캠페인',
          'reviewSubmitted': false,
          'rating': 0,
        },
        {
          'id': '4',
          'name': '최분석',
          'email': 'choi@example.com',
          'status': 'approved',
          'statusText': '승인됨',
          'appliedAt': '2024-01-12',
          'campaignTitle': '헤드폰 리뷰 캠페인',
          'reviewSubmitted': true,
          'rating': 4,
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
        title: const Text('참여자 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 필터 탭
        _buildFilterTabs(),

        // 참여자 목록
        Expanded(
          child: _participants.isEmpty
              ? _buildEmptyState()
              : _buildParticipantsList(),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': '전체'},
      {'key': 'pending', 'label': '심사중'},
      {'key': 'approved', 'label': '승인됨'},
      {'key': 'rejected', 'label': '거절됨'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key']!;
                  });
                },
                selectedColor: const Color(0xFF137fec),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '참여자가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '캠페인을 등록하여 참여자를 모집해보세요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    final filteredParticipants = _selectedFilter == 'all'
        ? _participants
        : _participants
              .where((participant) => participant['status'] == _selectedFilter)
              .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredParticipants.length,
      itemBuilder: (context, index) {
        final participant = filteredParticipants[index];
        return _buildParticipantCard(participant);
      },
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> participant) {
    Color statusColor;
    switch (participant['status']) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
        statusColor = Colors.orange;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        participant['email'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
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
                    participant['statusText'],
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
              participant['campaignTitle'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '신청일: ${participant['appliedAt']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (participant['reviewSubmitted']) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${participant['rating']}/5',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (participant['status'] == 'pending') ...[
                  Expanded(
                    child: CustomButton(
                      text: '승인',
                      onPressed: () => _approveParticipant(participant),
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: '거절',
                      onPressed: () => _rejectParticipant(participant),
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    ),
                  ),
                ] else if (participant['status'] == 'approved') ...[
                  Expanded(
                    child: CustomButton(
                      text: '리뷰 확인',
                      onPressed: () => _viewReview(participant),
                      backgroundColor: const Color(0xFF137fec),
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveParticipant(Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참여자 승인'),
        content: Text('${participant['name']}님을 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${participant['name']}님이 승인되었습니다')),
              );
            },
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  void _rejectParticipant(Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('참여자 거절'),
        content: Text('${participant['name']}님을 거절하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${participant['name']}님이 거절되었습니다')),
              );
            },
            child: const Text('거절', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewReview(Map<String, dynamic> participant) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('리뷰 확인 기능은 준비 중입니다')));
  }
}
