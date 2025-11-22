# R2 업로드 로직 문서

## 개요

이 문서는 Smart Review 앱에서 Cloudflare R2로 파일을 업로드하는 모든 로직을 설명합니다.

## 업로드 방식

R2 업로드는 두 가지 방식으로 구현되어 있습니다:

1. **Presigned URL 방식** (권장) - 클라이언트에서 직접 R2에 업로드
2. **Workers API 방식** - Workers를 통한 서버 사이드 업로드

---

## 1. Presigned URL 방식 (직접 업로드)

### 개요
클라이언트(Flutter)에서 Presigned URL을 받아 R2에 직접 업로드하는 방식입니다. Workers 서버의 부하를 줄이고 업로드 속도를 향상시킵니다.

### 사용 사례
- 캠페인 상품 이미지 업로드
- 사업자등록증 업로드

### 업로드 흐름

```
Flutter 앱
  ↓
1. Presigned URL 요청 (POST /api/presigned-url)
  ↓
Workers API
  ↓
2. AWS Signature V4로 Presigned URL 생성
  ↓
Flutter 앱
  ↓
3. Presigned URL로 직접 R2 업로드 (PUT)
  ↓
R2 Storage
```

### 구현 위치

#### Workers API (`workers/index.ts`)

**Presigned URL 생성 엔드포인트:**
```typescript
POST /api/presigned-url
```

**요청 파라미터:**
- `fileName`: 파일명
- `userId`: 사용자 ID
- `contentType`: 파일 MIME 타입
- `fileType`: 파일 타입 (예: `campaign-images`, `business-registration`)
- `method`: HTTP 메서드 (기본값: `PUT`)

**파일 경로 형식:**
```
{fileType}/{YYYYMMDDHHMMSS}_{fileName}
```

**예시:**
```
campaign-images/20250115143025_product.jpg
business-registration/20250115143025.png
```

**Presigned URL 유효기간:**
- PUT: 15분 (900초)
- GET: 1시간 (3600초)

**주요 함수:**
- `handlePresignedUrl()`: Presigned URL 생성 요청 처리
- `createPresignedUrlSignature()`: AWS Signature V4로 Presigned URL 생성
- `generateFilePath()`: 파일 경로 생성

#### Flutter 서비스 (`lib/services/cloudflare_workers_service.dart`)

**Presigned URL 요청:**
```dart
static Future<PresignedUrlResponse> getPresignedUrl({
  required String fileName,
  required String userId,
  required String contentType,
  required String fileType,
  String method = 'PUT',
})
```

**Presigned URL로 업로드:**
```dart
static Future<void> uploadToPresignedUrl({
  required String presignedUrl,
  required Uint8List fileBytes,
  required String contentType,
})
```

### 사용 예시

#### 캠페인 이미지 업로드 (`lib/screens/campaign/campaign_creation_screen.dart`)

```dart
Future<String?> _uploadProductImage(Uint8List imageBytes) async {
  // 1. Presigned URL 요청
  final presignedUrlResponse = await CloudflareWorkersService.getPresignedUrl(
    fileName: 'product_${timestamp}.jpg',
    userId: user.id,
    contentType: 'image/jpeg',
    fileType: 'campaign-images',
    method: 'PUT',
  );

  // 2. Presigned URL로 직접 업로드
  await CloudflareWorkersService.uploadToPresignedUrl(
    presignedUrl: presignedUrlResponse.url,
    fileBytes: imageBytes,
    contentType: 'image/jpeg',
  );

  // 3. Public URL 생성 (Workers API를 통해 제공)
  final publicUrl = '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrlResponse.filePath}';
  return publicUrl;
}
```

#### 사업자등록증 업로드 (`lib/screens/mypage/common/business_registration_form.dart`)

```dart
// 1. Workers API로 검증 및 Presigned URL 받기
final response = await http.post(
  Uri.parse('$workersApiUrl/api/verify-and-register'),
  body: json.encode({
    'image': base64Image,
    'fileName': fileName,
    'userId': userId,
  }),
);

final presignedUrl = responseData['presignedUrl'] as String;
final publicUrl = responseData['publicUrl'] as String;

// 2. Presigned URL로 직접 업로드
final uploadResponse = await http.put(
  Uri.parse(presignedUrl),
  headers: {'Content-Type': 'image/png'},
  body: fileBytes,
);
```

---

## 2. Workers API 방식 (서버 사이드 업로드)

### 개요
Workers API를 통해 파일을 업로드하는 방식입니다. Workers가 R2에 직접 업로드합니다.

### 사용 사례
- 일반적인 파일 업로드 (현재는 Presigned URL 방식으로 대체됨)

### 업로드 흐름

```
Flutter 앱
  ↓
1. Multipart Form Data로 파일 업로드 (POST /api/upload)
  ↓
Workers API
  ↓
2. R2에 파일 저장
  ↓
R2 Storage
  ↓
3. Public URL 반환
```

### 구현 위치

#### Workers API (`workers/index.ts`)

**업로드 엔드포인트:**
```typescript
POST /api/upload
```

**요청 형식:**
- `Content-Type: multipart/form-data`
- `file`: 파일 (File 객체)
- `userId`: 사용자 ID
- `fileType`: 파일 타입

**응답:**
```json
{
  "success": true,
  "url": "https://...r2.cloudflarestorage.com/...",
  "key": "fileType/20250115143025_filename.jpg"
}
```

**주요 함수:**
- `handleUpload()`: 파일 업로드 요청 처리

#### Flutter 서비스 (`lib/services/cloudflare_workers_service.dart`)

```dart
static Future<UploadResponse> uploadFile({
  required Uint8List fileBytes,
  required String fileName,
  required String userId,
  required String fileType,
  required String contentType,
})
```

---

## 3. 파일 조회

### Presigned URL 방식 (조회용)

**엔드포인트:**
```typescript
POST /api/presigned-url-view
```

**요청:**
```json
{
  "filePath": "campaign-images/20250115143025_filename.jpg"
}
```

**응답:**
```json
{
  "success": true,
  "url": "https://...r2.cloudflarestorage.com/...?X-Amz-Signature=...",
  "expiresIn": 3600,
  "method": "GET"
}
```

### Workers API를 통한 조회

**엔드포인트:**
```typescript
GET /api/files/{filePath}
```

**Flutter 서비스:**
```dart
static Future<Uint8List> getFile(String filePath)
```

---

## 4. 파일 삭제

### 엔드포인트
```typescript
POST /api/delete-file
```

**요청:**
```json
{
  "fileUrl": "https://...r2.cloudflarestorage.com/business-registration/..."
}
```

**주요 함수:**
- `handleDeleteFile()`: 파일 삭제 요청 처리

**사용 시나리오:**
- DB 저장 실패 시 롤백용
- 사업자등록증 재등록 시 기존 파일 삭제

---

## 5. 파일 경로 구조

### 경로 형식
```
{fileType}/{YYYYMMDDHHMMSS}_{fileName}
```

### 파일 타입 (fileType)
- `campaign-images`: 캠페인 상품 이미지
- `business-registration`: 사업자등록증
- 기타 사용자 정의 타입

### 예시
```
campaign-images/20250115143025_product.jpg
business-registration/20250115143025.png
```

---

## 6. R2 메타데이터

### HTTP 메타데이터
- `contentType`: 파일 MIME 타입
- `contentEncoding`: 인코딩 방식 (선택)

### 커스텀 메타데이터
- `userId`: 업로드한 사용자 ID
- `fileType`: 파일 타입
- `uploadedAt`: 업로드 시간 (ISO 8601)

### 저장 예시
```typescript
await env.FILES.put(key, file.stream(), {
  httpMetadata: {
    contentType: file.type,
  },
  customMetadata: {
    userId,
    fileType,
    uploadedAt: new Date().toISOString(),
  },
});
```

---

## 7. 에러 처리

### Presigned URL 생성 실패
- 타임아웃: 10초
- 재시도: 최대 3회 (지수 백오프)
- 에러 타입 감지 및 사용자 친화적 메시지

### 업로드 실패
- 타임아웃: 30초
- 재시도: 최대 3회
- 재시도 불가능한 에러: 즉시 종료
  - 인증 실패
  - 잘못된 요청 형식

### 롤백 처리
- 사업자등록증 업로드: DB 저장 실패 시 파일 업로드하지 않음
- 파일 업로드 실패 시: DB 롤백 (사업자등록증)

---

## 8. 보안 고려사항

### Presigned URL
- AWS Signature V4 사용
- 유효기간 제한 (PUT: 15분, GET: 1시간)
- 파일 경로에 사용자 ID 포함으로 권한 검증

### Workers API
- CORS 헤더 설정
- 필수 필드 검증
- 파일 타입 검증 (사업자등록증의 경우 AI 검증)

---

## 9. 환경 변수

### Workers 환경 변수
- `R2_ACCOUNT_ID`: R2 계정 ID
- `R2_ACCESS_KEY_ID`: R2 Access Key ID
- `R2_SECRET_ACCESS_KEY`: R2 Secret Access Key
- `R2_BUCKET_NAME`: R2 버킷 이름
- `R2_PUBLIC_URL`: R2 Public URL

### 설정 위치
- `wrangler.toml`: 로컬 개발
- Workers Secrets: 프로덕션

---

## 10. 성능 최적화

### Presigned URL 방식의 장점
- Workers 서버 부하 감소
- 직접 업로드로 속도 향상
- 대용량 파일 업로드에 적합

### 업로드 진행률 표시
- Flutter에서 업로드 진행률 추적
- UI에 진행률 표시 (캠페인 이미지 업로드)

---

## 11. 참고 파일

### Workers
- `workers/index.ts`: Workers API 구현
- `wrangler.toml`: Workers 설정

### Flutter
- `lib/services/cloudflare_workers_service.dart`: 업로드 서비스
- `lib/screens/campaign/campaign_creation_screen.dart`: 캠페인 이미지 업로드
- `lib/screens/mypage/common/business_registration_form.dart`: 사업자등록증 업로드

### 설정
- `lib/config/supabase_config.dart`: Workers API URL 설정

---

## 12. 업로드 시나리오별 상세 흐름

### 시나리오 1: 캠페인 이미지 업로드

1. 사용자가 이미지 선택
2. Flutter에서 Presigned URL 요청
3. Workers에서 Presigned URL 생성 (AWS Signature V4)
4. Flutter에서 Presigned URL로 직접 R2 업로드
5. Workers API를 통한 Public URL 반환
6. 캠페인 생성 시 Public URL 저장

**특징:**
- 재시도 로직 포함 (최대 3회)
- 업로드 진행률 표시
- 타임아웃 처리

### 시나리오 2: 사업자등록증 업로드

1. 사용자가 사업자등록증 이미지 선택
2. Flutter에서 Workers API로 검증 요청 (`/api/verify-and-register`)
3. Workers에서 AI 검증 (Gemini API)
   - 이미지 검증
   - 정보 추출
   - 사업자등록번호 검증 (국세청 API)
4. Workers에서 Presigned URL 생성
5. Flutter에서 DB 저장 (중복 체크 포함)
6. Flutter에서 Presigned URL로 파일 업로드
7. 업로드 실패 시 DB 롤백

**특징:**
- AI 검증 포함
- DB 저장 후 파일 업로드 (원자성 보장)
- 롤백 처리

---

## 13. 문제 해결

### Presigned URL 만료
- 유효기간: PUT 15분, GET 1시간
- 만료 시 새로 요청 필요

### 업로드 실패
- 네트워크 에러: 자동 재시도
- 인증 에러: 즉시 실패
- 타임아웃: 재시도 또는 사용자 알림

### 파일 경로 추출 실패
- `extractFilePathFromUrl()` 함수 사용
- 여러 형식의 URL 지원

---

## 14. 향후 개선 사항

- [ ] 멀티파트 업로드 지원 (대용량 파일)
- [ ] 업로드 진행률 서버 사이드 추적
- [ ] 파일 압축 옵션
- [ ] CDN 캐싱 설정
- [ ] 업로드 속도 제한

