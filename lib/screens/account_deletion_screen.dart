import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../services/account_deletion_service.dart';
import '../utils/error_message_utils.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  bool _hasDeletionRequest = false;
  Map<String, dynamic>? _eligibilityData;

  @override
  void initState() {
    super.initState();
    _checkDeletionStatus();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkDeletionStatus() async {
    setState(() => _isLoading = true);
    try {
      final hasRequest = await AccountDeletionService.hasDeletionRequest();
      final eligibility = await AccountDeletionService.checkDeletionEligibility();
      
      setState(() {
        _hasDeletionRequest = hasRequest;
        _eligibilityData = eligibility;
      });
    } catch (e) {
      _showErrorSnackBar(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestDeletion() async {
    if (_reasonController.text.trim().isEmpty) {
      _showErrorSnackBar('삭제 사유를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AccountDeletionService.requestAccountDeletion(
        reason: _reasonController.text.trim(),
      );
      
      _showSuccessSnackBar('계정 삭제 요청이 완료되었습니다.');
      await _checkDeletionStatus();
    } catch (e) {
      _showErrorSnackBar(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelDeletionRequest() async {
    setState(() => _isLoading = true);
    try {
      await AccountDeletionService.cancelDeletionRequest();
      
      _showSuccessSnackBar('계정 삭제 요청이 취소되었습니다.');
      await _checkDeletionStatus();
    } catch (e) {
      _showErrorSnackBar(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(dynamic error) {
    final userFriendlyMessage = error is String 
        ? error 
        : ErrorMessageUtils.getUserFriendlyMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userFriendlyMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEligibilityInfo() {
    if (_eligibilityData == null) return const SizedBox.shrink();

    final data = _eligibilityData!;
    final warnings = data['warnings'] as List<String>? ?? [];
    final errors = data['errors'] as List<String>? ?? [];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정 삭제 정보',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // 포인트 정보
            _buildInfoRow('개인 포인트', '${data['personalPoints']} 포인트'),
            _buildInfoRow('회사 포인트', '${data['companyPoints']} 포인트'),
            _buildInfoRow('활성 캠페인', '${data['activeCampaigns']}개'),
            
            if (data['companyId'] != null)
              _buildInfoRow('다른 오너 수', '${data['otherOwnersCount']}명'),
            
            const SizedBox(height: 16),
            
            // 경고 및 오류
            if (errors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '삭제 불가',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...errors.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    )),
                  ],
                ),
              ),
            ],
            
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '주의사항',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...warnings.map((warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $warning',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDeletionRequestForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정 삭제 요청',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Text(
              '계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '삭제 사유',
                hintText: '계정을 삭제하는 이유를 알려주세요.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('계정 삭제 요청'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletionRequestStatus() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '삭제 요청 대기 중',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text(
              '계정 삭제 요청이 관리자 검토 중입니다. 요청을 취소하거나 관리자 승인을 기다려주세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _cancelDeletionRequest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade700),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('삭제 요청 취소'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 삭제'),
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade700,
      ),
      body: _isLoading && _eligibilityData == null
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBuilder(
              builder: (context, sizingInformation) {
                return SingleChildScrollView(
                  padding: getValueForScreenType<EdgeInsets>(
                    context: context,
                    mobile: EdgeInsets.zero,
                    tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    desktop: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: getValueForScreenType<double>(
                          context: context,
                          mobile: double.infinity,
                          tablet: 700,
                          desktop: 900,
                        ),
                      ),
                      child: Column(
                        children: [
                          // 삭제 가능 여부 정보
                          _buildEligibilityInfo(),
                          
                          // 삭제 요청 상태에 따른 UI
                          if (_hasDeletionRequest)
                            _buildDeletionRequestStatus()
                          else
                            _buildDeletionRequestForm(),
                          
                          // 주의사항
                          Card(
                            margin: getValueForScreenType<EdgeInsets>(
                              context: context,
                              mobile: const EdgeInsets.all(16),
                              tablet: const EdgeInsets.all(20),
                              desktop: const EdgeInsets.all(24),
                            ),
                            child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '주의사항',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• 계정 삭제 후 모든 데이터는 복구할 수 없습니다.\n'
                            '• 포인트, 캠페인, 리뷰 등 모든 활동 내역이 삭제됩니다.\n'
                            '• 회사 오너인 경우 다른 오너가 있어야 삭제 가능합니다.\n'
                            '• 삭제 요청 후 관리자 승인이 필요합니다.\n'
                            '• 법적 요구사항에 따라 일정 기간 데이터가 보존될 수 있습니다.',
                            style: TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
