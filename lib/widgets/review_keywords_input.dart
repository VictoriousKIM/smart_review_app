import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_text_field.dart';

/// 리뷰 키워드 입력 위젯
///
/// 체크박스로 활성화/비활성화하고, 콤마로 구분된 텍스트 필드에서 키워드를 입력받아
/// 태그/칩 형태로 표시합니다. 최대 3개까지 입력 가능합니다.
class ReviewKeywordsInput extends StatefulWidget {
  final bool enabled;
  final List<String> keywords;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<List<String>> onChanged;
  final int maxKeywords;

  const ReviewKeywordsInput({
    Key? key,
    required this.enabled,
    required this.keywords,
    required this.onEnabledChanged,
    required this.onChanged,
    this.maxKeywords = 3,
  }) : super(key: key);

  @override
  State<ReviewKeywordsInput> createState() => _ReviewKeywordsInputState();
}

class _ReviewKeywordsInputState extends State<ReviewKeywordsInput> {
  late TextEditingController _textController;
  List<String> _currentKeywords = [];
  bool _isUpdatingController = false; // 컨트롤러 업데이트 중 플래그

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _currentKeywords = List<String>.from(widget.keywords);
    // 초기화 시에는 입력 필드를 비워둠 (키워드는 칩으로만 표시)
  }

  @override
  void didUpdateWidget(ReviewKeywordsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keywords != oldWidget.keywords) {
      // 키워드가 외부에서 변경된 경우에만 업데이트
      // 입력 필드는 사용자가 입력 중인 내용을 유지
      final newKeywords = List<String>.from(widget.keywords);
      if (_currentKeywords.length != newKeywords.length ||
          !_currentKeywords.every((k) => newKeywords.contains(k))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentKeywords = newKeywords;
            });
          }
        });
      }
    }
  }

  void _onTextChanged(String text) {
    // 프로그래밍 방식으로 컨트롤러를 업데이트하는 중이면 무시
    if (_isUpdatingController) return;

    // 콤마가 없으면 일반 입력이므로 처리하지 않음 (조합 중인 문자 유지)
    if (!text.contains(',')) {
      return;
    }

    // TextEditingValue를 사용하여 조합 중인 문자 확인
    final value = _textController.value;
    final hasComposing = value.composing.isValid;

    // 조합 중인 범위를 제외한 실제 텍스트만 사용
    String textToProcess = text;
    if (hasComposing) {
      final composingStart = value.composing.start;
      final composingEnd = value.composing.end;
      if (composingStart >= 0 && composingEnd <= text.length) {
        // 조합 중인 부분을 제외한 텍스트만 사용
        textToProcess =
            text.substring(0, composingStart) + text.substring(composingEnd);
      }
    }

    // 콤마로 구분하여 키워드 파싱
    final parts = textToProcess.split(',');

    // 완료된 키워드들 (마지막 부분 제외)
    final completedKeywords = <String>[];
    for (int i = 0; i < parts.length - 1; i++) {
      final keyword = parts[i].trim();
      if (keyword.isNotEmpty) {
        completedKeywords.add(keyword);
      }
    }

    // 현재 입력 중인 키워드 (마지막 부분)
    final currentInput = parts.isNotEmpty ? parts.last : '';

    // 기존 키워드와 새로 완료된 키워드 합치기
    final newKeywords = List<String>.from(_currentKeywords);

    // 새로 완료된 키워드 추가 (중복 제거, 최대 개수 제한)
    for (final keyword in completedKeywords) {
      if (!newKeywords.contains(keyword) &&
          newKeywords.length < widget.maxKeywords) {
        newKeywords.add(keyword);
      }
    }

    // 상태 업데이트는 빌드 완료 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final hasChanged =
          _currentKeywords.length != newKeywords.length ||
          !_currentKeywords.every((k) => newKeywords.contains(k));

      if (hasChanged) {
        setState(() {
          _currentKeywords = newKeywords;
        });

        // 부모 위젯에 변경사항 알림 (빌드 완료 후)
        widget.onChanged(_currentKeywords);
      }

      // 입력 필드 업데이트 (현재 입력 중인 키워드만 표시)
      // 조합 상태를 초기화하여 중복 입력 방지
      final currentText = _textController.value.text;
      if (currentText != currentInput) {
        _isUpdatingController = true;
        _textController.value = TextEditingValue(
          text: currentInput,
          selection: TextSelection.collapsed(offset: currentInput.length),
          composing: TextRange.empty, // 조합 상태 초기화
        );
        // 다음 프레임에서 플래그 해제
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingController = false;
        });
      }
    });
  }

  void _removeKeyword(String keyword) {
    // 상태 업데이트는 빌드 완료 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _currentKeywords.remove(keyword);
      });

      // 부모 위젯에 변경사항 알림 (빌드 완료 후)
      widget.onChanged(_currentKeywords);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 체크박스
        CheckboxListTile(
          title: const Text(
            '리뷰 키워드 사용',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '최대 ${widget.maxKeywords}개까지 입력 가능',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: widget.enabled,
          onChanged: (value) {
            widget.onEnabledChanged(value ?? false);
          },
          contentPadding: EdgeInsets.zero,
        ),

        // 키워드 입력 영역 (체크박스가 체크되었을 때만 표시)
        if (widget.enabled) ...[
          const SizedBox(height: 8),
          // 텍스트 입력 필드
          CustomTextField(
            controller: _textController,
            hintText: '키워드를 입력하세요 (콤마로 구분)',
            onChanged: _onTextChanged,
            readOnly: _currentKeywords.length >= widget.maxKeywords,
            inputFormatters: [
              // 콤마 입력 시 조합 완료를 보장하는 formatter
              _CommaInputFormatter(),
            ],
          ),
          const SizedBox(height: 8),
          // 키워드 개수 표시
          if (_currentKeywords.length >= widget.maxKeywords)
            Text(
              '최대 ${widget.maxKeywords}개까지 입력 가능합니다',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          const SizedBox(height: 8),
          // 태그/칩 표시
          if (_currentKeywords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentKeywords.map((keyword) {
                return Chip(
                  label: Text(keyword),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeKeyword(keyword),
                  backgroundColor: Colors.grey[200],
                  side: BorderSide(color: Colors.grey[400]!),
                  labelStyle: const TextStyle(fontSize: 14),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

/// 콤마 입력 시 한글 조합을 완료시키는 TextInputFormatter
class _CommaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 새 텍스트에 콤마가 추가되었는지 확인
    final oldHasComma = oldValue.text.contains(',');
    final newHasComma = newValue.text.contains(',');
    final commaAdded = newHasComma && !oldHasComma;

    // 콤마가 추가되었고 조합 중인 문자가 있으면 조합 완료
    if (commaAdded && newValue.composing.isValid) {
      return TextEditingValue(
        text: newValue.text,
        selection: newValue.selection,
        composing: TextRange.empty, // 조합 상태 초기화하여 완료 처리
      );
    }

    return newValue;
  }
}
