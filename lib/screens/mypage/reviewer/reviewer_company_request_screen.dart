import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../config/supabase_config.dart';
import '../../../services/company_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/date_time_utils.dart';

class ReviewerCompanyRequestScreen extends ConsumerStatefulWidget {
  const ReviewerCompanyRequestScreen({super.key});

  @override
  ConsumerState<ReviewerCompanyRequestScreen> createState() =>
      _ReviewerCompanyRequestScreenState();
}

class _ReviewerCompanyRequestScreenState
    extends ConsumerState<ReviewerCompanyRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 리뷰어 신청 탭 관련
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSearching = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _foundCompanies = [];
  String? _errorMessage;
  Timer? _countdownTimer;
  int _currentFailureCount = 0;

  // 검색 실패 제한 관련
  static const String _searchFailureCountKey = 'reviewer_search_failure_count';
  static const String _searchFailureTimestampKey = 'reviewer_search_failure_timestamp';
  static const int _maxFailureCount = 5;
  static const Duration _blockDuration = Duration(minutes: 5);

  // 신청 내역 탭 관련
  bool _isLoadingRequests = false;
  List<Map<String, dynamic>> _reviewerRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _reviewerRequests.isEmpty) {
        _loadReviewerRequests();
      }
    });
    // 초기 실패 횟수 로드
    _loadFailureCount();
  }

  // 실패 횟수 로드
  Future<void> _loadFailureCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_searchFailureCountKey) ?? 0;
      final timestamp = prefs.getInt(_searchFailureTimestampKey);
      
      if (mounted) {
        setState(() {
          _currentFailureCount = count;
        });
        
        // 차단 중이면 카운트다운 시작
        if (count >= _maxFailureCount && timestamp != null) {
          final blockTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final elapsed = now.difference(blockTime);
          if (elapsed < _blockDuration) {
            _startCountdown();
          } else {
            await _resetSearchFailureCount();
          }
        }
      }
    } catch (e) {
      print('⚠️ 실패 횟수 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 실시간 카운트다운 시작
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final failureTimestamp = prefs.getInt(_searchFailureTimestampKey);
        
        if (failureTimestamp != null) {
          final blockTime = DateTime.fromMillisecondsSinceEpoch(failureTimestamp);
          final now = DateTime.now();
          final elapsed = now.difference(blockTime);
          
          if (elapsed < _blockDuration) {
            final remainingSeconds = _blockDuration.inSeconds - elapsed.inSeconds;
            final remainingMinutes = remainingSeconds ~/ 60;
            final remainingSecs = remainingSeconds % 60;
            
            if (mounted) {
              setState(() {
                _errorMessage = '검색이 5번 연속 실패하여 5분간 차단되었습니다. ${remainingMinutes}분 ${remainingSecs}초 후에 다시 시도해주세요.';
              });
            }
          } else {
            // 차단 시간이 지났으면 리셋
            timer.cancel();
            await _resetSearchFailureCount();
            if (mounted) {
              setState(() {
                _errorMessage = null;
                _currentFailureCount = 0;
              });
            }
          }
        } else {
          timer.cancel();
        }
      } catch (e) {
        print('⚠️ 카운트다운 업데이트 실패: $e');
        timer.cancel();
      }
    });
  }

  // 검색 차단 확인
  Future<bool> _isSearchBlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failureCount = prefs.getInt(_searchFailureCountKey) ?? 0;
      final failureTimestamp = prefs.getInt(_searchFailureTimestampKey);

      if (failureCount >= _maxFailureCount && failureTimestamp != null) {
        final blockTime = DateTime.fromMillisecondsSinceEpoch(failureTimestamp);
        final now = DateTime.now();
        final elapsed = now.difference(blockTime);

        if (elapsed < _blockDuration) {
          // 실시간 카운트다운 시작
          _startCountdown();
          return true;
        } else {
          // 차단 시간이 지났으면 리셋
          await _resetSearchFailureCount();
        }
      }
      return false;
    } catch (e) {
      print('⚠️ 검색 차단 확인 실패: $e');
      return false;
    }
  }

  // 검색 실패 횟수 증가
  Future<void> _incrementSearchFailureCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_searchFailureCountKey) ?? 0;
      final newCount = currentCount + 1;
      
      await prefs.setInt(_searchFailureCountKey, newCount);
      
      setState(() {
        _currentFailureCount = newCount;
      });
      
      if (newCount >= _maxFailureCount) {
        // 5번 실패 시 타임스탬프 저장 및 카운트다운 시작
        await prefs.setInt(_searchFailureTimestampKey, DateTime.now().millisecondsSinceEpoch);
        _startCountdown();
      }
    } catch (e) {
      print('⚠️ 검색 실패 횟수 증가 실패: $e');
    }
  }

  // 검색 실패 횟수 리셋
  Future<void> _resetSearchFailureCount() async {
    try {
      _countdownTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchFailureCountKey);
      await prefs.remove(_searchFailureTimestampKey);
      if (mounted) {
        setState(() {
          _currentFailureCount = 0;
        });
      }
    } catch (e) {
      print('⚠️ 검색 실패 횟수 리셋 실패: $e');
    }
  }

  // 리뷰어 신청 탭 관련 메서드
  Future<void> _searchCompany() async {
    final businessName = _searchController.text.trim();
    
    if (businessName.isEmpty) {
      setState(() {
        _errorMessage = '사업자명을 입력해주세요.';
        _foundCompanies = [];
      });
      return;
    }

    // 검색 차단 확인
    final isBlocked = await _isSearchBlocked();
    if (isBlocked) {
      setState(() {
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundCompanies = [];
    });

    try {
      final supabase = SupabaseConfig.client;
      
      // companies 테이블에서 정확히 일치하는 사업자명 검색 (여러 결과 반환)
      final response = await supabase
          .from('companies')
          .select('id, business_name, business_number, representative_name, address')
          .eq('business_name', businessName);

      if (response.isNotEmpty) {
        // 검색 성공 시 실패 횟수 리셋
        await _resetSearchFailureCount();
        
        setState(() {
          _foundCompanies = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
        });
      } else {
        // 검색 실패 (결과 없음)
        await _incrementSearchFailureCount();
        
        final prefs = await SharedPreferences.getInstance();
        final currentCount = prefs.getInt(_searchFailureCountKey) ?? 0;
        
        setState(() {
          _errorMessage = '등록된 광고사를 찾을 수 없습니다. 사업자명을 정확히 입력해주세요. ($currentCount/$_maxFailureCount)';
          _foundCompanies = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ 광고사 검색 실패: $e');
      
      // 검색 실패 (에러 발생)
      await _incrementSearchFailureCount();
      
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_searchFailureCountKey) ?? 0;
      
      setState(() {
        _errorMessage = '검색 중 오류가 발생했습니다: $e ($currentCount/$_maxFailureCount)';
        _foundCompanies = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _requestReviewerRoleForCompany(Map<String, dynamic> company) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = SupabaseConfig.client;
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final companyId = company['id'] as String;

      // Custom JWT 세션 확인
      final prefs = await SharedPreferences.getInstance();
      final customJwtToken = prefs.getString('custom_jwt_token');

      // RPC 함수 호출 (리뷰어 요청)
      if (customJwtToken != null) {
        // Custom JWT를 사용하여 직접 HTTP 요청
        final supabaseUrl = SupabaseConfig.supabaseUrl;
        final url = Uri.parse(
          '$supabaseUrl/rest/v1/rpc/request_reviewer_role',
        );

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $customJwtToken',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'p_company_id': companyId,
            'p_user_id': userId,
          }),
        );

        if (response.statusCode != 200) {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
          final errorMessage = errorData?['message'] ?? '요청 실패: ${response.statusCode}';
          throw Exception(errorMessage);
        }
        debugPrint('✅ Custom JWT로 리뷰어 요청 RPC 호출 성공');
      } else {
        // 일반 RPC 함수 호출
        await supabase.rpc(
          'request_reviewer_role',
          params: {
            'p_company_id': companyId,
            'p_user_id': userId,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${company['business_name']} 광고사 리뷰어 요청이 완료되었습니다. 승인 대기 중입니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 성공 후 초기화 및 신청 내역 새로고침
        setState(() {
          _foundCompanies = [];
          _searchController.clear();
          _isSubmitting = false;
        });
        
        // 신청 내역 탭으로 전환하고 새로고침
        _tabController.animateTo(1);
        _loadReviewerRequests();
      }
    } catch (e) {
      print('❌ 리뷰어 요청 실패: $e');
      
      String errorMessage = '요청 실패: $e';
      if (e.toString().contains('이미 요청')) {
        errorMessage = '이미 요청한 광고사입니다.';
      } else if (e.toString().contains('이미 등록')) {
        errorMessage = '이미 등록된 리뷰어입니다.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 신청 내역 탭 관련 메서드
  Future<void> _loadReviewerRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final requests = await CompanyService.getUserReviewerRequests();
      setState(() {
        _reviewerRequests = requests;
        _isLoadingRequests = false;
      });
    } catch (e) {
      print('❌ 리뷰어 요청 목록 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 내역을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('광고사 리뷰어'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/reviewer'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '리뷰어 신청'),
            Tab(text: '신청 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestTab(),
          _buildStatusTab(),
        ],
      ),
    );
  }

  // 리뷰어 신청 탭
  Widget _buildRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '광고사에 리뷰어로 등록을 요청할 수 있습니다.\n사업자명을 정확히 입력해주세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 검색 섹션
            Text(
              '사업자명 검색',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: '사업자명',
                      hintText: '등록된 사업자명을 정확히 입력하세요',
                      border: const OutlineInputBorder(),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '사업자명을 입력해주세요';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _searchCompany(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _searchCompany,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 검색 결과 카드 리스트
            if (_foundCompanies.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '검색 결과 (${_foundCompanies.length}개)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              ..._foundCompanies.map((company) => _buildCompanyCard(company)),
            ],
          ],
        ),
      ),
    );
  }

  // 신청 내역 탭
  Widget _buildStatusTab() {
    return RefreshIndicator(
      onRefresh: _loadReviewerRequests,
      child: _isLoadingRequests
          ? const Center(child: CircularProgressIndicator())
          : _reviewerRequests.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviewerRequests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(_reviewerRequests[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '신청한 광고사가 없습니다.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '리뷰어 신청 탭에서 광고사에 신청해보세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? '';
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request['company_name'] ?? '이름 없음',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color']?.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusInfo['color'] ?? Colors.grey,
                    width: 1,
                  ),
                ),
                child: Text(
                  statusInfo['label'] ?? status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusInfo['color'] ?? Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (request['business_number'] != null) ...[
            _buildInfoRow('사업자등록번호', request['business_number'] ?? ''),
            const SizedBox(height: 8),
          ],
          if (request['created_at'] != null) ...[
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '신청일시: ${_formatDate(request['created_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': '승인 대기',
          'color': Colors.orange,
        };
      case 'active':
        return {
          'label': '활성 리뷰어',
          'color': Colors.green,
        };
      case 'inactive':
        return {
          'label': '비활성 리뷰어',
          'color': Colors.grey,
        };
      case 'rejected':
        return {
          'label': '거절됨',
          'color': Colors.red,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
        };
    }
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return '';
      
      DateTime date;
      if (dateValue is String) {
        date = DateTimeUtils.parseKST(dateValue);
      } else if (dateValue is DateTime) {
        date = DateTimeUtils.toKST(dateValue);
      } else {
        return '';
      }

      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // 회사 카드 위젯
  Widget _buildCompanyCard(Map<String, dynamic> company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company['business_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('사업자번호', company['business_number'] ?? ''),
                  if (company['representative_name'] != null) ...[
                    const SizedBox(height: 4),
                    _buildInfoRow('대표자', company['representative_name'] ?? ''),
                  ],
                  if (company['address'] != null) ...[
                    const SizedBox(height: 4),
                    _buildInfoRow('주소', company['address'] ?? ''),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isSubmitting 
                  ? null 
                  : () => _requestReviewerRoleForCompany(company),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('신청'),
            ),
          ],
        ),
      ),
    );
  }
}
