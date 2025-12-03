import 'package:flutter/material.dart';
import '../../widgets/signup_platform_connection_dialog.dart';

/// 리뷰어 회원가입 - SNS 연결 폼
class ReviewerSignupSNSForm extends StatefulWidget {
  final List<Map<String, dynamic>> initialSnsConnections;
  final String? profileName; // 프로필 이름
  final String? profilePhone; // 프로필 전화번호
  final String? profileAddress; // 프로필 주소 (전체주소)
  final Function(List<Map<String, dynamic>>) onComplete;

  const ReviewerSignupSNSForm({
    super.key,
    this.initialSnsConnections = const [],
    this.profileName,
    this.profilePhone,
    this.profileAddress,
    required this.onComplete,
  });

  @override
  State<ReviewerSignupSNSForm> createState() => _ReviewerSignupSNSFormState();
}

class _ReviewerSignupSNSFormState extends State<ReviewerSignupSNSForm> {
  late List<Map<String, dynamic>> _snsConnections;

  @override
  void initState() {
    super.initState();
    // 초기 SNS 연결 정보 복원
    _snsConnections = List<Map<String, dynamic>>.from(
      widget.initialSnsConnections,
    );
  }

  /// 플랫폼 연결 추가
  Future<void> _addPlatformConnection(String platform) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => SignupPlatformConnectionDialog(
        platform: platform,
        platformName: _getPlatformDisplayName(platform),
        profileName: widget.profileName,
        profilePhone: widget.profilePhone,
        profileAddress: widget.profileAddress,
      ),
    );

    if (result != null && mounted) {
      // 중복 검증: 계정 ID 중복 확인
      final accountId = result['platform_account_id'] as String?;
      final existingAccount = _snsConnections.any(
        (conn) =>
            conn['platform'] == platform &&
            conn['platform_account_id'] == accountId,
      );

      if (existingAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_getPlatformDisplayName(platform)}에 이미 등록된 계정 ID입니다',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 중복 검증: 배송주소 중복 확인 (스토어 플랫폼만)
      final address = result['address'] as String?;
      if (address != null && address.isNotEmpty) {
        final existingAddress = _snsConnections.any(
          (conn) => conn['platform'] == platform && conn['address'] == address,
        );

        if (existingAddress) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getPlatformDisplayName(platform)}에 이미 등록된 배송주소입니다',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _snsConnections.add(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getPlatformDisplayName(platform)} 연결이 추가되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getPlatformDisplayName(String platform) {
    const platformNames = {
      'blog': '네이버 블로그',
      'instagram': '인스타그램',
      'coupang': '쿠팡',
      'smartstore': '스마트스토어',
      'kakao': '카카오',
    };
    return platformNames[platform.toLowerCase()] ?? platform;
  }

  // 스토어 플랫폼 목록 (회원가입용)
  static const List<String> _storePlatforms = [
    'coupang',
    'smartstore',
    'kakao',
  ];

  // SNS 플랫폼 목록 (회원가입용)
  static const List<String> _snsPlatforms = ['blog', 'instagram'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            'SNS 연결',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '리뷰 활동에 사용할 SNS 계정을 연결해주세요 (선택)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 64),
          // 스토어 플랫폼 목록 (위로 이동)
          _buildPlatformList('스토어 플랫폼', _storePlatforms),
          const SizedBox(height: 24),
          // SNS 플랫폼 목록
          _buildPlatformList('SNS 플랫폼', _snsPlatforms),
          const SizedBox(height: 32),
          // 다음 버튼
          ElevatedButton(
            onPressed: () {
              widget.onComplete(_snsConnections);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '다음',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformList(String title, List<String> platforms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...platforms.map((platform) => _buildPlatformItem(platform)),
      ],
    );
  }

  Widget _buildPlatformItem(String platform) {
    final connections = _snsConnections
        .where((conn) => conn['platform'] == platform)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 플랫폼 추가 버튼 (항상 표시)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(_getPlatformDisplayName(platform)),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => _addPlatformConnection(platform),
          ),
        ),
        // 추가된 연결 목록 표시
        if (connections.isNotEmpty)
          ...connections.asMap().entries.map((entry) {
            final index = entry.key;
            final connection = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8, left: 16),
              color: Colors.grey[50],
              child: ListTile(
                title: Text(
                  connection['platform_account_name'] ?? '계정 이름 없음',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '계정 ID: ${connection['platform_account_id'] ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 변경 버튼
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editPlatformConnection(platform, index),
                      tooltip: '변경',
                    ),
                    // 삭제 버튼
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _deletePlatformConnection(platform, index),
                      tooltip: '삭제',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// 플랫폼 연결 수정
  Future<void> _editPlatformConnection(String platform, int index) async {
    final connection = _snsConnections
        .where((conn) => conn['platform'] == platform)
        .toList()[index];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => SignupPlatformConnectionDialog(
        platform: platform,
        platformName: _getPlatformDisplayName(platform),
        profileName: widget.profileName,
        profilePhone: widget.profilePhone,
        profileAddress: widget.profileAddress,
        initialData: connection, // 기존 데이터 전달
      ),
    );

    if (result != null && mounted) {
      final oldAccountId = connection['platform_account_id'] as String?;
      final newAccountId = result['platform_account_id'] as String?;
      final oldAddress = connection['address'] as String?;
      final newAddress = result['address'] as String?;

      // 중복 검증: 계정 ID 중복 확인 (자기 자신 제외)
      if (oldAccountId != newAccountId) {
        final existingAccount = _snsConnections.any(
          (conn) =>
              conn['platform'] == platform &&
              conn['platform_account_id'] == newAccountId &&
              conn != connection,
        ); // 자기 자신 제외

        if (existingAccount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getPlatformDisplayName(platform)}에 이미 등록된 계정 ID입니다',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // 중복 검증: 배송주소 중복 확인 (스토어 플랫폼만, 자기 자신 제외)
      if (newAddress != null &&
          newAddress.isNotEmpty &&
          oldAddress != newAddress) {
        final existingAddress = _snsConnections.any(
          (conn) =>
              conn['platform'] == platform &&
              conn['address'] == newAddress &&
              conn != connection,
        ); // 자기 자신 제외

        if (existingAddress) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getPlatformDisplayName(platform)}에 이미 등록된 배송주소입니다',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        // 해당 인덱스의 연결 찾아서 업데이트
        final allConnections = _snsConnections
            .where((conn) => conn['platform'] == platform)
            .toList();
        final globalIndex = _snsConnections.indexOf(allConnections[index]);
        if (globalIndex != -1) {
          _snsConnections[globalIndex] = result;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getPlatformDisplayName(platform)} 연결이 수정되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// 플랫폼 연결 삭제
  void _deletePlatformConnection(String platform, int index) {
    setState(() {
      final connections = _snsConnections
          .where((conn) => conn['platform'] == platform)
          .toList();
      if (index < connections.length) {
        final connectionToRemove = connections[index];
        _snsConnections.remove(connectionToRemove);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getPlatformDisplayName(platform)} 연결이 삭제되었습니다'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
