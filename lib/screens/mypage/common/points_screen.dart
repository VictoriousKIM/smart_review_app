import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/company_user_service.dart';
import '../../../utils/user_type_helper.dart';
import '../../../widgets/custom_button.dart';
import '../../../utils/date_time_utils.dart';

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

      // widget.userType을 직접 사용하여 리뷰어/광고주 구분
      if (widget.userType == 'reviewer') {
        // 리뷰어: 개인 지갑 조회 (userId 기반)
        final wallet = await WalletService.getUserWallet();
        _currentPoints = wallet?.currentPoints ?? 0;
        _isOwner = true; // 리뷰어는 항상 자신의 지갑에 대한 권한이 있음

        // 포인트 내역 조회 (통합: 캠페인 + 현금 거래)
        final unifiedLogs = await WalletService.getUserPointHistoryUnified(limit: 50);

        _pointHistory = unifiedLogs.map((log) {
          final amount = log['point_amount'] ?? log['amount'] ?? 0;
          return {
            'id': log['id'] ?? '',
            'type': log['transaction_category'] == 'cash'
                ? (log['transaction_type'] == 'deposit'
                      ? 'charge'
                      : 'withdraw')
                : (amount > 0 ? 'earned' : 'spent'),
            'amount': amount,
            'description':
                log['description'] ??
                (log['transaction_category'] == 'cash'
                    ? (log['transaction_type'] == 'deposit'
                          ? '포인트 충전'
                          : '포인트 출금')
                    : '포인트 거래'),
            'date': DateTimeUtils.formatKST(
              DateTimeUtils.parseKST(log['created_at']),
            ),
            'status': log['status'],
            'transaction_category':
                log['transaction_category'] ?? 'campaign',
            'transaction_type': log['transaction_type'] ?? '',
            'raw_data': log, // 전체 데이터 저장
          };
        }).toList();
      } else {
        // 광고주: owner 여부 확인 후 지갑 조회
        final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
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
              final amount = log['point_amount'] ?? log['amount'] ?? 0;
              print(
                '  - 거래 ID: ${log['id']}, 카테고리: ${log['transaction_category']}, 타입: ${log['transaction_type']}, 금액: $amount, 상태: ${log['status']}',
              );
            }

            _pointHistory = unifiedLogs.map((log) {
              final amount = log['point_amount'] ?? log['amount'] ?? 0;
              return {
                'id': log['id'] ?? '',
                'type': log['transaction_category'] == 'cash'
                    ? (log['transaction_type'] == 'deposit'
                          ? 'charge'
                          : 'withdraw')
                    : (amount > 0 ? 'earned' : 'spent'),
                'amount': amount,
                'description':
                    log['description'] ??
                    (log['transaction_category'] == 'cash'
                        ? (log['transaction_type'] == 'deposit'
                              ? '포인트 충전'
                              : '포인트 출금')
                        : '포인트 거래'),
                'date': DateTimeUtils.formatKST(
                  DateTimeUtils.parseKST(log['created_at']),
                ),
                'status': log['status'],
                'transaction_category':
                    log['transaction_category'] ?? 'campaign',
                'transaction_type': log['transaction_type'] ?? '',
                'raw_data': log, // 전체 데이터 저장
              };
            }).toList();

            print('✅ 포인트 내역 매핑 완료: ${_pointHistory.length}건');
          } else {
            _currentPoints = 0;
            _isOwner = false;
            _pointHistory = [];
          }
        } else {
          // manager: 회사 지갑 조회 (읽기 전용)
          final companyId = await CompanyUserService.getUserCompanyId(user.uid);
          if (companyId != null) {
            final companyWallet =
                await WalletService.getCompanyWalletByCompanyId(companyId);
            _currentPoints = companyWallet?.currentPoints ?? 0;
            _isOwner = false; // owner가 아니면 입금/출금 권한 없음

            // 회사 지갑 포인트 내역 조회 (통합: 캠페인 + 현금 거래)
            final unifiedLogs =
                await WalletService.getCompanyPointHistoryUnified(
                  companyId: companyId,
                  limit: 50,
                );

            _pointHistory = unifiedLogs.map((log) {
              final amount = log['point_amount'] ?? log['amount'] ?? 0;
              return {
                'id': log['id'] ?? '',
                'type': log['transaction_category'] == 'cash'
                    ? (log['transaction_type'] == 'deposit'
                          ? 'charge'
                          : 'withdraw')
                    : (amount > 0 ? 'earned' : 'spent'),
                'amount': amount,
                'description':
                    log['description'] ??
                    (log['transaction_category'] == 'cash'
                        ? (log['transaction_type'] == 'deposit'
                              ? '포인트 충전'
                              : '포인트 출금')
                        : '포인트 거래'),
                'date': DateTimeUtils.formatKST(
                  DateTimeUtils.parseKST(log['created_at']),
                ),
                'status': log['status'],
                'transaction_category':
                    log['transaction_category'] ?? 'campaign',
                'transaction_type': log['transaction_type'] ?? '',
                'raw_data': log, // 전체 데이터 저장
              };
            }).toList();
          } else {
            _currentPoints = 0;
            _isOwner = false;
            _pointHistory = [];
          }
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
            // userType에 따라 적절한 마이페이지로 리다이렉트
            if (widget.userType == 'advertiser') {
              context.go('/mypage/advertiser');
            } else {
              context.go('/mypage/reviewer');
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
                '입금/출금 권한이 없습니다. (대표만 가능)',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 높이를 계산하여 하단 전체를 차지하도록 설정
        final screenHeight = MediaQuery.of(context).size.height;
        final availableHeight = screenHeight - 400; // 상단 요소들 높이 제외

        return Container(
          width: double.infinity,
          height: availableHeight > 200 ? availableHeight : 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final isEarned = history['type'] == 'earned' || history['type'] == 'charge';
    final transactionType = history['transaction_type'] as String? ?? '';
    final transactionCategory =
        history['transaction_category'] as String? ?? 'campaign';
    // 출금(withdraw) 거래의 경우 amount를 음수로 표시
    final rawAmount =
        (history['point_amount'] ?? history['amount'] ?? 0) as int;
    final amount =
        (transactionCategory == 'cash' && transactionType == 'withdraw')
        ? -rawAmount
        : rawAmount;
    final isPositive = amount > 0;
    final status = history['status'] as String?;

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
                  if (transactionCategory == 'cash' && status != null) ...[
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

    context
        .pushNamed(
          routeName,
          pathParameters: {'id': history['id'] as String},
          extra: history['raw_data'],
        )
        .then((result) {
          // 취소 또는 변경 시 포인트 정보 다시 로드
          if (result == true) {
            _loadPointsData();
          }
        });
  }

  void _navigateToRefund() {
    // withdraw 하위 URL 사용
    if (widget.userType == 'reviewer') {
      context.push('/mypage/reviewer/points/withdraw').then((result) {
        // 환급 신청 성공 시 포인트 정보 다시 로드
        if (result == true) {
          _loadPointsData();
        }
      });
    } else {
      context.push('/mypage/advertiser/points/withdraw').then((result) {
        // 환급 신청 성공 시 포인트 정보 다시 로드
        if (result == true) {
          _loadPointsData();
        }
      });
    }
  }

  void _navigateToCharge() {
    // 리뷰어는 충전 불가
    if (widget.userType == 'reviewer') {
      return;
    }
    // deposit 하위 URL 사용
    context.push('/mypage/advertiser/points/deposit').then((result) {
      // 충전 신청 성공 시 포인트 정보 다시 로드
      if (result == true) {
        _loadPointsData();
      }
    });
  }
}
