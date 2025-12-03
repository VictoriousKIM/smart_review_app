import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../config/supabase_config.dart';

/// 리뷰어 회원가입 - 회사 선택 폼
class ReviewerSignupCompanyForm extends StatefulWidget {
  final String? initialCompanyId;
  final Function(String?) onComplete;

  const ReviewerSignupCompanyForm({
    super.key,
    this.initialCompanyId,
    required this.onComplete,
  });

  @override
  State<ReviewerSignupCompanyForm> createState() =>
      _ReviewerSignupCompanyFormState();
}

class _ReviewerSignupCompanyFormState extends State<ReviewerSignupCompanyForm> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundCompanies = [];
  bool _isSearching = false;
  String? _errorMessage;
  String? _selectedCompanyId;
  Map<String, dynamic>? _initialCompany;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  // 검색 실패 횟수 관련 상수
  static const String _searchFailureCountKey = 'signup_company_search_failure_count';
  static const String _searchFailureTimestampKey = 'signup_company_search_failure_timestamp';
  static const int _maxFailureCount = 5;
  static const Duration _blockDuration = Duration(minutes: 5);


  @override
  void initState() {
    super.initState();
    if (widget.initialCompanyId != null) {
      _loadInitialCompany(widget.initialCompanyId!);
    }
    _checkSearchBlockStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 검색 차단 상태 확인 및 카운트다운 시작
  Future<void> _checkSearchBlockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failureCount = prefs.getInt(_searchFailureCountKey) ?? 0;
      final failureTimestamp = prefs.getInt(_searchFailureTimestampKey);

      if (failureCount >= _maxFailureCount && failureTimestamp != null) {
        final blockTime = DateTime.fromMillisecondsSinceEpoch(failureTimestamp);
        final now = DateTime.now();
        final elapsed = now.difference(blockTime);

        if (elapsed < _blockDuration) {
          // 아직 차단 중
          final remaining = _blockDuration - elapsed;
          _remainingSeconds = remaining.inSeconds;
          _startCountdown();
        } else {
          // 차단 시간이 지났으므로 리셋
          await _resetSearchFailureCount();
        }
      }
    } catch (e) {
      debugPrint('⚠️ 검색 차단 상태 확인 실패: $e');
    }
  }

  /// 카운트다운 시작
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        await _resetSearchFailureCount();
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      }
    });
  }

  /// 검색 실패 횟수 리셋
  Future<void> _resetSearchFailureCount() async {
    try {
      _countdownTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchFailureCountKey);
      await prefs.remove(_searchFailureTimestampKey);
      if (mounted) {
        setState(() {
          _remainingSeconds = 0;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 검색 실패 횟수 리셋 실패: $e');
    }
  }

  /// 검색 실패 횟수 증가
  Future<void> _incrementSearchFailureCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_searchFailureCountKey) ?? 0;
      final newCount = currentCount + 1;

      await prefs.setInt(_searchFailureCountKey, newCount);

      if (newCount >= _maxFailureCount) {
        // 5번 실패 시 타임스탬프 저장 및 카운트다운 시작
        await prefs.setInt(
          _searchFailureTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        _remainingSeconds = _blockDuration.inSeconds;
        _startCountdown();
      }
    } catch (e) {
      debugPrint('⚠️ 검색 실패 횟수 증가 실패: $e');
    }
  }

  /// 검색 차단 확인
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
          // 아직 차단 중
          final remaining = _blockDuration - elapsed;
          _remainingSeconds = remaining.inSeconds;
          if (_countdownTimer == null || !_countdownTimer!.isActive) {
            _startCountdown();
          }
          return true;
        } else {
          // 차단 시간이 지났으므로 리셋
          await _resetSearchFailureCount();
        }
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ 검색 차단 확인 실패: $e');
      return false;
    }
  }

  /// 초기 회사 정보 로드
  Future<void> _loadInitialCompany(String companyId) async {
    try {
      final response = await SupabaseConfig.client
          .from('companies')
          .select('id, business_name, business_number, representative_name, address')
          .eq('id', companyId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _initialCompany = response;
          _selectedCompanyId = companyId;
        });
      }
    } catch (e) {
      debugPrint('초기 회사 정보 로드 실패: $e');
    }
  }

  /// 회사 검색
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
    final blocked = await _isSearchBlocked();
    if (blocked) {
      final minutes = _remainingSeconds ~/ 60;
      final seconds = _remainingSeconds % 60;
      setState(() {
        _isSearching = false;
        _errorMessage = '너무 많은 검색 실패로 인해 검색이 일시적으로 차단되었습니다. ${minutes}분 ${seconds}초 후에 다시 시도해주세요.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundCompanies = [];
    });

    try {
      final response = await SupabaseConfig.client
          .from('companies')
          .select('id, business_name, business_number, representative_name, address')
          .eq('business_name', businessName);

      if (mounted) {
        if (response.isNotEmpty) {
          // 검색 성공 시 실패 횟수 리셋
          _countdownTimer?.cancel();
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
      }
    } catch (e) {
      debugPrint('❌ 광고사 검색 실패: $e');

      // 검색 실패 (에러 발생)
      await _incrementSearchFailureCount();

      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_searchFailureCountKey) ?? 0;

      if (mounted) {
        setState(() {
          _errorMessage = '검색 중 오류가 발생했습니다: $e ($currentCount/$_maxFailureCount)';
          _foundCompanies = [];
          _isSearching = false;
        });
      }
    }
  }

  /// 회사 선택
  void _selectCompany(Map<String, dynamic> company) {
    setState(() {
      _selectedCompanyId = company['id'] as String;
    });
  }

  /// 회원가입 완료
  void _handleComplete() {
    widget.onComplete(_selectedCompanyId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            '회사 선택',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '소속된 광고사를 선택해주세요 (선택)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 64),
          // 초기 회사 정보 표시
          if (_initialCompany != null) ...[
            _buildCompanyCard(_initialCompany!),
            const SizedBox(height: 24),
          ],
          // 검색 입력
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: '사업자명 검색',
              hintText: '사업자명을 입력해주세요',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                onPressed: _isSearching ? null : _searchCompany,
              ),
            ),
            onSubmitted: (_) => _searchCompany(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          // 검색 결과
          if (_foundCompanies.isNotEmpty) ...[
            const Text(
              '검색 결과',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._foundCompanies.map((company) => _buildCompanyCard(company)),
          ],
          const SizedBox(height: 32),
          // 완료 버튼
          ElevatedButton(
            onPressed: _handleComplete,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '회원가입 완료',
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

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    final isSelected = _selectedCompanyId == company['id'];

    return Card(
      color: isSelected ? Colors.blue[50] : null,
      child: ListTile(
        title: Text(company['business_name'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company['business_number'] != null)
              Text('사업자번호: ${company['business_number']}'),
            if (company['representative_name'] != null)
              Text('대표자: ${company['representative_name']}'),
            if (company['address'] != null)
              Text('주소: ${company['address']}'),
          ],
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () => _selectCompany(company),
      ),
    );
  }
}

