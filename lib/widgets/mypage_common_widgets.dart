import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sns_platform_connection_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../widgets/address_form_field.dart';

class MyPageCommonWidgets {
  // 상단 파란색 카드
  static Widget buildTopCard({
    required String userName,
    required String userType,
    required VoidCallback onSwitchPressed,
    required String switchButtonText,
    bool showRating = false,
    VoidCallback? onProfileTap,
    VoidCallback? onPointsTap,
    int? currentPoints,
    bool isLoadingPoints = false,
    bool showAdminButton = false,
    VoidCallback? onAdminPressed,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF137fec),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 사용자 정보 - 클릭 가능하게 변경
              Expanded(
                child: InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(8),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userType,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 버튼들 (전환 버튼 + 관리자 버튼)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 관리자 전환 버튼 (관리자일 때만 표시)
                  if (showAdminButton && onAdminPressed != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: onAdminPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.admin_panel_settings, size: 16),
                            const SizedBox(width: 4),
                            const Text('관리자 전환'),
                          ],
                        ),
                      ),
                    ),
                  // 전환 버튼 (흰색 배경)
                  ElevatedButton(
                    onPressed: onSwitchPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF137fec),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: const Color(0xFF137fec).withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(switchButtonText),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 포인트 정보 - 클릭 가능하게 변경
          InkWell(
            onTap: onPointsTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 왼쪽: 보유 포인트 라벨
                  const Text(
                    '보유 포인트',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  // 오른쪽: 포인트 값 + 화살표 아이콘
                  Row(
                    children: [
                      if (isLoadingPoints)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        Text(
                          currentPoints != null
                              ? '${WalletService.formatPoints(currentPoints)}P'
                              : '0P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 캠페인 상태 섹션
  static Widget buildCampaignStatusSection({
    required List<Map<String, String>> statusItems,
    String? actionButtonText,
    VoidCallback? onActionPressed,
    Function(String)? onStatusTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF137fec),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '나의 캠페인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (actionButtonText != null && onActionPressed != null)
                ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137fec),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(actionButtonText),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: _buildStatusRow(statusItems, onStatusTap)),
          ),
        ],
      ),
    );
  }

  // 상태 아이템들 생성
  static List<Widget> _buildStatusRow(
    List<Map<String, String>> statusItems,
    Function(String)? onStatusTap,
  ) {
    List<Widget> widgets = [];
    for (int i = 0; i < statusItems.length; i++) {
      widgets.add(
        _buildStatusItem(
          statusItems[i]['label']!,
          statusItems[i]['count']!,
          statusItems[i]['tab'] ?? '',
          onStatusTap,
        ),
      );
      if (i < statusItems.length - 1) {
        widgets.add(_buildStatusDivider());
      }
    }
    return widgets;
  }

  static Widget _buildStatusItem(
    String label,
    String count,
    String tab,
    Function(String)? onStatusTap,
  ) {
    final content = Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onStatusTap != null && tab.isNotEmpty) {
      return Expanded(
        child: InkWell(
          onTap: () => onStatusTap(tab),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return content;
  }

  static Widget _buildStatusDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // 알림 섹션
  static Widget buildNotificationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.black,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                '알림 0개',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            '전체알림 >',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // SNS 연결 섹션
  static Widget buildSNSConnectionSection(BuildContext context) {
    return SNSConnectionSection(key: ValueKey('sns_connection_section'));
  }
}

// SNS 연결 섹션 위젯 (확장 가능)
class SNSConnectionSection extends StatefulWidget {
  const SNSConnectionSection({super.key});

  @override
  State<SNSConnectionSection> createState() => _SNSConnectionSectionState();
}

class _SNSConnectionSectionState extends State<SNSConnectionSection> {
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = false;
  // 각 플랫폼별 확장 상태 관리
  final Map<String, bool> _expandedPlatforms = {};

  // 플랫폼 정보 (한글 ID 사용)
  final List<Map<String, dynamic>> _platforms = [
    {
      'id': '쿠팡',
      'name': '쿠팡',
      'icon': Icons.shopping_cart,
      'color': const Color(0xFFFF6B00),
    },
    {
      'id': 'N스토어',
      'name': 'N스토어',
      'icon': Icons.store,
      'color': const Color(0xFF137fec),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections({bool forceRefresh = false}) async {
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  int _getConnectionCount(String platform) {
    return _connections.where((conn) => conn['platform'] == platform).length;
  }

  List<Map<String, dynamic>> _getConnectionsByPlatform(String platform) {
    return _connections.where((conn) => conn['platform'] == platform).toList();
  }

  void _showAddDialog(String platform, String platformName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformConnectionDialog(
        platform: platform,
        platformName: platformName,
      ),
    );

    if (result == true && mounted) {
      // 연결이 성공적으로 추가되었으므로 목록 새로고침
      await _loadConnections();
      // 해당 플랫폼 확장 상태로 변경
      setState(() {
        _expandedPlatforms[platform] = true;
      });
    }
  }

  bool _isPlatformExpanded(String platformId) {
    return _expandedPlatforms[platformId] ?? false;
  }

  void _togglePlatform(String platformId) {
    setState(() {
      _expandedPlatforms[platformId] = !_isPlatformExpanded(platformId);
    });
  }

  Future<void> _deleteConnection(String id) async {
    try {
      await SNSPlatformConnectionService.deleteConnection(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연결이 삭제되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // 삭제된 연결의 플랫폼 찾기
        final deletedConnection = _connections.firstWhere(
          (conn) => conn['id'] == id,
          orElse: () => {},
        );
        final platform = deletedConnection['platform'] as String?;

        // 연결 목록 새로고침
        await _loadConnections(forceRefresh: true);

        // 삭제된 플랫폼의 확장 상태 닫기
        if (platform != null) {
          setState(() {
            _expandedPlatforms[platform] = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '삭제 실패: ${SNSPlatformConnectionService.getErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalConnections = _connections.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (항상 표시)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.black, size: 20),
                const SizedBox(width: 12),
                Text(
                  'SNS 연결',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (totalConnections > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF137fec),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalConnections개 연결됨',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    context.go('/mypage/reviewer/sns');
                  },
                  child: const Text(
                    '추가',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // 플랫폼 목록
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _platforms
                    .where((platform) {
                      final platformId = platform['id'] as String;
                      final connectionCount = _getConnectionCount(platformId);
                      // 데이터가 있는 플랫폼만 표시
                      return connectionCount > 0;
                    })
                    .map((platform) {
                      final platformId = platform['id'] as String;
                      final platformName = platform['name'] as String;
                      final platformIcon = platform['icon'] as IconData;
                      final platformColor = platform['color'] as Color;
                      final connectionCount = _getConnectionCount(platformId);
                      final connections = _getConnectionsByPlatform(platformId);
                      final isExpanded = _isPlatformExpanded(platformId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 플랫폼 헤더 (탭 가능)
                          InkWell(
                            onTap: () => _togglePlatform(platformId),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: platformColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          platformIcon,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        platformName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      if (connectionCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '$connectionCount개',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _showAddDialog(
                                          platformId,
                                          platformName,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: platformColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('추가'),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 플랫폼별 확장된 연결 정보
                          if (isExpanded)
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),
                                  if (connections.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        '연결된 계정이 없습니다.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    )
                                  else
                                    ...connections.map((connection) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        connection['platform_account_name'] ??
                                                            '알 수 없음',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '계정 ID: ${connection['platform_account_id'] ?? ''}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                      if (connection['phone'] !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '전화번호: ${connection['phone']}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                      if (connection['address'] !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '주소: ${connection['address']}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                      if (connection['return_address'] !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '회수 주소: ${connection['return_address']}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        color: Colors.blue,
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        _showEditDialog(
                                                          context,
                                                          connection,
                                                          platformName,
                                                        );
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        _showDeleteConfirmDialog(
                                                          context,
                                                          connection['id']
                                                              as String,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          if (_platforms.indexOf(platform) <
                              _platforms.length - 1)
                            const SizedBox(height: 12),
                        ],
                      );
                    })
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    Map<String, dynamic> connection,
    String platformName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformConnectionDialog(
        platform: connection['platform'] as String,
        platformName: platformName,
        connectionId: connection['id'] as String,
        initialData: connection,
        isEditMode: true,
      ),
    );

    if (result == true && mounted) {
      // 연결이 성공적으로 수정되었으므로 목록 새로고침
      await _loadConnections(forceRefresh: true);
      // 수정된 플랫폼의 확장 상태 유지
      final platform = connection['platform'] as String;
      setState(() {
        _expandedPlatforms[platform] = true;
      });
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, String connectionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('연결 삭제'),
        content: const Text('이 연결을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteConnection(connectionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// 플랫폼 연결 다이얼로그 위젯
class PlatformConnectionDialog extends StatefulWidget {
  final String platform;
  final String platformName;
  final String? connectionId;
  final Map<String, dynamic>? initialData;
  final bool isEditMode;

  const PlatformConnectionDialog({
    super.key,
    required this.platform,
    required this.platformName,
    this.connectionId,
    this.initialData,
    this.isEditMode = false,
  });

  @override
  State<PlatformConnectionDialog> createState() =>
      _PlatformConnectionDialogState();
}

class _PlatformConnectionDialogState extends State<PlatformConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountIdController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryBaseAddressController = TextEditingController(); // 배송 기본주소
  final _deliveryDetailAddressController = TextEditingController(); // 배송 상세주소
  final _returnBaseAddressController = TextEditingController(); // 반품 기본주소
  final _returnDetailAddressController = TextEditingController(); // 반품 상세주소
  bool _isLoading = false;
  bool _useProfileInfo = false; // 내 프로필 정보 넣기 체크박스
  String? _profileName; // 프로필 이름
  String? _profilePhone; // 프로필 전화번호
  String? _profileAddress; // 프로필 주소

  @override
  void initState() {
    super.initState();
    // 수정 모드일 때 기존 데이터로 초기화
    if (widget.isEditMode && widget.initialData != null) {
      _accountIdController.text =
          widget.initialData!['platform_account_id'] ?? '';
      _accountNameController.text =
          widget.initialData!['platform_account_name'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';

      // 주소 분리 (기본주소 + 상세주소)
      final address = widget.initialData!['address'] as String?;
      if (address != null && address.isNotEmpty) {
        final lastSpaceIndex = address.lastIndexOf(' ');
        if (lastSpaceIndex > 0 && lastSpaceIndex < address.length - 1) {
          _deliveryBaseAddressController.text = address.substring(
            0,
            lastSpaceIndex,
          );
          _deliveryDetailAddressController.text = address.substring(
            lastSpaceIndex + 1,
          );
        } else {
          _deliveryBaseAddressController.text = address;
        }
      }

      // 반품주소 분리
      final returnAddress = widget.initialData!['return_address'] as String?;
      if (returnAddress != null && returnAddress.isNotEmpty) {
        final lastSpaceIndex = returnAddress.lastIndexOf(' ');
        if (lastSpaceIndex > 0 && lastSpaceIndex < returnAddress.length - 1) {
          _returnBaseAddressController.text = returnAddress.substring(
            0,
            lastSpaceIndex,
          );
          _returnDetailAddressController.text = returnAddress.substring(
            lastSpaceIndex + 1,
          );
        } else {
          _returnBaseAddressController.text = returnAddress;
        }
      }
    } else {
      // 추가 모드일 때 프로필 정보 로드
      _loadProfileInfo();
    }
  }

  /// 프로필 정보 로드
  Future<void> _loadProfileInfo() async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      // users 테이블에서 프로필 정보 조회
      final response = await Supabase.instance.client
          .from('users')
          .select('display_name, phone, address')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _profileName = response['display_name'] as String?;
          _profilePhone = response['phone'] as String?;
          _profileAddress = response['address'] as String?;
        });
      }
    } catch (e) {
      debugPrint('프로필 정보 로드 실패: $e');
    }
  }

  /// 프로필 정보로 자동 입력
  void _fillProfileInfo() {
    if (_profileName != null && _profileName!.isNotEmpty) {
      _accountNameController.text = _profileName!;
    }
    if (_profilePhone != null && _profilePhone!.isNotEmpty) {
      _phoneController.text = _profilePhone!;
    }
    if (_profileAddress != null && _profileAddress!.isNotEmpty) {
      // 주소를 기본주소와 상세주소로 분리
      final address = _profileAddress!.trim();
      final lastSpaceIndex = address.lastIndexOf(' ');
      if (lastSpaceIndex > 0 && lastSpaceIndex < address.length - 1) {
        _deliveryBaseAddressController.text = address.substring(
          0,
          lastSpaceIndex,
        );
        _deliveryDetailAddressController.text = address.substring(
          lastSpaceIndex + 1,
        );
      } else {
        _deliveryBaseAddressController.text = address;
      }
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _accountNameController.dispose();
    _phoneController.dispose();
    _deliveryBaseAddressController.dispose();
    _deliveryDetailAddressController.dispose();
    _returnBaseAddressController.dispose();
    _returnDetailAddressController.dispose();
    super.dispose();
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 주소 합치기 (기본주소 + 상세주소)
      final deliveryBaseAddress = _deliveryBaseAddressController.text.trim();
      final deliveryDetailAddress = _deliveryDetailAddressController.text
          .trim();
      final fullDeliveryAddress = deliveryBaseAddress.isNotEmpty
          ? (deliveryDetailAddress.isNotEmpty
                ? '$deliveryBaseAddress $deliveryDetailAddress'
                : deliveryBaseAddress)
          : null;

      final returnBaseAddress = _returnBaseAddressController.text.trim();
      final returnDetailAddress = _returnDetailAddressController.text.trim();
      final fullReturnAddress = returnBaseAddress.isNotEmpty
          ? (returnDetailAddress.isNotEmpty
                ? '$returnBaseAddress $returnDetailAddress'
                : returnBaseAddress)
          : null;

      if (widget.isEditMode && widget.connectionId != null) {
        // 수정 모드: updateConnection 호출
        await SNSPlatformConnectionService.updateConnection(
          id: widget.connectionId!,
          platformAccountName: _accountNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: fullDeliveryAddress,
          returnAddress: fullReturnAddress,
        );

        if (mounted) {
          Navigator.of(context).pop(true); // 성공 시 true 반환
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.platformName} 연결이 수정되었습니다'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 생성 모드: createConnection 호출
        await SNSPlatformConnectionService.createConnection(
          platform: widget.platform,
          platformAccountId: _accountIdController.text.trim(),
          platformAccountName: _accountNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: fullDeliveryAddress,
          returnAddress: fullReturnAddress,
        );

        if (mounted) {
          Navigator.of(context).pop(true); // 성공 시 true 반환
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.platformName} 연결이 완료되었습니다'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SNSPlatformConnectionService.getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.link,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isEditMode
                ? '${widget.platformName} 연결 수정'
                : '${widget.platformName} 연결',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _accountIdController,
                  enabled: !widget.isEditMode, // 수정 모드에서는 읽기 전용
                  decoration: const InputDecoration(
                    labelText: '계정 ID',
                    hintText: '플랫폼 계정 ID를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!widget.isEditMode &&
                        (value == null || value.trim().isEmpty)) {
                      return '계정 ID를 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // 내 프로필 정보 넣기 체크박스 (추가 모드일 때만 표시)
                if (!widget.isEditMode &&
                    (_profileName != null ||
                        _profilePhone != null ||
                        _profileAddress != null))
                  CheckboxListTile(
                    title: const Text('내 프로필 정보 넣기'),
                    value: _useProfileInfo,
                    onChanged: (value) {
                      setState(() {
                        _useProfileInfo = value ?? false;
                        if (_useProfileInfo) {
                          _fillProfileInfo();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                if (!widget.isEditMode &&
                    (_profileName != null ||
                        _profilePhone != null ||
                        _profileAddress != null))
                  const SizedBox(height: 16),
                TextFormField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(
                    labelText: '계정 이름',
                    hintText: '플랫폼에 표시되는 이름',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '계정 이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '전화번호',
                    hintText: '010-1234-5678',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '전화번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
                // 스토어 플랫폼인 경우에만 주소 입력 필드 표시
                if (SNSPlatformConnectionService.isStorePlatform(
                  widget.platform,
                )) ...[
                  const SizedBox(height: 16),
                  AddressFormField(
                    deliveryBaseAddressController:
                        _deliveryBaseAddressController,
                    deliveryDetailAddressController:
                        _deliveryDetailAddressController,
                    returnBaseAddressController: _returnBaseAddressController,
                    returnDetailAddressController:
                        _returnDetailAddressController,
                    isDeliveryAddressRequired: true,
                    showReturnAddress: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveConnection,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
