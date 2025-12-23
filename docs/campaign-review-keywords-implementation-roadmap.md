# 캠페인 리뷰 키워드 기능 구현 로드맵

## 📋 개요

캠페인 생성 및 편집 화면의 리뷰 설정 박스에 리뷰 키워드 입력 기능을 추가합니다. 최대 3개의 키워드를 입력할 수 있으며, 리스트 형태로 관리됩니다.

## 🎯 목표

- 리뷰 설정 박스에 리뷰 키워드 입력 필드 추가
- 최대 3개 키워드까지 입력 가능
- 키워드는 리스트 형태로 저장 및 관리
- 캠페인 생성 및 편집 시 키워드 설정 가능
- 기본 리뷰 설정에 키워드 기본값 저장/로드 기능 추가

## 📊 현재 상태 분석

### ✅ 이미 구현된 부분
- RPC 함수 시그니처에 `p_review_keywords` 파라미터 존재 (`text[]` 타입)
- `create_campaign_with_points_v2` 함수에 `p_review_keywords` 파라미터 포함

### ❌ 미구현 부분
1. **데이터베이스 스키마**
   - `campaigns` 테이블에 `review_keywords` 컬럼 없음 (제거됨)
   - 마이그레이션 필요

2. **Campaign 모델**
   - `reviewKeywords` 필드 없음
   - `fromJson`, `toJson`, `copyWith` 메서드에 필드 추가 필요

3. **UI 컴포넌트**
   - 리뷰 설정 박스에 키워드 입력 필드 없음
   - 키워드 리스트 관리 UI 없음

4. **서비스 레이어**
   - `CampaignService.createCampaignV2`에 `reviewKeywords` 파라미터 없음
   - 기본 리뷰 설정 서비스에 키워드 저장/로드 기능 없음

5. **RPC 함수**
   - `create_campaign_with_points_v2` 함수 내부에서 `p_review_keywords` 처리 확인 필요
   - `update_campaign_v2` 함수에 `p_review_keywords` 파라미터 추가 필요

## 🗺️ 구현 단계

### Phase 1: 데이터베이스 스키마 및 RPC 함수

#### 1.1 데이터베이스 마이그레이션
**파일**: `supabase/migrations/YYYYMMDDHHMMSS_add_review_keywords.sql`

**작업 내용**:
```sql
-- campaigns 테이블에 review_keywords 컬럼 추가
ALTER TABLE "public"."campaigns" 
ADD COLUMN IF NOT EXISTS "review_keywords" "text"[] DEFAULT NULL::"text"[];

-- 인덱스 추가 (선택사항, 검색 성능 향상)
CREATE INDEX IF NOT EXISTS "idx_campaigns_review_keywords" 
ON "public"."campaigns" USING "gin" ("review_keywords");
```

**체크리스트**:
- [ ] 마이그레이션 파일 생성
- [ ] `review_keywords` 컬럼 추가 (text[] 타입)
- [ ] 인덱스 추가 (GIN 인덱스, 배열 검색용)
- [ ] 마이그레이션 테스트

#### 1.2 RPC 함수 확인 및 업데이트

**파일**: `supabase/migrations/YYYYMMDDHHMMSS_add_review_keywords.sql`

**작업 내용**:
1. `create_campaign_with_points_v2` 함수 확인
   - `p_review_keywords` 파라미터가 함수 내부에서 사용되는지 확인
   - INSERT 문에 `review_keywords` 컬럼 포함 여부 확인
   - 미포함 시 추가

2. `update_campaign_v2` 함수 확인 및 업데이트
   - `p_review_keywords` 파라미터 추가
   - UPDATE 문에 `review_keywords` 컬럼 포함

**체크리스트**:
- [ ] `create_campaign_with_points_v2` 함수 내부 확인
- [ ] `create_campaign_with_points_v2` 함수에 `review_keywords` INSERT 추가
- [ ] `update_campaign_v2` 함수에 `p_review_keywords` 파라미터 추가
- [ ] `update_campaign_v2` 함수에 `review_keywords` UPDATE 추가
- [ ] RPC 함수 테스트

---

### Phase 2: Campaign 모델 업데이트

#### 2.1 Campaign 모델 필드 추가

**파일**: `lib/models/campaign.dart`

**작업 내용**:
1. 필드 추가
   ```dart
   // 리뷰 설정
   final String reviewType;
   final int reviewTextLength;
   final int reviewImageCount;
   final List<String>? reviewKeywords; // ✅ 추가
   ```

2. 생성자 업데이트
   ```dart
   Campaign({
     // ... 기존 필드들
     this.reviewKeywords, // ✅ 추가
   });
   ```

3. `fromJson` 메서드 업데이트
   ```dart
   reviewKeywords: json['review_keywords'] != null
       ? List<String>.from(json['review_keywords'])
       : null,
   ```

4. `toJson` 메서드 업데이트
   ```dart
   'review_keywords': reviewKeywords,
   ```

5. `copyWith` 메서드 업데이트
   ```dart
   List<String>? reviewKeywords,
   // ...
   reviewKeywords: reviewKeywords ?? this.reviewKeywords,
   ```

**체크리스트**:
- [ ] `reviewKeywords` 필드 추가
- [ ] 생성자에 파라미터 추가
- [ ] `fromJson` 메서드 업데이트
- [ ] `toJson` 메서드 업데이트
- [ ] `copyWith` 메서드 업데이트
- [ ] 모델 테스트

---

### Phase 3: 기본 리뷰 설정 서비스 업데이트

#### 3.1 기본 리뷰 설정 서비스에 키워드 추가

**파일**: `lib/services/campaign_default_schedule_service.dart`

**작업 내용**:
1. SharedPreferences 키 추가
   ```dart
   static const String _keyReviewKeywords = 'campaign_default_review_keywords';
   ```

2. 기본값 추가
   ```dart
   static const List<String> _defaultReviewKeywords = [];
   ```

3. 저장 메서드 추가
   ```dart
   static Future<void> saveDefaultReviewKeywords(List<String> keywords) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setStringList(_keyReviewKeywords, keywords);
   }
   ```

4. 로드 메서드 추가
   ```dart
   static Future<List<String>> loadDefaultReviewKeywords() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       return prefs.getStringList(_keyReviewKeywords) ?? _defaultReviewKeywords;
     } catch (e) {
       return _defaultReviewKeywords;
     }
   }
   ```

**체크리스트**:
- [ ] SharedPreferences 키 추가
- [ ] 기본값 상수 추가
- [ ] 저장 메서드 추가
- [ ] 로드 메서드 추가
- [ ] 기본 리뷰 설정 다이얼로그에 키워드 UI 추가 (선택사항)

---

### Phase 4: CampaignService 업데이트

#### 4.1 createCampaignV2 메서드 업데이트

**파일**: `lib/services/campaign_service.dart`

**작업 내용**:
1. 메서드 시그니처에 파라미터 추가
   ```dart
   Future<ApiResponse<Campaign>> createCampaignV2({
     // ... 기존 파라미터들
     List<String>? reviewKeywords, // ✅ 추가
   })
   ```

2. RPC 호출 파라미터에 추가
   ```dart
   final params = <String, dynamic>{
     // ... 기존 파라미터들
     'p_review_keywords': reviewKeywords, // ✅ 추가
   };
   ```

**체크리스트**:
- [ ] `createCampaignV2` 메서드에 `reviewKeywords` 파라미터 추가
- [ ] RPC 호출 파라미터에 `p_review_keywords` 추가
- [ ] 빈 리스트 처리 (null vs 빈 리스트)

#### 4.2 updateCampaignV2 메서드 업데이트

**파일**: `lib/services/campaign_service.dart`

**작업 내용**:
1. 메서드 시그니처에 파라미터 추가
   ```dart
   Future<ApiResponse<Campaign>> updateCampaignV2({
     // ... 기존 파라미터들
     List<String>? reviewKeywords, // ✅ 추가
   })
   ```

2. RPC 호출 파라미터에 추가
   ```dart
   final params = <String, dynamic>{
     // ... 기존 파라미터들
     'p_review_keywords': reviewKeywords, // ✅ 추가
   };
   ```

**체크리스트**:
- [ ] `updateCampaignV2` 메서드에 `reviewKeywords` 파라미터 추가
- [ ] RPC 호출 파라미터에 `p_review_keywords` 추가
- [ ] 빈 리스트 처리 (null vs 빈 리스트)

---

### Phase 5: UI 컴포넌트 구현

#### 5.1 리뷰 키워드 입력 위젯 생성

**파일**: `lib/widgets/review_keywords_input.dart` (신규 생성)

**작업 내용**:
- 체크박스로 활성화/비활성화
- 체크박스 체크 시 텍스트 필드 표시
- 텍스트 필드에서 콤마(,)로 구분하여 키워드 입력
- 입력된 키워드가 태그/칩 형태로 표시 (이미지 참조)
- 각 태그에 X 버튼으로 삭제 가능
- 최대 3개 키워드 제한
- 키워드 중복 방지
- 빈 키워드 방지

**UI 구조**:
```
┌─────────────────────────────────────┐
│ ☑ 리뷰 키워드 사용                  │
│                                     │
│ (체크박스 체크 시 아래 표시)        │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 키워드를 입력하세요 (콤마로 구분)│ │
│ └─────────────────────────────────┘ │
│                                     │
│ [전동 ×] [등받이쿠션 ×] [팅 ×]     │
│                                     │
│ (최대 3개까지 입력 가능)            │
└─────────────────────────────────────┘
```

**동작 방식**:
1. 체크박스가 체크되지 않으면 → 텍스트 필드와 태그 영역 숨김
2. 체크박스 체크 → 텍스트 필드와 태그 영역 표시
3. 텍스트 필드에 "전동, 등받이쿠션, 팅" 입력 후 콤마 입력
4. 자동으로 태그로 변환: `[전동 ×] [등받이쿠션 ×] [팅 ×]`
5. 태그의 X 버튼 클릭 시 해당 키워드 삭제
6. 최대 3개 제한: 3개 입력 시 텍스트 필드 비활성화 또는 경고 표시

**체크리스트**:
- [ ] `ReviewKeywordsInput` 위젯 생성
- [ ] 체크박스로 활성화/비활성화 기능
- [ ] 조건부 텍스트 필드 표시
- [ ] 콤마로 구분된 키워드 파싱
- [ ] 태그/칩 형태 UI 구현 (Chip 위젯 사용)
- [ ] 태그 삭제 기능 (X 버튼)
- [ ] 최대 3개 제한 구현
- [ ] 중복 방지 로직
- [ ] 빈 키워드 방지
- [ ] 반응형 디자인 적용

#### 5.2 캠페인 생성 화면에 UI 추가

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`

**작업 내용**:
1. 상태 변수 추가
   ```dart
   bool _useReviewKeywords = false; // 체크박스 상태
   List<String> _reviewKeywords = []; // 키워드 리스트
   ```

2. `_buildReviewSettings` 메서드에 위젯 추가
   ```dart
   Widget _buildReviewSettings() {
     return Card(
       // ... 기존 코드
       child: Column(
         children: [
           // ... 기존 필드들
           const SizedBox(height: 16),
           ReviewKeywordsInput(
             enabled: _useReviewKeywords,
             keywords: _reviewKeywords,
             onEnabledChanged: (enabled) {
               setState(() {
                 _useReviewKeywords = enabled;
                 if (!enabled) {
                   _reviewKeywords = []; // 비활성화 시 키워드 초기화
                 }
               });
             },
             onChanged: (keywords) {
               setState(() {
                 _reviewKeywords = keywords;
               });
             },
           ),
         ],
       ),
     );
   }
   ```

3. 기본 리뷰 설정 로드 시 키워드 로드
   ```dart
   Future<void> _loadDefaultReviewSettings() async {
     // ... 기존 코드
     final keywords = await CampaignDefaultScheduleService.loadDefaultReviewKeywords();
     setState(() {
       _reviewKeywords = keywords;
       _useReviewKeywords = keywords.isNotEmpty; // 키워드가 있으면 체크박스 체크
     });
   }
   ```

4. 캠페인 생성 시 키워드 전달
   ```dart
   final result = await _campaignService.createCampaignV2(
     // ... 기존 파라미터들
     reviewKeywords: _useReviewKeywords && _reviewKeywords.isNotEmpty 
         ? _reviewKeywords 
         : null,
   );
   ```

**체크리스트**:
- [ ] `_useReviewKeywords` 상태 변수 추가
- [ ] `_reviewKeywords` 상태 변수 추가
- [ ] `_buildReviewSettings`에 `ReviewKeywordsInput` 추가
- [ ] 기본 리뷰 설정 로드 시 키워드 및 체크박스 상태 로드
- [ ] 캠페인 생성 시 키워드 전달 (체크박스 상태 확인)
- [ ] 기본 리뷰 설정 다이얼로그에 키워드 UI 추가 (선택사항)

#### 5.3 캠페인 편집 화면에 UI 추가

**파일**: `lib/screens/campaign/campaign_edit_screen.dart`

**작업 내용**:
1. 상태 변수 추가
   ```dart
   bool _useReviewKeywords = false; // 체크박스 상태
   List<String> _reviewKeywords = []; // 키워드 리스트
   ```

2. `_loadCampaignData` 메서드에서 키워드 로드
   ```dart
   final keywords = campaign.reviewKeywords ?? [];
   setState(() {
     _reviewKeywords = keywords;
     _useReviewKeywords = keywords.isNotEmpty; // 키워드가 있으면 체크박스 체크
   });
   ```

3. `_buildReviewSettings` 메서드에 위젯 추가
   ```dart
   Widget _buildReviewSettings() {
     return Card(
       // ... 기존 코드
       child: Column(
         children: [
           // ... 기존 필드들
           const SizedBox(height: 16),
           ReviewKeywordsInput(
             enabled: _useReviewKeywords,
             keywords: _reviewKeywords,
             onEnabledChanged: (enabled) {
               setState(() {
                 _useReviewKeywords = enabled;
                 if (!enabled) {
                   _reviewKeywords = []; // 비활성화 시 키워드 초기화
                 }
               });
             },
             onChanged: (keywords) {
               setState(() {
                 _reviewKeywords = keywords;
               });
             },
           ),
         ],
       ),
     );
   }
   ```

4. 캠페인 업데이트 시 키워드 전달
   ```dart
   final result = await _campaignService.updateCampaignV2(
     // ... 기존 파라미터들
     reviewKeywords: _useReviewKeywords && _reviewKeywords.isNotEmpty 
         ? _reviewKeywords 
         : null,
   );
   ```

**체크리스트**:
- [ ] `_useReviewKeywords` 상태 변수 추가
- [ ] `_reviewKeywords` 상태 변수 추가
- [ ] `_loadCampaignData`에서 키워드 및 체크박스 상태 로드
- [ ] `_buildReviewSettings`에 `ReviewKeywordsInput` 추가
- [ ] 캠페인 업데이트 시 키워드 전달 (체크박스 상태 확인)

---

### Phase 6: 테스트 및 검증

#### 6.1 단위 테스트

**체크리스트**:
- [ ] Campaign 모델 테스트 (fromJson, toJson, copyWith)
- [ ] CampaignService 테스트 (createCampaignV2, updateCampaignV2)
- [ ] CampaignDefaultScheduleService 테스트 (키워드 저장/로드)

#### 6.2 통합 테스트

**체크리스트**:
- [ ] 캠페인 생성 시 키워드 저장 확인
- [ ] 캠페인 편집 시 키워드 업데이트 확인
- [ ] 캠페인 조회 시 키워드 로드 확인
- [ ] 기본 리뷰 설정 키워드 저장/로드 확인

#### 6.3 UI 테스트

**체크리스트**:
- [ ] 체크박스 활성화/비활성화 동작 확인
- [ ] 체크박스 체크 시 텍스트 필드 표시 확인
- [ ] 콤마로 구분된 키워드 입력 및 파싱 확인
- [ ] 태그/칩 형태로 키워드 표시 확인
- [ ] 태그 삭제 기능 확인
- [ ] 최대 3개 제한 확인
- [ ] 중복 방지 확인
- [ ] 빈 키워드 방지 확인
- [ ] 반응형 디자인 확인

---

## 📝 구현 세부사항

### 리뷰 키워드 입력 위젯 설계

```dart
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

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _currentKeywords = List.from(widget.keywords);
    _updateTextController();
  }

  @override
  void didUpdateWidget(ReviewKeywordsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keywords != oldWidget.keywords) {
      _currentKeywords = List.from(widget.keywords);
      _updateTextController();
    }
  }

  void _updateTextController() {
    _textController.text = _currentKeywords.join(', ');
  }

  void _onTextChanged(String text) {
    // 콤마로 구분하여 키워드 파싱
    final inputKeywords = text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // 최대 개수 제한
    if (inputKeywords.length > widget.maxKeywords) {
      // 마지막 키워드 제거
      inputKeywords.removeRange(widget.maxKeywords, inputKeywords.length);
      _textController.text = inputKeywords.join(', ');
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }

    // 중복 제거
    final uniqueKeywords = <String>[];
    for (final keyword in inputKeywords) {
      if (!uniqueKeywords.contains(keyword)) {
        uniqueKeywords.add(keyword);
      }
    }

    setState(() {
      _currentKeywords = uniqueKeywords;
    });

    widget.onChanged(_currentKeywords);
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _currentKeywords.remove(keyword);
      _updateTextController();
    });
    widget.onChanged(_currentKeywords);
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
            enabled: _currentKeywords.length < widget.maxKeywords,
          ),
          const SizedBox(height: 8),
          // 키워드 개수 표시
          if (_currentKeywords.length >= widget.maxKeywords)
            Text(
              '최대 ${widget.maxKeywords}개까지 입력 가능합니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
              ),
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
```

### UI 동작 흐름

1. **초기 상태**: 체크박스 해제 → 키워드 입력 영역 숨김
2. **체크박스 체크**: 키워드 입력 영역 표시
3. **키워드 입력**: 
   - 텍스트 필드에 "전동, 등받이쿠션, 팅" 입력
   - 콤마 입력 시 자동으로 파싱하여 태그 생성
4. **태그 표시**: `[전동 ×] [등받이쿠션 ×] [팅 ×]` 형태로 표시
5. **태그 삭제**: X 버튼 클릭 시 해당 키워드 제거
6. **최대 개수 제한**: 3개 입력 시 텍스트 필드 비활성화 및 경고 메시지 표시

### 데이터베이스 마이그레이션 예시

```sql
-- 리뷰 키워드 컬럼 추가
ALTER TABLE "public"."campaigns" 
ADD COLUMN IF NOT EXISTS "review_keywords" "text"[] DEFAULT NULL::"text"[];

-- 인덱스 추가 (배열 검색용)
CREATE INDEX IF NOT EXISTS "idx_campaigns_review_keywords" 
ON "public"."campaigns" USING "gin" ("review_keywords");

-- RPC 함수 업데이트 (create_campaign_with_points_v2)
-- INSERT 문에 review_keywords 추가 필요

-- RPC 함수 업데이트 (update_campaign_v2)
-- p_review_keywords 파라미터 추가 및 UPDATE 문에 review_keywords 추가 필요
```

---

## 🚨 주의사항

1. **데이터 타입 일관성**
   - 데이터베이스: `text[]` (PostgreSQL 배열)
   - Dart: `List<String>?`
   - JSON 변환 시 배열 형태 유지

2. **빈 리스트 처리**
   - 빈 리스트는 `null`로 저장하는 것이 좋음 (NULL vs 빈 배열)
   - 또는 빈 배열로 저장하고 프론트엔드에서 처리

3. **최대 개수 제한**
   - UI에서 3개 제한
   - 데이터베이스 레벨 제약조건 추가 고려 (CHECK 제약조건)

4. **기본값 처리**
   - 기본 리뷰 설정에서 키워드 기본값은 빈 리스트
   - 캠페인 생성 시 기본값 적용

5. **반응형 디자인**
   - `ReviewKeywordsInput` 위젯도 반응형 디자인 적용
   - 모바일/태블릿/데스크톱에서 적절한 레이아웃

---

## 📅 예상 일정

- **Phase 1**: 데이터베이스 및 RPC 함수 (1-2일)
- **Phase 2**: Campaign 모델 (0.5일)
- **Phase 3**: 기본 리뷰 설정 서비스 (0.5일)
- **Phase 4**: CampaignService (0.5일)
- **Phase 5**: UI 컴포넌트 (2-3일)
- **Phase 6**: 테스트 및 검증 (1-2일)

**총 예상 기간**: 5-9일

---

## ✅ 완료 체크리스트

### 데이터베이스
- [ ] 마이그레이션 파일 생성
- [ ] `review_keywords` 컬럼 추가
- [ ] 인덱스 추가
- [ ] RPC 함수 업데이트

### 모델 및 서비스
- [ ] Campaign 모델 업데이트
- [ ] CampaignService 업데이트
- [ ] CampaignDefaultScheduleService 업데이트

### UI
- [ ] ReviewKeywordsInput 위젯 생성 (체크박스 + 텍스트 필드 + 태그)
- [ ] 체크박스 활성화/비활성화 기능
- [ ] 콤마로 구분된 키워드 파싱
- [ ] 태그/칩 형태 UI 구현
- [ ] 캠페인 생성 화면에 UI 추가
- [ ] 캠페인 편집 화면에 UI 추가

### 테스트
- [ ] 단위 테스트
- [ ] 통합 테스트
- [ ] UI 테스트

---

## 📚 참고 자료

- [PostgreSQL 배열 타입 문서](https://www.postgresql.org/docs/current/arrays.html)
- [Flutter TextField 위젯 문서](https://api.flutter.dev/flutter/material/TextField-class.html)
- [Supabase RPC 함수 가이드](https://supabase.com/docs/guides/database/functions)

