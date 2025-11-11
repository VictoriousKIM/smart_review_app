import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;
import '../../widgets/custom_button.dart';

class AdvertisementInquiryScreen extends ConsumerStatefulWidget {
  const AdvertisementInquiryScreen({super.key});

  @override
  ConsumerState<AdvertisementInquiryScreen> createState() =>
      _AdvertisementInquiryScreenState();
}

class _AdvertisementInquiryScreenState
    extends ConsumerState<AdvertisementInquiryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inquiries = [];

  @override
  void initState() {
    super.initState();
    _loadInquiries();
  }

  Future<void> _loadInquiries() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _inquiries = [
        {
          'id': '1',
          'title': '신제품 런칭 캠페인 문의',
          'content': '새로운 스마트워치 제품 런칭을 위한 캠페인을 진행하고 싶습니다.',
          'status': 'pending',
          'statusText': '답변 대기',
          'createdAt': '2024-01-15',
          'category': 'campaign',
          'categoryText': '캠페인 문의',
        },
        {
          'id': '2',
          'title': '광고비 정산 관련 문의',
          'content': '지난 달 광고비 정산에 대해 문의드립니다.',
          'status': 'answered',
          'statusText': '답변 완료',
          'createdAt': '2024-01-10',
          'category': 'billing',
          'categoryText': '정산 문의',
        },
        {
          'id': '3',
          'title': '리뷰어 품질 관리 방안',
          'content': '리뷰어 품질 관리를 위한 방안에 대해 문의드립니다.',
          'status': 'processing',
          'statusText': '처리중',
          'createdAt': '2024-01-08',
          'category': 'quality',
          'categoryText': '품질 관리',
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
        title: const Text('광고문의'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final user = ref.read(currentUserProvider).value;
            if (user != null) {
              if (user.userType == app_user.UserType.admin) {
                context.go('/mypage/admin');
              } else if (user.companyId != null) {
                context.go('/mypage/advertiser');
              } else {
                context.go('/mypage/reviewer');
              }
            } else {
              context.go('/mypage');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showCreateInquiryDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inquiries.isEmpty
          ? _buildEmptyState()
          : _buildInquiriesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '문의 내역이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '광고 관련 문의사항이 있으시면 언제든 문의해주세요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: '문의하기',
            onPressed: () {
              _showCreateInquiryDialog();
            },
            backgroundColor: const Color(0xFF137fec),
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildInquiriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inquiries.length,
      itemBuilder: (context, index) {
        final inquiry = _inquiries[index];
        return _buildInquiryCard(inquiry);
      },
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inquiry) {
    Color statusColor;
    switch (inquiry['status']) {
      case 'answered':
        statusColor = Colors.green;
        break;
      case 'processing':
        statusColor = Colors.orange;
        break;
      case 'pending':
        statusColor = Colors.blue;
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                inquiry['statusText'],
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                inquiry['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                inquiry['categoryText'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              inquiry['content'],
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              inquiry['createdAt'],
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        onTap: () => _showInquiryDetail(inquiry),
      ),
    );
  }

  void _showCreateInquiryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문의하기'),
        content: const Text('문의 작성 기능은 준비 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showInquiryDetail(Map<String, dynamic> inquiry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(inquiry['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inquiry['content']),
            const SizedBox(height: 16),
            Text(
              '카테고리: ${inquiry['categoryText']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '작성일: ${inquiry['createdAt']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '상태: ${inquiry['statusText']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
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
