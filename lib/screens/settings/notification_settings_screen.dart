import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;
  Map<String, bool> _notificationSettings = {};

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _notificationSettings = {
        'pushNotifications': true,
        'emailNotifications': true,
        'campaignUpdates': true,
        'reviewReminders': true,
        'paymentNotifications': true,
        'systemAnnouncements': true,
        'marketingEmails': false,
        'weeklyReports': true,
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('알림 설정'),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildNotificationSettings(),
    );
  }

  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전체 알림 설정
          _buildNotificationSection('전체 알림', [
            {
              'key': 'pushNotifications',
              'title': '푸시 알림',
              'description': '앱에서 발생하는 모든 알림을 받습니다',
              'icon': Icons.notifications_active_outlined,
            },
            {
              'key': 'emailNotifications',
              'title': '이메일 알림',
              'description': '중요한 알림을 이메일로 받습니다',
              'icon': Icons.email_outlined,
            },
          ]),

          const SizedBox(height: 24),

          // 캠페인 관련 알림
          _buildNotificationSection('캠페인 관련', [
            {
              'key': 'campaignUpdates',
              'title': '캠페인 업데이트',
              'description': '캠페인 상태 변경 및 새로운 캠페인 알림',
              'icon': Icons.campaign_outlined,
            },
            {
              'key': 'reviewReminders',
              'title': '리뷰 작성 알림',
              'description': '리뷰 작성 마감일 알림',
              'icon': Icons.star_outline,
            },
          ]),

          const SizedBox(height: 24),

          // 결제 및 정산
          _buildNotificationSection('결제 및 정산', [
            {
              'key': 'paymentNotifications',
              'title': '결제 알림',
              'description': '포인트 충전, 출금 등 결제 관련 알림',
              'icon': Icons.payment_outlined,
            },
          ]),

          const SizedBox(height: 24),

          // 시스템 및 마케팅
          _buildNotificationSection('시스템 및 마케팅', [
            {
              'key': 'systemAnnouncements',
              'title': '시스템 공지',
              'description': '시스템 점검, 업데이트 등 공지사항',
              'icon': Icons.announcement_outlined,
            },
            {
              'key': 'marketingEmails',
              'title': '마케팅 이메일',
              'description': '이벤트, 프로모션 등 마케팅 정보',
              'icon': Icons.campaign_outlined,
            },
            {
              'key': 'weeklyReports',
              'title': '주간 리포트',
              'description': '주간 활동 요약 리포트',
              'icon': Icons.assessment_outlined,
            },
          ]),

          const SizedBox(height: 32),

          // 설정 초기화 버튼
          _buildResetButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationSection(
    String title,
    List<Map<String, dynamic>> items,
  ) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildNotificationItem(item)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    final key = item['key'] as String;
    final isEnabled = _notificationSettings[key] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(item['icon'] as IconData, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['description'] as String,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (value) {
              setState(() {
                _notificationSettings[key] = value;
              });
              _saveNotificationSetting(key, value);
            },
            activeThumbColor: const Color(0xFF137fec),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _showResetDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red[700],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.red[200]!),
          ),
        ),
        child: const Text(
          '알림 설정 초기화',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _saveNotificationSetting(String key, bool value) {
    // TODO: 실제 API 호출로 설정 저장
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_getSettingName(key)} 설정이 ${value ? '활성화' : '비활성화'}되었습니다',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 설정 초기화'),
        content: const Text('모든 알림 설정을 기본값으로 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetNotificationSettings();
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _resetNotificationSettings() {
    setState(() {
      _notificationSettings = {
        'pushNotifications': true,
        'emailNotifications': true,
        'campaignUpdates': true,
        'reviewReminders': true,
        'paymentNotifications': true,
        'systemAnnouncements': true,
        'marketingEmails': false,
        'weeklyReports': true,
      };
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(
      content: Text('알림 설정이 초기화되었습니다'),
      duration: Duration(seconds: 2),
    ));
  }

  String _getSettingName(String key) {
    switch (key) {
      case 'pushNotifications':
        return '푸시 알림';
      case 'emailNotifications':
        return '이메일 알림';
      case 'campaignUpdates':
        return '캠페인 업데이트';
      case 'reviewReminders':
        return '리뷰 작성 알림';
      case 'paymentNotifications':
        return '결제 알림';
      case 'systemAnnouncements':
        return '시스템 공지';
      case 'marketingEmails':
        return '마케팅 이메일';
      case 'weeklyReports':
        return '주간 리포트';
      default:
        return '알림';
    }
  }
}
