# 파일명 구조 변경 구현 보고서

## 📋 개요

R2 업로드 파일명 구조를 개선하여 유니코드 인코딩 문제를 해결하고, 파일 관리 효율성을 향상시키는 작업을 완료했습니다.

**작업 일시**: 2025-01-22  
**배포 상태**: ✅ 완료 (Version ID: 187dfc27-7ea7-4fa8-8abc-a9f9f427f419)

---

## 🎯 목표

1. **유니코드 파일명 인코딩 문제 해결**: 한글 파일명이 포함된 Presigned URL 업로드 오류 해결
2. **파일 관리 개선**: 회사별/상품별로 구조화된 파일 경로로 관리 효율성 향상
3. **중복 파일명 방지**: 타임스탬프 + 밀리초를 활용한 고유 파일명 생성
4. **AI 추출 실패 처리**: 사업자등록증 AI 추출 실패 시 적절한 에러 처리

---

## 📁 변경된 파일명 구조

### 이전 구조
```
{fileType}/{YYYYMMDDHHMMSS}_{fileName}
예: business-registration/20251122005340_사업자등록증(포인터스).png
```

### 새로운 구조

#### 1. 캠페인 이미지
```
campaign-images/{companyId}/product/{YYYYMMDDHHMMSSmmm}_{상품명}.jpg
예: campaign-images/abc123-def456/product/20250115143025123_아이폰15프로.jpg
```

#### 2. 사업자등록증
```
business-registration/{YYYYMMDDHHMMSSmmm}_{회사명}.png
예: business-registration/20250115143025123_포인터스.png
```

**주요 변경사항**:
- 타임스탬프에 밀리초(3자리) 추가로 중복 방지
- 파일명 정규화 함수로 특수 문자 처리
- AI 추출 데이터 활용 (상품명, 회사명)

---

## 🔧 구현 내용

### 1. Workers API 수정 (`workers/index.ts`)

#### 1.1 새로운 유틸리티 함수 추가

**`formatTimestampWithMillis` 함수**
```typescript
function formatTimestampWithMillis(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  const millis = String(date.getMilliseconds()).padStart(3, '0');
  return `${year}${month}${day}${hours}${minutes}${seconds}${millis}`;
}
```
- **목적**: 중복 파일명 방지를 위해 밀리초까지 포함한 타임스탬프 생성
- **형식**: `YYYYMMDDHHMMSSmmm` (17자리)

**`sanitizeFileName` 함수**
```typescript
function sanitizeFileName(name: string): string {
  if (!name || name.trim().length === 0) {
    return 'unknown';
  }

  return name
    .replace(/[<>:"/\\|?*]/g, '_')  // 파일 시스템 예약 문자 제거
    .replace(/\s+/g, '_')            // 공백을 언더스코어로
    .replace(/_{2,}/g, '_')          // 연속된 언더스코어 제거
    .replace(/^_+|_+$/g, '')         // 앞뒤 언더스코어 제거
    .trim() || 'unknown';
}
```
- **목적**: 파일명에 포함될 수 없는 특수 문자 제거 및 정규화
- **처리 내용**:
  - 파일 시스템 예약 문자 (`<>:"/\|?*`) 제거
  - 공백을 언더스코어로 변환
  - 연속된 언더스코어 통합
  - 빈 문자열인 경우 'unknown' 반환

#### 1.2 `handlePresignedUrl` 함수 수정

**변경 전**:
```typescript
const filePath = `${fileType}/${timestamp}_${fileName}`;
```

**변경 후**:
```typescript
const { 
  fileName, 
  userId, 
  contentType, 
  fileType, 
  method = 'PUT',
  companyId,      // 캠페인 이미지용
  productName,    // 캠페인 이미지용
  companyName     // 사업자등록증용
} = await request.json();

const timestamp = formatTimestampWithMillis(now);
let filePath: string;

if (fileType === 'campaign-images') {
  if (!companyId || !productName) {
    return new Response(
      JSON.stringify({ success: false, error: 'companyId and productName are required for campaign-images' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  const sanitized = sanitizeFileName(productName);
  filePath = `${fileType}/${companyId}/product/${timestamp}_${sanitized}${extension}`;
} else if (fileType === 'business-registration') {
  if (!companyName) {
    return new Response(
      JSON.stringify({ success: false, error: 'companyName is required for business-registration' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  const sanitized = sanitizeFileName(companyName);
  filePath = `${fileType}/${timestamp}_${sanitized}${extension}`;
} else {
  // 기타 파일 타입은 기존 방식 유지
  const sanitized = sanitizeFileName(fileName);
  filePath = `${fileType}/${timestamp}_${sanitized}`;
}
```

**주요 변경사항**:
- 파일 타입별로 다른 경로 구조 적용
- 필수 파라미터 검증 추가
- 파일명 정규화 적용

#### 1.3 `generateFilePath` 함수 수정

**변경 전**:
```typescript
function generateFilePath(userId: string, fileName: string): string {
  const now = new Date();
  const timestamp = formatTimestamp(now);
  return `business-registration/${timestamp}_${fileName}`;
}
```

**변경 후**:
```typescript
function generateFilePath(userId: string, fileName: string, companyName?: string): string {
  const now = new Date();
  const timestamp = formatTimestampWithMillis(now);
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  
  if (companyName) {
    // 사업자등록증: AI가 추출한 회사명 사용
    const sanitized = sanitizeFileName(companyName);
    return `business-registration/${timestamp}_${sanitized}${extension}`;
  }
  
  // 기본값 (사용되지 않을 예정)
  return `business-registration/${timestamp}_${sanitizeFileName(fileName)}`;
}
```

**주요 변경사항**:
- `companyName` 파라미터 추가
- 밀리초 포함 타임스탬프 사용
- 파일명 정규화 적용

#### 1.4 `handleVerifyAndRegister` 함수 수정

**주요 변경사항**:
1. **AI 추출 실패 시 에러 응답 개선**:
   ```typescript
   catch (extractError) {
     const errorMessage = extractError instanceof Error ? extractError.message : String(extractError);
     console.error('❌ AI 추출 실패:', errorMessage);
     return new Response(
       JSON.stringify({
         success: false,
         error: `AI 추출 실패: ${errorMessage}`,
         step: 'extraction',
       }),
       { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
     );
   }
   ```

2. **회사명 검증 추가**:
   ```typescript
   if (!extractedData || !extractedData.business_name) {
     return new Response(
       JSON.stringify({
         success: false,
         error: '회사명을 추출할 수 없습니다. 이미지를 다시 확인해주세요.',
         extractedData: extractedData || undefined,
         step: 'extraction',
       }),
       { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
     );
   }
   ```

3. **회사명 정규화 및 검증**:
   ```typescript
   const companyName = sanitizeFileName(extractedData.business_name);
   if (!companyName || companyName === 'unknown') {
     return new Response(
       JSON.stringify({
         success: false,
         error: '유효한 회사명을 추출할 수 없습니다.',
         extractedData,
         step: 'extraction',
       }),
       { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
     );
   }
   ```

4. **Presigned URL 생성 시점 변경**:
   - 모든 검증(이미지 검증, AI 추출, 사업자등록번호 검증) 통과 후에만 Presigned URL 생성
   - 검증 실패 시 Presigned URL을 생성하지 않아 불필요한 리소스 사용 방지

---

### 2. Flutter 클라이언트 수정

#### 2.1 `CloudflareWorkersService` 수정

**변경 전**:
```dart
static Future<PresignedUrlResponse> getPresignedUrl({
  required String fileName,
  required String userId,
  required String contentType,
  required String fileType,
  String method = 'PUT',
}) async {
  // ...
  body: json.encode({
    'fileName': fileName,
    'userId': userId,
    'contentType': contentType,
    'fileType': fileType,
    'method': method,
  }),
}
```

**변경 후**:
```dart
static Future<PresignedUrlResponse> getPresignedUrl({
  required String fileName,
  required String userId,
  required String contentType,
  required String fileType,
  String method = 'PUT',
  String? companyId,      // 캠페인 이미지용
  String? productName,    // 캠페인 이미지용
  String? companyName,    // 사업자등록증용
}) async {
  // ...
  body: json.encode({
    'fileName': fileName,
    'userId': userId,
    'contentType': contentType,
    'fileType': fileType,
    'method': method,
    if (companyId != null) 'companyId': companyId,
    if (productName != null) 'productName': productName,
    if (companyName != null) 'companyName': companyName,
  }),
}
```

**주요 변경사항**:
- 선택적 파라미터 추가 (`companyId`, `productName`, `companyName`)
- 조건부 JSON 인코딩으로 null 값 제외

#### 2.2 `campaign_creation_screen.dart` 수정

**변경 전**:
```dart
final timestamp = DateTime.now().millisecondsSinceEpoch;
final fileName = 'product_${timestamp}.jpg';

final presignedUrlResponse =
    await CloudflareWorkersService.getPresignedUrl(
      fileName: fileName,
      userId: user.id,
      contentType: 'image/jpeg',
      fileType: 'campaign-images',
      method: 'PUT',
    );
```

**변경 후**:
```dart
// 회사 ID 가져오기
final companyId = await CompanyUserService.getUserCompanyId(user.id);
if (companyId == null) {
  throw Exception('회사 정보를 찾을 수 없습니다.');
}

// 상품명 가져오기
final productName = _productNameController.text.trim();
if (productName.isEmpty) {
  throw Exception('상품명을 입력해주세요.');
}

// 파일명 생성 (확장자만 사용)
final fileName = 'product.jpg';

final presignedUrlResponse =
    await CloudflareWorkersService.getPresignedUrl(
      fileName: fileName,
      userId: user.id,
      contentType: 'image/jpeg',
      fileType: 'campaign-images',
      method: 'PUT',
      companyId: companyId,
      productName: productName,
    );
```

**주요 변경사항**:
- `CompanyUserService.getUserCompanyId()`로 회사 ID 조회
- `_productNameController`에서 상품명 가져오기
- 필수 파라미터 검증 추가
- 파일명은 확장자만 사용 (실제 파일명은 Workers에서 생성)

---

## ✅ 검증 항목

### 1. 파일명 정규화
- ✅ 특수 문자 제거 (`<>:"/\|?*`)
- ✅ 공백을 언더스코어로 변환
- ✅ 연속된 언더스코어 통합
- ✅ 빈 문자열 처리 ('unknown' 반환)

### 2. 중복 파일명 방지
- ✅ 밀리초 포함 타임스탬프 사용
- ✅ 타임스탬프 형식: `YYYYMMDDHHMMSSmmm` (17자리)

### 3. 파일 경로 구조
- ✅ 캠페인 이미지: `campaign-images/{companyId}/product/{timestamp}_{productName}.jpg`
- ✅ 사업자등록증: `business-registration/{timestamp}_{companyName}.png`

### 4. 에러 처리
- ✅ 필수 파라미터 검증
- ✅ AI 추출 실패 시 적절한 에러 응답
- ✅ 회사명/상품명 검증

### 5. 유니코드 인코딩
- ✅ 기존 `encodePath` 함수로 유니코드 문자 정상 처리
- ✅ AWS Signature V4 호환 경로 인코딩 유지

---

## 🚀 배포 정보

**배포 일시**: 2025-01-22  
**Workers 버전**: 187dfc27-7ea7-4fa8-8abc-a9f9f427f419  
**배포 URL**: https://smart-review-api.nightkille.workers.dev  
**배포 상태**: ✅ 성공

---

## 📝 주의사항

### 1. 파일명 길이 제한
- R2/S3의 최대 키 길이: 1024 바이트 (UTF-8 인코딩 기준)
- 현재 구현에서는 파일명 길이 제한을 명시적으로 처리하지 않음
- 향후 개선 필요 시 `sanitizeFileName` 함수에 길이 제한 로직 추가 가능

### 2. 특수 문자 처리
- 현재는 파일 시스템 예약 문자만 제거
- 한글, 영문, 숫자, 일부 특수 문자(`-`, `_`, `.`)는 허용
- 필요 시 더 엄격한 필터링 가능

### 3. AI 추출 실패 처리
- 사업자등록증: AI 추출 실패 시 Presigned URL을 생성하지 않음
- 캠페인 이미지: 상품명이 비어있으면 에러 발생
- 향후 개선: AI 추출 실패 시 기본값 사용 옵션 추가 가능

### 4. 중복 파일명 방지
- 밀리초 단위 타임스탬프로 대부분의 중복 방지
- 동일 밀리초에 동일 상품명/회사명 업로드 시 중복 가능성 있음
- 향후 개선: 타임스탬프 + 랜덤 문자열 조합 고려

---

## 🔄 마이그레이션 가이드

### 기존 파일 처리
- 기존에 업로드된 파일은 기존 경로 구조 유지
- 새로운 업로드만 새로운 경로 구조 사용
- 필요 시 기존 파일 마이그레이션 스크립트 작성 가능

### 클라이언트 업데이트
- Flutter 앱 업데이트 필요
- `campaign_creation_screen.dart`에서 `companyId`와 `productName` 전달 필수
- 사업자등록증 업로드 시 `companyName` 전달 필요 (현재는 AI 추출 데이터 사용)

---

## 📊 성능 영향

### 긍정적 영향
- ✅ 파일 경로 구조화로 관리 효율성 향상
- ✅ 회사별/상품별 파일 그룹화로 조회 성능 향상 가능
- ✅ 파일명 정규화로 인코딩 문제 사전 방지

### 부정적 영향
- ⚠️ 파일명 생성 로직이 약간 복잡해짐 (성능 영향 미미)
- ⚠️ 추가 파라미터 검증으로 약간의 오버헤드 (미미)

---

## 🎉 결론

파일명 구조 변경 작업을 성공적으로 완료했습니다. 주요 개선사항:

1. ✅ 유니코드 파일명 인코딩 문제 해결
2. ✅ 구조화된 파일 경로로 관리 효율성 향상
3. ✅ 중복 파일명 방지 메커니즘 추가
4. ✅ AI 추출 실패 시 적절한 에러 처리
5. ✅ 파일명 정규화로 특수 문자 문제 사전 방지

모든 변경사항이 배포되었으며, Flutter 클라이언트도 업데이트되었습니다.

---

## 📚 참고 문서

- [파일명 구조 제안서](./filename-structure-proposal.md)
- [Presigned URL 유니코드 파일명 이슈 분석](./presigned-url-unicode-filename-issue.md)
- [R2 업로드 로직 문서](./r2-upload-logic.md)

