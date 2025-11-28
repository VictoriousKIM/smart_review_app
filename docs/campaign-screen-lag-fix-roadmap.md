# 캠페인 생성/편집 스크린 렉 해결 로드맵

**작성일**: 2025년 11월 28일  
**대상 파일**: 
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/screens/campaign/campaign_edit_screen.dart`
- `lib/services/campaign_image_service.dart`

---

## 📋 문제 분석

### 1. 현상
- 캠페인 생성/편집 스크린 진입 시 UI 애니메이션 끊김
- "자동 추출" 버튼 클릭 시 UI 프리징 (약 2-5초)
- 특히 **웹 환경**에서 심각함

### 2. 근본 원인

#### 2.1 화면 진입 시 렉
| 원인 | 설명 | 영향도 |
|------|------|--------|
| 동시다발적 초기화 | 500ms 지연 후에도 여러 비동기 작업이 한꺼번에 실행 | 🔴 높음 |
| API 호출 블로킹 | `_loadCompanyBalance()`, `_loadCampaignData()` 실행 | 🟡 중간 |
| 컨트롤러 대량 업데이트 | 20개 이상의 TextEditingController 초기화 | 🟡 중간 |
| 비용 계산 즉시 실행 | 초기화 직후 `_calculateCost()` 호출 | 🟢 낮음 |

#### 2.2 자동추출 버튼 클릭 시 렉
| 원인 | 설명 | 영향도 |
|------|------|--------|
| 이미지 디코딩 | `img.decodeImage()` - 웹에서 메인 스레드 블로킹 | 🔴 높음 |
| AI API 호출 대기 | 네트워크 요청 중 UI 업데이트 없음 | 🟡 중간 |
| 크롭 처리 | `_cropImageDirect()` - 웹에서 메인 스레드 실행 | 🔴 높음 |
| 다중 setState | 분석 결과로 여러 컨트롤러 업데이트 시 연속 리렌더링 | 🟡 중간 |

#### 2.3 웹 환경 특수 문제
```dart
// ❌ 현재: 웹에서 compute() 사용 불가 → 메인 스레드에서 직접 처리
if (kIsWeb) {
  return _resizeImageDirect(originalBytes, 1920, 1920, 85);
}

// ❌ 이미지 디코딩이 메인 스레드 블로킹
final image = img.decodeImage(imageBytes);  // 큰 이미지 = 심각한 렉
```

---

## 🗺️ 해결 로드맵

### Phase 1: 즉각적 개선 (1-2일) 🚀

#### 1.1 스켈레톤 UI 도입
**목표**: 화면 진입 즉시 시각적 피드백 제공

```dart
// lib/screens/campaign/campaign_creation_screen.dart

@override
Widget build(BuildContext context) {
  // 초기화 완료 전까지 스켈레톤 UI 표시
  if (!_isInitialized) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠페인 생성')),
      body: const _CampaignFormSkeleton(),  // 스켈레톤 위젯
    );
  }
  
  return Scaffold(
    // ... 실제 폼
  );
}
```

#### 1.2 초기화 더 세분화
**목표**: 애니메이션 완료 후 단계적 로딩

```dart
// 변경 전
Future.delayed(const Duration(milliseconds: 500), () {
  if (mounted) {
    _initializeForWeb();  // 한 번에 모든 초기화
  }
});

// 변경 후
Future.delayed(const Duration(milliseconds: 600), () async {
  if (!mounted) return;
  
  // 1단계: UI 먼저 표시 (50ms 후)
  setState(() => _isInitialized = true);
  
  // 2단계: 잔액 로딩 (100ms 후)
  await Future.delayed(const Duration(milliseconds: 100));
  if (mounted) _loadCompanyBalance();
  
  // 3단계: 리스너 설정 (200ms 후)
  await Future.delayed(const Duration(milliseconds: 200));
  if (mounted) {
    _ignoreCostListeners = true;
    _setupCostListeners();
    _updateDateTimeControllers();
    _ignoreCostListeners = false;
    _calculateCost();
  }
});
```

#### 1.3 자동추출 버튼 즉시 피드백
**목표**: 버튼 클릭 즉시 "분석 중" 상태 표시

```dart
Future<void> _extractFromImage() async {
  if (_capturedImage == null) {
    setState(() => _errorMessage = '먼저 이미지를 선택해주세요.');
    return;
  }

  // ✅ 즉시 로딩 상태 표시 (동기)
  setState(() {
    _isAnalyzing = true;
    _errorMessage = null;
  });

  // ✅ UI 업데이트가 렌더링될 시간 확보
  await Future.delayed(const Duration(milliseconds: 50));
  
  // 이후 비동기 작업...
}
```

---

### Phase 2: 이미지 처리 최적화 (3-5일) 🖼️

#### 2.1 Web Worker 도입 (웹 전용)
**목표**: 이미지 처리를 별도 스레드로 분리

```dart
// lib/services/image_worker_service.dart (신규 생성)

import 'dart:html' as html;
import 'dart:typed_data';

class ImageWorkerService {
  static html.Worker? _worker;
  
  /// Web Worker 초기화
  static void initialize() {
    if (kIsWeb) {
      _worker = html.Worker('image_worker.js');
    }
  }
  
  /// 이미지 리사이징 (Web Worker에서 실행)
  static Future<Uint8List> resizeImage(Uint8List bytes, int maxWidth, int maxHeight) async {
    if (!kIsWeb || _worker == null) {
      return _resizeImageDirect(bytes, maxWidth, maxHeight);
    }
    
    final completer = Completer<Uint8List>();
    
    _worker!.onMessage.listen((event) {
      completer.complete(Uint8List.fromList(event.data));
    });
    
    _worker!.postMessage({
      'action': 'resize',
      'bytes': bytes,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
    });
    
    return completer.future;
  }
}
```

```javascript
// web/image_worker.js (신규 생성)

self.onmessage = async function(e) {
  const { action, bytes, maxWidth, maxHeight } = e.data;
  
  if (action === 'resize') {
    // OffscreenCanvas를 사용한 이미지 리사이징
    const blob = new Blob([bytes]);
    const bitmap = await createImageBitmap(blob);
    
    // 크기 계산
    let width = bitmap.width;
    let height = bitmap.height;
    
    if (width > maxWidth || height > maxHeight) {
      const ratio = Math.min(maxWidth / width, maxHeight / height);
      width = Math.round(width * ratio);
      height = Math.round(height * ratio);
    }
    
    // OffscreenCanvas에서 리사이징
    const canvas = new OffscreenCanvas(width, height);
    const ctx = canvas.getContext('2d');
    ctx.drawImage(bitmap, 0, 0, width, height);
    
    // Blob으로 변환
    const resultBlob = await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.85 });
    const arrayBuffer = await resultBlob.arrayBuffer();
    
    self.postMessage(new Uint8List(arrayBuffer));
  }
};
```

#### 2.2 분석용 저해상도 이미지 사용
**목표**: AI 분석에 작은 이미지 사용

```dart
// lib/services/campaign_image_service.dart 수정

Future<Map<String, dynamic>?> extractFromImage(Uint8List imageBytes) async {
  try {
    print('🔍 이미지 분석 시작...');

    // ✅ 분석용으로 작은 이미지 생성 (1024px 이하)
    final analysisBytes = await _prepareForAnalysis(imageBytes, maxSize: 1024);
    
    // ... API 호출
  } catch (e) {
    print('❌ 이미지 분석 실패: $e');
    return null;
  }
}

/// 분석용 이미지 준비 (저해상도)
Future<Uint8List> _prepareForAnalysis(Uint8List bytes, {int maxSize = 1024}) async {
  if (kIsWeb) {
    return await ImageWorkerService.resizeImage(bytes, maxSize, maxSize);
  } else {
    return await compute(_resizeForAnalysis, _ResizeParams(bytes, maxSize));
  }
}
```

#### 2.3 프로그레시브 이미지 로딩
**목표**: 썸네일 먼저 표시 → 원본으로 교체

```dart
// 1. 이미지 선택 시 썸네일 먼저 생성
Future<void> _pickImage() async {
  setState(() {
    _isLoadingImage = true;
    _errorMessage = null;
  });

  try {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      
      // ✅ 1단계: 썸네일 먼저 생성 & 표시
      final thumbnail = await _generateThumbnail(bytes, maxSize: 300);
      if (mounted) {
        setState(() {
          _thumbnailImage = thumbnail;  // 썸네일 먼저 표시
          _isLoadingImage = false;
        });
      }
      
      // ✅ 2단계: 원본 이미지 백그라운드 처리
      _processFullImageInBackground(bytes);
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoadingImage = false;
        _errorMessage = '이미지 선택 실패: $e';
      });
    }
  }
}
```

---

### Phase 3: UI 렌더링 최적화 (3-5일) 🎨

#### 3.1 섹션별 레이지 로딩
**목표**: 화면에 보이는 섹션만 렌더링

```dart
// lib/widgets/lazy_section.dart (신규 생성)

class LazySection extends StatefulWidget {
  final Widget Function() builder;
  final Widget placeholder;
  
  const LazySection({
    required this.builder,
    this.placeholder = const SizedBox(height: 100),
  });
  
  @override
  State<LazySection> createState() => _LazySectionState();
}

class _LazySectionState extends State<LazySection> {
  bool _isVisible = false;
  
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('lazy_${hashCode}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0 && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      child: _isVisible ? widget.builder() : widget.placeholder,
    );
  }
}
```

```dart
// campaign_creation_screen.dart에서 사용

Column(
  children: [
    // 상단 섹션은 즉시 로드
    _buildCampaignTypeSection(),
    _buildImageSection(),
    
    // 하단 섹션은 레이지 로드
    LazySection(
      builder: () => _buildProductInfoSection(),
      placeholder: _buildSectionSkeleton(),
    ),
    LazySection(
      builder: () => _buildReviewSettings(),
      placeholder: _buildSectionSkeleton(),
    ),
    // ...
  ],
)
```

#### 3.2 TextField 입력 최적화
**목표**: 입력 중 불필요한 리빌드 방지

```dart
// lib/widgets/optimized_text_field.dart (신규 생성)

class OptimizedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String>? onChanged;
  
  @override
  State<OptimizedTextField> createState() => _OptimizedTextFieldState();
}

class _OptimizedTextFieldState extends State<OptimizedTextField> {
  Timer? _debounceTimer;
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(labelText: widget.labelText),
      onChanged: (value) {
        // ✅ 디바운싱으로 리빌드 최소화
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          widget.onChanged?.call(value);
        });
      },
    );
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

#### 3.3 애니메이션 중 무거운 작업 방지
**목표**: 페이지 전환 애니메이션 완료 확인

```dart
// lib/utils/navigation_utils.dart (신규 생성)

class NavigationUtils {
  /// 페이지 전환 애니메이션 완료 대기
  static Future<void> waitForTransition(BuildContext context) async {
    final route = ModalRoute.of(context);
    if (route != null) {
      await route.completed;
    }
    // 추가 버퍼 시간
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

// 사용 예시
@override
void initState() {
  super.initState();
  
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NavigationUtils.waitForTransition(context);
    if (mounted) {
      _initializeScreen();
    }
  });
}
```

---

### Phase 4: 아키텍처 개선 (1-2주) 🏗️

#### 4.1 이미지 처리 전용 서비스 분리
**목표**: 이미지 관련 로직을 독립 서비스로 분리

```dart
// lib/services/image_processing_service.dart (신규 생성)

class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._();
  factory ImageProcessingService() => _instance;
  ImageProcessingService._();
  
  /// 이미지 처리 큐
  final _processingQueue = StreamController<_ImageTask>();
  
  /// 결과 스트림
  Stream<ImageResult> get results => _resultController.stream;
  final _resultController = StreamController<ImageResult>.broadcast();
  
  void initialize() {
    _processingQueue.stream.listen(_processTask);
  }
  
  /// 이미지 분석 요청 (비동기)
  void requestAnalysis(String taskId, Uint8List imageBytes) {
    _processingQueue.add(_ImageTask(
      id: taskId,
      type: TaskType.analyze,
      bytes: imageBytes,
    ));
  }
  
  /// 이미지 크롭 요청 (비동기)
  void requestCrop(String taskId, Uint8List bytes, Rect cropRect) {
    _processingQueue.add(_ImageTask(
      id: taskId,
      type: TaskType.crop,
      bytes: bytes,
      cropRect: cropRect,
    ));
  }
  
  Future<void> _processTask(_ImageTask task) async {
    try {
      switch (task.type) {
        case TaskType.analyze:
          final result = await _analyzeImage(task.bytes);
          _resultController.add(ImageResult.analysis(task.id, result));
          break;
        case TaskType.crop:
          final result = await _cropImage(task.bytes, task.cropRect!);
          _resultController.add(ImageResult.crop(task.id, result));
          break;
      }
    } catch (e) {
      _resultController.add(ImageResult.error(task.id, e.toString()));
    }
  }
}
```

#### 4.2 Riverpod StateNotifier로 상태 관리 개선
**목표**: 필요한 부분만 리빌드

```dart
// lib/providers/campaign_form_provider.dart (신규 생성)

class CampaignFormState {
  final bool isLoading;
  final bool isAnalyzing;
  final Uint8List? capturedImage;
  final Uint8List? productImage;
  final String? errorMessage;
  final int totalCost;
  final int currentBalance;
  // ...
  
  CampaignFormState copyWith({...});
}

class CampaignFormNotifier extends StateNotifier<CampaignFormState> {
  CampaignFormNotifier() : super(CampaignFormState.initial());
  
  Future<void> pickImage() async {
    state = state.copyWith(isLoading: true);
    // ...
  }
  
  Future<void> analyzeImage() async {
    state = state.copyWith(isAnalyzing: true);
    // ...
  }
}

final campaignFormProvider = StateNotifierProvider<CampaignFormNotifier, CampaignFormState>((ref) {
  return CampaignFormNotifier();
});
```

```dart
// 화면에서 사용 (선택적 리빌드)

// ✅ 이미지만 구독
Consumer(
  builder: (context, ref, _) {
    final image = ref.watch(campaignFormProvider.select((s) => s.capturedImage));
    return image != null ? Image.memory(image) : const Placeholder();
  },
)

// ✅ 로딩 상태만 구독
Consumer(
  builder: (context, ref, _) {
    final isAnalyzing = ref.watch(campaignFormProvider.select((s) => s.isAnalyzing));
    return CustomButton(
      text: '자동 추출',
      isLoading: isAnalyzing,
      onPressed: () => ref.read(campaignFormProvider.notifier).analyzeImage(),
    );
  },
)
```

---

## 📊 예상 효과

| Phase | 작업 | 예상 개선 효과 |
|-------|------|----------------|
| 1 | 스켈레톤 UI | 체감 로딩 시간 50% 감소 |
| 1 | 초기화 세분화 | 화면 진입 렉 60% 감소 |
| 2 | Web Worker | 웹 이미지 처리 렉 80% 제거 |
| 2 | 저해상도 분석 | API 응답 시간 30% 단축 |
| 3 | 레이지 로딩 | 초기 렌더링 시간 40% 단축 |
| 3 | TextField 최적화 | 입력 중 렉 제거 |
| 4 | 아키텍처 개선 | 전체적인 성능 안정화 |

---

## 🔧 즉시 적용 가능한 Quick Fix

아래 코드를 `campaign_creation_screen.dart`에 즉시 적용하면 체감 성능이 개선됩니다:

### Quick Fix 1: 자동추출 버튼 피드백 개선

```dart
// _extractFromImage() 메서드 수정
Future<void> _extractFromImage() async {
  if (_capturedImage == null) {
    setState(() => _errorMessage = '먼저 이미지를 선택해주세요.');
    return;
  }

  // ✅ Step 1: 즉시 로딩 상태 표시
  setState(() {
    _isAnalyzing = true;
    _errorMessage = null;
  });

  // ✅ Step 2: UI가 렌더링될 시간 확보 (중요!)
  await Future.delayed(const Duration(milliseconds: 50));

  // ✅ Step 3: 나머지 작업은 기존 로직 유지
  Future.microtask(() async {
    // ... 기존 코드
  });
}
```

### Quick Fix 2: 화면 진입 초기화 개선

```dart
// initState() 수정
@override
void initState() {
  super.initState();

  _applyStartDateTimeController = TextEditingController();
  _applyEndDateTimeController = TextEditingController();
  _reviewStartDateTimeController = TextEditingController();
  _reviewEndDateTimeController = TextEditingController();

  // ✅ 더 긴 지연 + 프레임 콜백 조합
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        if (kIsWeb) {
          _initializeForWeb();
        } else {
          _initializeInStages();
        }
      }
    });
  });
}
```

---

## 📝 우선순위 정리

1. **🔴 긴급 (즉시)**: Quick Fix 1, 2 적용
2. **🟠 높음 (Phase 1)**: 스켈레톤 UI, 초기화 세분화
3. **🟡 중간 (Phase 2)**: Web Worker 도입, 이미지 최적화
4. **🟢 낮음 (Phase 3-4)**: 레이지 로딩, 아키텍처 개선

---

## 참고 자료

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Isolates and compute()](https://docs.flutter.dev/perf/isolates)
- [Web Workers API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API)

