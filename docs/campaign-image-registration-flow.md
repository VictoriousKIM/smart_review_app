# 캠페인 생성 시 이미지 등록 프로세스 상세 문서

## 📋 목차
1. [개요](#개요)
2. [전체 프로세스 흐름](#전체-프로세스-흐름)
3. [단계별 상세 설명](#단계별-상세-설명)
4. [기술적 세부사항](#기술적-세부사항)
5. [에러 처리 및 재시도 로직](#에러-처리-및-재시도-로직)
6. [최적화 전략](#최적화-전략)

---

## 개요

캠페인 생성 시 이미지 등록은 다음과 같은 주요 단계로 구성됩니다:

1. **이미지 선택**: 갤러리에서 주문 화면 캡처 이미지 선택
2. **이미지 분석**: AI를 통한 자동 정보 추출
3. **이미지 크롭**: 상품 이미지 영역 자동/수동 크롭
4. **이미지 업로드**: Cloudflare R2에 이미지 업로드
5. **캠페인 생성**: 추출된 정보와 이미지 URL로 캠페인 생성

---

## 전체 프로세스 흐름

```
[사용자] 이미지 선택
    ↓
[앱] 이미지 리사이징 및 캐싱
    ↓
[사용자] "자동 추출" 버튼 클릭
    ↓
[앱] Cloudflare Workers API 호출 (AI 이미지 분석)
    ↓
[Workers] Gemini/Claude API로 이미지 분석
    ↓
[앱] 추출된 정보를 폼에 자동 입력
    ↓
[앱] 상품 이미지 영역 자동 크롭 (백그라운드)
    ↓
[사용자] (선택) 이미지 크롭 수정
    ↓
[사용자] "캠페인 생성하기" 버튼 클릭
    ↓
[앱] Presigned URL 요청
    ↓
[Workers] Presigned URL 생성 및 반환
    ↓
[앱] Presigned URL로 R2에 직접 업로드
    ↓
[앱] Public URL 생성 및 캠페인 생성 API 호출
    ↓
[완료] 캠페인 생성 완료
```

---

## 단계별 상세 설명

### 1단계: 이미지 선택 (`_pickImage`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:266`

**프로세스**:
1. 사용자가 "이미지 선택" 버튼 클릭
2. `ImagePicker`를 통해 갤러리에서 이미지 선택
3. 이미지 크기 제한 검증 (최대 5MB)
4. 이미지 리사이징 (최대 1920x1920, 품질 85%)
5. 리사이징된 이미지를 `_capturedImage`에 저장

**주요 코드**:
```dart
final XFile? image = await _imagePicker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 70,
  maxWidth: 1920,
  maxHeight: 1920,
);

if (bytes.length > 5 * 1024 * 1024) {
  // 5MB 초과 시 에러
}

// 이미지 캐싱 및 리사이징
pendingImageBytes = await _getCachedOrResizeImage(bytes);
```

**최적화**:
- 즉시 로딩 상태 표시 (UI 블로킹 방지)
- 이미지 캐싱으로 중복 리사이징 방지
- Isolate를 사용한 백그라운드 리사이징

---

### 2단계: 이미지 분석 (`_extractFromImage`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:342`

**프로세스**:
1. 사용자가 "자동 추출" 버튼 클릭
2. `CampaignImageService.extractFromImage()` 호출
3. Cloudflare Workers API로 이미지 전송
4. Workers에서 Gemini/Claude API를 통해 이미지 분석
5. 추출된 정보를 폼에 자동 입력

**추출되는 정보**:
- `keyword`: 제품 카테고리
- `title`: 제품명
- `option`: 선택된 옵션
- `quantity`: 구매 개수
- `seller`: 판매자명
- `productNumber`: 상품번호
- `paymentAmount`: 결제금액
- `productImageCrop`: 상품 이미지 크롭 영역 좌표

**API 엔드포인트**:
```
POST https://smart-review-api.nightkille.workers.dev/api/analyze-campaign-image
Content-Type: multipart/form-data

FormData:
  - image: 이미지 파일 (PNG/JPEG)
  - imageWidth: 이미지 너비
  - imageHeight: 이미지 높이
```

**Workers 처리** (`workers/index.ts:1032`):
1. 이미지를 Base64로 인코딩
2. Gemini/Claude API에 프롬프트와 함께 전송
3. JSON 형식으로 구조화된 데이터 반환
4. 크롭 좌표는 비율(0.0-1.0) 또는 픽셀 좌표로 반환

**주요 코드**:
```dart
final extractedData = await _campaignImageService.extractFromImage(
  _capturedImage!,
);

// 폼에 자동 입력
_keywordController.text = extractedData['keyword'] ?? '';
_productNameController.text = extractedData['title'] ?? '';
// ... 기타 필드들
```

---

### 3단계: 이미지 크롭 (`_processCropInBackground`, `_cropProductImage`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:425`

**프로세스**:

#### 3-1. 자동 크롭 (AI 분석 결과 기반)
1. AI 분석 결과에서 `productImageCrop` 좌표 추출
2. 좌표 정규화 (이미지 크기에 맞게 조정)
3. Isolate에서 이미지 크롭 실행
4. 크롭된 이미지를 `_productImage`에 저장

#### 3-2. 수동 크롭 (사용자 편집)
1. 사용자가 "이미지 크롭" 버튼 클릭
2. `ImageCropEditor` 위젯으로 크롭 영역 선택
3. 크롭된 이미지 저장

**크롭 좌표 처리**:
- AI가 반환한 좌표는 비율(0.0-1.0) 또는 픽셀 좌표일 수 있음
- `_normalizeCropCoordinates`에서 실제 이미지 크기에 맞게 정규화
- 좌표가 이미지 범위를 벗어나면 자동으로 클램핑

**주요 코드**:
```dart
// 좌표 정규화
final normalizedResult = await compute(
  _normalizeCropCoordinates,
  _NormalizeCropParams(...),
);

// 이미지 크롭 (Isolate에서 실행)
final cropResult = await compute(
  _cropImageInIsolate,
  _CropImageParams(...),
);
```

**크롭 결과**:
- 크롭된 이미지는 JPEG 형식으로 인코딩 (품질 85%)
- `_productImage`에 저장되어 UI에 표시
- 캠페인 생성 시 이 이미지가 업로드됨

---

### 4단계: 이미지 업로드 (`_uploadProductImage`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:754`

**프로세스**:

#### 4-1. Presigned URL 요청
1. 파일명 생성: `product_{timestamp}.jpg`
2. Cloudflare Workers API에 Presigned URL 요청
3. 파일 경로: `campaign-images/{year}/{month}/{day}/{userId}_{timestamp}_{fileName}`
4. Presigned URL 유효기간: 15분 (PUT)

**API 엔드포인트**:
```
POST https://smart-review-api.nightkille.workers.dev/api/presigned-url
Content-Type: application/json

{
  "fileName": "product_1234567890.jpg",
  "userId": "user-uuid",
  "contentType": "image/jpeg",
  "fileType": "campaign-images",
  "method": "PUT"
}
```

**응답**:
```json
{
  "success": true,
  "url": "https://...r2.cloudflarestorage.com/...?X-Amz-...",
  "filePath": "campaign-images/2024/01/15/user-id_timestamp_product_1234567890.jpg",
  "expiresIn": 900,
  "expiresAt": 1234567890
}
```

#### 4-2. R2에 직접 업로드
1. Presigned URL로 HTTP PUT 요청
2. 이미지 바이트 데이터를 직접 전송
3. Content-Type: `image/jpeg` 설정

**주요 코드**:
```dart
await CloudflareWorkersService.uploadToPresignedUrl(
  presignedUrl: presignedUrlResponse.url,
  fileBytes: imageBytes,
  contentType: 'image/jpeg',
);
```

#### 4-3. Public URL 생성
1. R2는 Private Bucket이므로 직접 접근 불가
2. Cloudflare Workers를 통한 Public URL 생성
3. URL 형식: `{workersApiUrl}/api/files/{filePath}`

**Public URL 예시**:
```
https://smart-review-api.nightkille.workers.dev/api/files/campaign-images/2024/01/15/user-id_timestamp_product_1234567890.jpg
```

**업로드 진행률 표시**:
- 10%: Presigned URL 요청 완료
- 30%: 업로드 시작
- 100%: 업로드 완료

---

### 5단계: 캠페인 생성 (`_createCampaign`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:974`

**프로세스**:
1. 이미지 업로드 완료 후 Public URL 획득
2. `CampaignService.createCampaignV2()` 호출
3. 추출된 정보와 이미지 URL을 포함하여 캠페인 생성

**이미지 우선순위**:
1. `_productImage`가 있으면 크롭된 이미지 업로드
2. 없으면 `_capturedImage` 업로드
3. 둘 다 없으면 이미지 없이 캠페인 생성

**주요 코드**:
```dart
String? productImageUrl;
if (_productImage != null) {
  productImageUrl = await _uploadProductImage(_productImage!);
} else if (_capturedImage != null) {
  productImageUrl = await _uploadProductImage(_capturedImage!);
}

final response = await _campaignService.createCampaignV2(
  // ... 기타 필드들
  productImageUrl: productImageUrl,
);
```

---

## 기술적 세부사항

### 이미지 처리 최적화

#### 1. 이미지 캐싱
- **목적**: 동일한 이미지의 중복 리사이징 방지
- **구현**: `Map<String, Uint8List> _imageCache`
- **키 생성**: `'${originalBytes.lengthInBytes}_${originalBytes.hashCode}'`

#### 2. Isolate를 사용한 백그라운드 처리
- **목적**: 메인 스레드 블로킹 방지
- **사용 위치**:
  - 이미지 리사이징: `_resizeImageInIsolate`
  - 이미지 크롭: `_cropImageInIsolate`
  - 좌표 정규화: `_normalizeCropCoordinates`
  - 이미지 디코딩: `_decodeImageInIsolate`

#### 3. 비동기 작업 분리
- **즉시 실행**: UI 상태 업데이트 (로딩 표시)
- **마이크로태스크**: 무거운 작업 (이미지 분석, 업로드)
- **백그라운드**: 크롭 작업 (UI와 독립적)

### Presigned URL 방식

**장점**:
- 서버 부하 감소 (직접 R2 업로드)
- 보안성 향상 (임시 URL, 만료 시간)
- 확장성 (서버를 거치지 않음)

**보안**:
- AWS Signature V4 사용
- URL 만료 시간: 15분 (PUT), 1시간 (GET)
- 사용자별 파일 경로 분리

### 파일 경로 구조

```
campaign-images/
  └── {year}/
      └── {month}/
          └── {day}/
              └── {userId}_{timestamp}_{fileName}
```

**예시**:
```
campaign-images/2024/01/15/abc123_1705123456789_product_1234567890.jpg
```

---

## 에러 처리 및 재시도 로직

### 업로드 재시도 로직

**최대 재시도 횟수**: 3회

**재시도 조건**:
- 네트워크 에러
- 타임아웃 에러
- 서버 에러 (5xx)

**재시도 불가능한 에러**:
- 인증 에러 (401 Unauthorized)
- 잘못된 요청 (400 Bad Request)
- 파일 크기 초과

**재시도 전략**:
- 지수 백오프: `attempt * 2` 초 대기
- 사용자 확인 다이얼로그 표시
- 진행률 초기화 후 재시도

**주요 코드**:
```dart
while (attempt < maxRetries) {
  try {
    // 업로드 시도
  } catch (e) {
    if (_isNonRetryableError(e)) {
      // 재시도 불가능한 에러
      return null;
    }
    
    if (attempt >= maxRetries) {
      // 최대 재시도 횟수 초과
      return null;
    }
    
    // 재시도 전 대기
    await Future.delayed(Duration(seconds: attempt * 2));
  }
}
```

### 타임아웃 설정

- **Presigned URL 요청**: 10초
- **이미지 업로드**: 30초
- **이미지 분석**: 기본 HTTP 타임아웃

### 에러 메시지 처리

- **사용자 친화적 메시지**: `ErrorHandler.getUserFriendlyMessage()`
- **에러 타입 감지**: `ErrorHandler.detectErrorType()`
- **네트워크 에러 로깅**: `ErrorHandler.handleNetworkError()`

---

## 최적화 전략

### 1. UI 반응성 향상

**문제**: 이미지 처리 시 UI 블로킹

**해결**:
- 즉시 로딩 상태 표시
- 무거운 작업을 마이크로태스크로 분리
- Isolate를 사용한 백그라운드 처리

### 2. 메모리 최적화

**문제**: 대용량 이미지로 인한 메모리 부족

**해결**:
- 이미지 리사이징 (최대 1920x1920)
- JPEG 품질 조정 (85%)
- 이미지 캐싱으로 중복 처리 방지

### 3. 네트워크 최적화

**문제**: 이미지 업로드 실패 및 느린 속도

**해결**:
- Presigned URL 방식 (직접 R2 업로드)
- 재시도 로직 (최대 3회)
- 진행률 표시로 사용자 경험 향상

### 4. 비용 최적화

**문제**: AI API 호출 비용

**해결**:
- 이미지 크기 제한 (5MB)
- 이미지 리사이징으로 전송 크기 감소
- 실패 시 재시도로 불필요한 호출 방지

---

## 관련 파일 목록

### Flutter 앱
- `lib/screens/campaign/campaign_creation_screen.dart`: 메인 UI 및 로직
- `lib/services/campaign_image_service.dart`: 이미지 분석 서비스
- `lib/services/cloudflare_workers_service.dart`: 업로드 서비스
- `lib/widgets/image_crop_editor.dart`: 이미지 크롭 위젯

### Cloudflare Workers
- `workers/index.ts`: API 엔드포인트 및 이미지 분석 로직
- `workers/functions/analyze-campaign-image.ts`: 이미지 분석 함수

### 설정 파일
- `lib/config/supabase_config.dart`: Workers API URL 설정

---

## 참고사항

### 이미지 형식 지원
- **입력**: PNG, JPEG
- **출력**: JPEG (품질 85%)

### 이미지 크기 제한
- **최대 파일 크기**: 5MB
- **최대 해상도**: 1920x1920 (리사이징 후)

### AI 모델
- **주요 모델**: Google Gemini, Anthropic Claude
- **폴백**: 여러 모델 순차 시도

### 보안 고려사항
- Presigned URL은 15분 후 만료
- 사용자별 파일 경로 분리
- R2는 Private Bucket (Workers를 통해서만 접근)

---

## 트러블슈팅

### 이미지 분석 실패
- **원인**: 이미지 품질 저하, AI 모델 한계
- **해결**: 수동 입력 옵션 제공

### 업로드 실패
- **원인**: 네트워크 문제, Presigned URL 만료
- **해결**: 자동 재시도 (최대 3회)

### 크롭 좌표 오류
- **원인**: AI 분석 오류, 이미지 크기 불일치
- **해결**: 좌표 정규화 및 클램핑, 수동 크롭 옵션

---

**문서 작성일**: 2024-01-15  
**최종 수정일**: 2024-01-15  
**작성자**: AI Assistant

