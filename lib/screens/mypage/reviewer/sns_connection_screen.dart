import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/custom_button.dart';

class SNSConnectionScreen extends ConsumerStatefulWidget {
  const SNSConnectionScreen({super.key});

  @override
  ConsumerState<SNSConnectionScreen> createState() =>
      _SNSConnectionScreenState();
}

class _SNSConnectionScreenState extends ConsumerState<SNSConnectionScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _snsConnections = {};

  @override
  void initState() {
    super.initState();
    _loadSNSConnections();
  }

  Future<void> _loadSNSConnections() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _snsConnections = {
        'instagram': {
          'connected': true,
          'username': '@hong_gildong',
          'followers': 1250,
        },
        'youtube': {
          'connected': true,
          'username': '홍길동 리뷰',
          'subscribers': 3200,
        },
        'tiktok': {'connected': false, 'username': null, 'followers': null},
        'blog': {
          'connected': true,
          'username': 'honggildong.blog.me',
          'followers': 850,
        },
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('SNS 연결'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSNSContent(),
    );
  }

  Widget _buildSNSContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 설명 카드
          _buildInfoCard(),

          const SizedBox(height: 24),

          // SNS 연결 목록
          _buildSNSList(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'SNS 연결 안내',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'SNS 계정을 연결하면 더 많은 캠페인에 참여할 수 있습니다.\n연결된 계정의 팔로워 수에 따라 다양한 혜택을 받을 수 있어요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSNSList() {
    final snsList = [
      {
        'key': 'instagram',
        'name': 'Instagram',
        'icon': Icons.camera_alt,
        'color': const Color(0xFFE4405F),
        'description': '인스타그램 계정 연결',
      },
      {
        'key': 'youtube',
        'name': 'YouTube',
        'icon': Icons.play_circle_filled,
        'color': const Color(0xFFFF0000),
        'description': '유튜브 채널 연결',
      },
      {
        'key': 'tiktok',
        'name': 'TikTok',
        'icon': Icons.music_note,
        'color': const Color(0xFF000000),
        'description': '틱톡 계정 연결',
      },
      {
        'key': 'blog',
        'name': '네이버 블로그',
        'icon': Icons.article,
        'color': const Color(0xFF03C75A),
        'description': '네이버 블로그 연결',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '연결된 SNS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        ...snsList.map((sns) => _buildSNSItem(sns)).toList(),
      ],
    );
  }

  Widget _buildSNSItem(Map<String, dynamic> sns) {
    final snsData = _snsConnections[sns['key']];
    final isConnected = snsData['connected'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: sns['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(sns['icon'], color: sns['color'], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sns['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                if (isConnected) ...[
                  Text(
                    snsData['username'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '팔로워 ${snsData['followers'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}명',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ] else
                  Text(
                    sns['description'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          if (isConnected)
            CustomButton(
              text: '연결 해제',
              onPressed: () => _disconnectSNS(sns['key']),
              backgroundColor: Colors.red[50],
              textColor: Colors.red[700],
              borderColor: Colors.red[200],
            )
          else
            CustomButton(
              text: '연결하기',
              onPressed: () => _connectSNS(sns['key']),
              backgroundColor: sns['color'],
              textColor: Colors.white,
            ),
        ],
      ),
    );
  }

  void _connectSNS(String snsKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getSNSName(snsKey)} 연결'),
        content: const Text('SNS 연결 기능은 준비 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _disconnectSNS(String snsKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getSNSName(snsKey)} 연결 해제'),
        content: const Text('정말로 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_getSNSName(snsKey)} 연결이 해제되었습니다')),
              );
            },
            child: const Text('해제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getSNSName(String key) {
    switch (key) {
      case 'instagram':
        return 'Instagram';
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'blog':
        return '네이버 블로그';
      default:
        return 'SNS';
    }
  }
}
