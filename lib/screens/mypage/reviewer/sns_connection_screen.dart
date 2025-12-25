import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/sns_platform_connection_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/mypage_common_widgets.dart';

class SNSConnectionScreen extends ConsumerStatefulWidget {
  const SNSConnectionScreen({super.key});

  @override
  ConsumerState<SNSConnectionScreen> createState() =>
      _SNSConnectionScreenState();
}

class _SNSConnectionScreenState extends ConsumerState<SNSConnectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _connections = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSNSConnections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSNSConnections({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connections = await SNSPlatformConnectionService.getConnections(
        forceRefresh: forceRefresh,
      );
      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '연결 정보를 불러오는데 실패했습니다: ${SNSPlatformConnectionService.getErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getStoreConnections() {
    return _connections.where((conn) {
      return SNSPlatformConnectionService.isStorePlatform(
        conn['platform'] as String,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getSNSConnections() {
    return _connections.where((conn) {
      return !SNSPlatformConnectionService.isStorePlatform(
        conn['platform'] as String,
      );
    }).toList();
  }

  Future<void> _showAddDialog(String platform) async {
    final platformName = SNSPlatformConnectionService.getPlatformDisplayName(
      platform,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformConnectionDialog(
        platform: platform,
        platformName: platformName,
      ),
    );

    if (result == true && mounted) {
      await _loadSNSConnections(forceRefresh: true);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> connection) async {
    final platform = connection['platform'] as String;
    final platformName = SNSPlatformConnectionService.getPlatformDisplayName(
      platform,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformConnectionDialog(
        platform: platform,
        platformName: platformName,
        connectionId: connection['id'] as String,
        initialData: connection,
        isEditMode: true,
      ),
    );

    if (result == true && mounted) {
      await _loadSNSConnections(forceRefresh: true);
    }
  }

  Future<void> _deleteConnection(String id, String platformName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$platformName 연결 해제'),
        content: const Text('정말로 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SNSPlatformConnectionService.deleteConnection(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$platformName 연결이 해제되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadSNSConnections(forceRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '삭제 실패: ${SNSPlatformConnectionService.getErrorMessage(e)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('SNS 연결'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/reviewer'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '스토어 플랫폼'),
            Tab(text: 'SNS 플랫폼'),
          ],
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadSNSConnections(forceRefresh: true),
              child: TabBarView(
                controller: _tabController,
                children: [_buildStoreTab(), _buildSNSTab()],
              ),
            ),
    );
  }

  Widget _buildStoreTab() {
    final storeConnections = _getStoreConnections();
    final storePlatforms = SNSPlatformConnectionService.storePlatforms
        .where(
          (platform) =>
              !['11번가', '지마켓', '옥션', '위메프'].contains(platform),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            '스토어 플랫폼 연결',
            '쇼핑몰 계정을 연결하면 상품 리뷰 캠페인에 참여할 수 있습니다.\n배송 주소를 정확히 입력해주세요.',
          ),
          const SizedBox(height: 24),
          ...storePlatforms.map((platform) {
            final platformConnections = storeConnections
                .where((conn) => conn['platform'] == platform)
                .toList();
            return _buildPlatformSection(platform, platformConnections);
          }),
        ],
      ),
    );
  }

  Widget _buildSNSTab() {
    final snsConnections = _getSNSConnections();
    final snsPlatforms = SNSPlatformConnectionService.snsPlatforms
        .where((platform) => !['틱톡', '네이버'].contains(platform))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'SNS 플랫폼 연결',
            'SNS 계정을 연결하면 더 많은 캠페인에 참여할 수 있습니다.\n연결된 계정의 팔로워 수에 따라 다양한 혜택을 받을 수 있어요.',
          ),
          const SizedBox(height: 24),
          ...snsPlatforms.map((platform) {
            final platformConnections = snsConnections
                .where((conn) => conn['platform'] == platform)
                .toList();
            return _buildPlatformSection(platform, platformConnections);
          }),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String description) {
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
                title,
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
            description,
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

  Widget _buildPlatformSection(
    String platform,
    List<Map<String, dynamic>> connections,
  ) {
    final platformName = SNSPlatformConnectionService.getPlatformDisplayName(
      platform,
    );
    final platformIcon = SNSPlatformConnectionService.getPlatformIcon(platform);
    final platformColor = SNSPlatformConnectionService.getPlatformColor(
      platform,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 플랫폼 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: platformColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(platformIcon, color: platformColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      if (connections.isNotEmpty)
                        Text(
                          '${connections.length}개 연결됨',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                CustomButton(
                  text: '추가',
                  onPressed: () => _showAddDialog(platform),
                  backgroundColor: platformColor,
                  textColor: Colors.white,
                ),
              ],
            ),
          ),
          // 연결 목록
          if (connections.isNotEmpty)
            ...connections.map(
              (connection) => _buildConnectionItem(connection, platformColor),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionItem(
    Map<String, dynamic> connection,
    Color platformColor,
  ) {
    final platform = connection['platform'] as String;
    final platformName = SNSPlatformConnectionService.getPlatformDisplayName(
      platform,
    );
    final accountId = connection['platform_account_id'] as String? ?? '';
    final accountName = connection['platform_account_name'] as String? ?? '';
    final phone = connection['phone'] as String? ?? '';
    final address = connection['address'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName.isNotEmpty ? accountName : accountId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (accountId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '계정 ID: $accountId',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '전화번호: $phone',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '주소: $address',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  CustomButton(
                    text: '수정',
                    onPressed: () => _showEditDialog(connection),
                    backgroundColor: Colors.grey[100]!,
                    textColor: Colors.black,
                    borderColor: Colors.grey[300]!,
                  ),
                  const SizedBox(width: 8),
                  CustomButton(
                    text: '삭제',
                    onPressed: () => _deleteConnection(
                      connection['id'] as String,
                      platformName,
                    ),
                    backgroundColor: Colors.red[50]!,
                    textColor: Colors.red[700]!,
                    borderColor: Colors.red[200]!,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
