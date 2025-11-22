import 'package:flutter/material.dart';
import '../services/juso_api_service.dart';

/// 우편번호 검색 결과 모델
class PostcodeResult {
  final String postalCode;
  final String address;
  final String? extraAddress;

  PostcodeResult({
    required this.postalCode,
    required this.address,
    this.extraAddress,
  });
}

/// 우편번호 검색 다이얼로그 위젯
/// 
/// 행정안전부 Juso API를 사용하여 주소를 검색하고 선택할 수 있는 다이얼로그입니다.
/// 모든 플랫폼(웹, Android, iOS)에서 작동합니다.
class PostcodeSearchDialog extends StatefulWidget {
  const PostcodeSearchDialog({super.key});

  @override
  State<PostcodeSearchDialog> createState() => _PostcodeSearchDialogState();

  /// 다이얼로그를 표시하고 선택된 주소를 반환
  static Future<PostcodeResult?> show(BuildContext context) {
    return showDialog<PostcodeResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PostcodeSearchDialog(),
    );
  }
}

class _PostcodeSearchDialogState extends State<PostcodeSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, String>> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _search({bool loadMore = false}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = false;
      });
      return;
    }

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _results = [];
      });
    }

    try {
      final results = await JusoApiService.searchAddress(
        keyword,
        currentPage: loadMore ? _currentPage + 1 : 1,
        countPerPage: 20,
      );

      setState(() {
        if (loadMore) {
          _results.addAll(results);
          _currentPage++;
        } else {
          _results = results;
          _currentPage = 1;
        }
        _isLoading = false;
        _hasMore = results.length >= 20; // 더 많은 결과가 있을 수 있음
        _errorMessage = _results.isEmpty ? '검색 결과가 없습니다.' : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _results = [];
      });
    }
  }

  void _selectAddress(Map<String, String> addressData) {
    final postalCode = addressData['postalCode'] ?? '';
    final roadAddress = addressData['roadAddress'] ?? '';
    final jibunAddress = addressData['jibunAddress'] ?? '';
    final buildingName = addressData['buildingName'] ?? '';

    // 지번주소가 있고 도로명주소와 다르면 참고항목으로 추가
    String? extraAddress;
    if (jibunAddress.isNotEmpty && jibunAddress != roadAddress) {
      extraAddress = jibunAddress;
      if (buildingName.isNotEmpty) {
        extraAddress += ' ($buildingName)';
      }
    } else if (buildingName.isNotEmpty) {
      extraAddress = '($buildingName)';
    }

    Navigator.of(context).pop(
      PostcodeResult(
        postalCode: postalCode,
        address: roadAddress,
        extraAddress: extraAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '우편번호 찾기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 검색 입력
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: '도로명, 지번, 건물명으로 검색',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                    _errorMessage = null;
                                  });
                                  _searchFocusNode.requestFocus();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _search(),
                    child: const Text('검색'),
                  ),
                ],
              ),
            ),
            // 검색 결과
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '주소를 검색해주세요',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '도로명, 지번, 건물명으로 검색할 수 있습니다',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 결과 개수 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                '검색 결과 ${_results.length}건',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // 결과 리스트
        Expanded(
          child: ListView.builder(
            itemCount: _results.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _results.length) {
                // 더보기 버튼
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () => _search(loadMore: true),
                            child: const Text('더보기'),
                          ),
                  ),
                );
              }

              final address = _results[index];
              final roadAddress = address['roadAddress'] ?? '';
              final jibunAddress = address['jibunAddress'] ?? '';
              final postalCode = address['postalCode'] ?? '';
              final buildingName = address['buildingName'] ?? '';

              return ListTile(
                title: Text(
                  roadAddress,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (jibunAddress.isNotEmpty && jibunAddress != roadAddress)
                      Text(
                        '지번: $jibunAddress',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '우편번호: $postalCode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                trailing: buildingName.isNotEmpty
                    ? Chip(
                        label: Text(
                          buildingName,
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onTap: () => _selectAddress(address),
              );
            },
          ),
        ),
      ],
    );
  }
}

