import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/company_user_service.dart';
import '../../../utils/user_type_helper.dart';
import '../../../widgets/custom_button.dart';

class PointsScreen extends ConsumerStatefulWidget {
  final String userType;

  const PointsScreen({super.key, required this.userType});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  bool _isLoading = true;
  int _currentPoints = 0;
  List<Map<String, dynamic>> _pointHistory = [];
  bool _isOwner = false; // 입금/출금 권한 여부
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadPointsData();
  }

  Future<void> _loadPointsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.currentUser;
      if (user == null) {
        setState(() {
          _currentPoints = 0;
          _pointHistory = [];
          _isLoading = false;
        });
        return;
      }

      // UserTypeHelper를 사용하여 리뷰어/광고주 구분
      final isReviewer = await UserTypeHelper.isReviewer(user.uid);
      final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);

      if (isReviewer) {
        // 리뷰어: 개인 지갑 조회
        final wallet = await WalletService.getUserWallet();
        _currentPoints = wallet?.currentPoints ?? 0;
        _isOwner = true; // 리뷰어는 항상 자신의 지갑에 대한 권한이 있음

        // 포인트 내역 조회
        final logs = await WalletService.getUserPointHistory(limit: 50);
        _pointHistory = logs
            .map(
              (log) => {
                'id': log.id,
                'type': log.amount > 0 ? 'earned' : 'spent',
                'amount': log.amount,
                'description': log.description ?? '포인트 거래',
                'date': _formatDate(log.createdAt),
                'transaction_category': 'campaign',
                'transaction_type': log.transactionType,
                'raw_data': {
                  'id': log.id,
                  'transaction_type': log.transactionType,
                  'amount': log.amount,
                  'description': log.description,
                  'created_at': log.createdAt.toIso8601String(),
                },
              },
            )
            .toList();
      } else {
        // 광고주: owner 여부 확인 후 지갑 조회
        if (isOwner) {
          // owner: 회사 지갑 조회
          final companyId = await CompanyUserService.getUserCompanyId(user.uid);
          if (companyId != null) {
            final companyWallet =
                await WalletService.getCompanyWalletByCompanyId(companyId);
            _currentPoints = companyWallet?.currentPoints ?? 0;
            _isOwner = true;

            // 회사 지갑 포인트 내역 조회 (통합: 캠페인 + 현금 거래)
            final unifiedLogs =
                await WalletService.getCompanyPointHistoryUnified(
                  companyId: companyId,
                  limit: 50,
                );

            print('✅ 회사 포인트 내역 조회 결과: ${unifiedLogs.length}건');
            for (var log in unifiedLogs) {
              print(
                '  - 거래 ID: ${log['id']}, 카테고리: ${log['transaction_category']}, 타입: ${log['transaction_type']}, 금액: ${log['amount']}, 상태: ${log['status']}',
              );
            }

            _pointHistory = unifiedLogs
                .map(
                  (log) => {
                    'id': log['id'] ?? '',
                    'type': log['transaction_category'] == 'cash'
                        ? (log['transaction_type'] == 'deposit'
                              ? 'charge'
                              : 'withdraw')
                        : (log['amount'] > 0 ? 'earned' : 'spent'),
                    'amount': log['amount'] ?? 0,
                    'description':
                        log['description'] ??
                        (log['transaction_category'] == 'cash'
                            ? (log['transaction_type'] == 'deposit'
                                  ? '포인트 충전'
                                  : '포인트 출금')
                            : '포인트 거래'),
                    'date': _formatDate(DateTime.parse(log['created_at'])),
                    'status': log['status'] ?? 'completed',
                    'transaction_category':
                        log['transaction_category'] ?? 'campaign',
                    'transaction_type': log['transaction_type'] ?? '',
                    'raw_data': log, // 전체 데이터 저장
                  },
                )
                .toList();

            print('✅ 포인트 내역 매핑 완료: ${_pointHistory.length}건');
          } else {
            _currentPoints = 0;
            _isOwner = false;
            _pointHistory = [];
          }
        } else {
          // manager: 개인 지갑 조회 (읽기 전용)
          final wallet = await WalletService.getUserWallet();
          _currentPoints = wallet?.currentPoints ?? 0;
          _isOwner = false; // owner가 아니면 입금/출금 권한 없음

          // 포인트 내역 조회
          final logs = await WalletService.getUserPointHistory(limit: 50);
          _pointHistory = logs
              .map(
                (log) => {
                  'id': log.id,
                  'type': log.amount > 0 ? 'earned' : 'spent',
                  'amount': log.amount,
                  'description': log.description ?? '포인트 거래',
                  'date': _formatDate(log.createdAt),
                  'transaction_category': 'campaign',
                  'transaction_type': log.transactionType,
                  'raw_data': {
                    'id': log.id,
                    'transaction_type': log.transactionType,
                    'amount': log.amount,
                    'description': log.description,
                    'created_at': log.createdAt.toIso8601String(),
                  },
                },
              )
              .toList();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentPoints = 0;
        _pointHistory = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('포인트 정보를 불러올 수 없습니다: $e')));
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('내 포인트'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.userType == 'advertiser') {
              context.go('/mypage/advertiser');
            } else if (widget.userType == 'reviewer') {
              context.go('/mypage/reviewer');
            } else {
              context.go('/mypage');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPointsContent(),
    );
  }

  Widget _buildPointsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 포인트 카드
          _buildCurrentPointsCard(),

          const SizedBox(height: 24),

          // 포인트 사용/출금 버튼
          _buildActionButtons(),

          const SizedBox(height: 24),

          // 포인트 내역
          _buildPointHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '보유 포인트',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '≈ ${(_currentPoints / 1000).toStringAsFixed(0)}원',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // owner가 아니면 버튼 숨김 및 안내 메시지 표시
    if (!_isOwner) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '입금/출금 권한이 없습니다. (owner만 가능)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 리뷰어는 출금 버튼만 표시
    if (widget.userType == 'reviewer') {
      return CustomButton(
        text: '포인트 출금',
        onPressed: _navigateToRefund,
        backgroundColor: Colors.white,
        textColor: const Color(0xFF4CAF50),
        borderColor: const Color(0xFF4CAF50),
      );
    }

    // 광고주는 충전/출금 모두 표시
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: '포인트 출금',
            onPressed: _navigateToRefund,
            backgroundColor: Colors.white,
            textColor: const Color(0xFF4CAF50),
            borderColor: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: '포인트 충전',
            onPressed: _navigateToCharge,
            backgroundColor: const Color(0xFF4CAF50),
            textColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPointHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '포인트 내역',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        if (_pointHistory.isEmpty)
          _buildEmptyHistory()
        else
          ..._pointHistory.map((history) => _buildHistoryItem(history)),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '포인트 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final isEarned = history['type'] == 'earned' || history['type'] == 'charge';
    final amount = history['amount'] as int;
    final isPositive = amount > 0;
    final status = history['status'] as String? ?? 'completed';
    final transactionCategory =
        history['transaction_category'] as String? ?? 'campaign';

    return InkWell(
      onTap: () {
        _navigateToDetail(history);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEarned
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isEarned ? Icons.add : Icons.remove,
                color: isEarned ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                  if (history['campaignTitle'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      history['campaignTitle'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    history['date'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (transactionCategory == 'cash' &&
                      status != 'completed') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'pending'
                            ? Colors.orange.withValues(alpha: 0.1)
                            : status == 'approved'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status == 'pending'
                            ? '대기중'
                            : status == 'approved'
                            ? '승인됨'
                            : status == 'rejected'
                            ? '거절됨'
                            : status,
                        style: TextStyle(
                          fontSize: 10,
                          color: status == 'pending'
                              ? Colors.orange[700]
                              : status == 'approved'
                              ? Colors.blue[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEarned ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> history) {
    final routeName = widget.userType == 'reviewer'
        ? 'reviewer-points-detail'
        : 'advertiser-points-detail';

    context.pushNamed(
      routeName,
      pathParameters: {'id': history['id'] as String},
      extra: history['raw_data'],
    );
  }

  void _navigateToRefund() {
    final routeName = widget.userType == 'reviewer'
        ? 'reviewer-points-refund'
        : 'advertiser-points-refund';
    context.pushNamed(routeName).then((result) {
      // 환급 신청 성공 시 포인트 정보 다시 로드
      if (result == true) {
        _loadPointsData();
      }
    });
  }

  void _navigateToCharge() {
    final routeName = widget.userType == 'reviewer'
        ? 'reviewer-points-charge'
        : 'advertiser-points-charge';
    context.pushNamed(routeName).then((result) {
      // 충전 신청 성공 시 포인트 정보 다시 로드
      if (result == true) {
        _loadPointsData();
      }
    });
  }
}
