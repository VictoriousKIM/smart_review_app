import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
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
      if (user != null) {
        setState(() {
          _currentPoints = user.points;
          _isLoading = false;
        });

        // TODO: 실제 포인트 내역 API 호출
        // 현재는 빈 리스트로 설정
        _pointHistory = [];
      } else {
        setState(() {
          _currentPoints = 0;
          _pointHistory = [];
          _isLoading = false;
        });
      }
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
            color: Colors.green.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: '포인트 출금',
            onPressed: () {
              _showWithdrawDialog();
            },
            backgroundColor: Colors.white,
            textColor: const Color(0xFF4CAF50),
            borderColor: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: '포인트 충전',
            onPressed: () {
              _showChargeDialog();
            },
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
    final isEarned = history['type'] == 'earned';
    final amount = history['amount'] as int;
    final isPositive = amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEarned
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
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
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isEarned ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포인트 출금'),
        content: const Text('포인트 출금 기능은 준비 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showChargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포인트 충전'),
        content: const Text('포인트 충전 기능은 준비 중입니다.'),
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
