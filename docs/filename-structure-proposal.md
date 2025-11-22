# 파일명 구조 변경 제안서

## 개요

현재 파일명 구조에서 한글 파일명 인코딩 문제를 해결하고, 더 의미있는 파일명을 사용하기 위한 구조 변경 제안입니다.

## 현재 구조

### 캠페인 이미지
```
campaign-images/{YYYYMMDDHHMMSS}_{원본파일명}
예: campaign-images/20250115143025_product.jpg
```

### 사업자등록증
```
business-registration/{YYYYMMDDHHMMSS}_{원본파일명}
예: business-registration/20250115143025_사업자등록증(포인터스).png
```

## 제안하는 새로운 구조

### 캠페인 이미지
```
campaign-images/{companyId}/product/{YYYYMMDDHHMMSS}_{상품명}.jpg
예: campaign-images/3aa3545b-ed63-40e9-8735-576686170346/product/20250115143025_욕실선반.jpg
```

**특징:**
- 회사 ID로 폴더 구분
- `product` 서브폴더로 상품 이미지임을 명시
- AI가 추출한 상품명 사용 (한글 가능)
- 개발자만 보는 파일명이므로 한글 사용 가능

### 사업자등록증
```
business-registration/{YYYYMMDDHHMMSS}_{회사명}.png
예: business-registration/20250115143025_포인터스.png
```

**특징:**
- AI가 추출한 회사명(business_name) 사용
- 한글 회사명 사용 가능
- 타임스탬프로 중복 방지

## 장점

### 1. 한글 파일명 문제 해결
- 원본 파일명 대신 AI가 추출한 의미있는 이름 사용
- URL 인코딩 문제를 피하면서도 한글 사용 가능
- 개발자만 보는 파일명이므로 가독성 향상

### 2. 파일 관리 용이성
- 회사별로 폴더 구분 (캠페인 이미지)
- 파일명만 봐도 어떤 상품/회사인지 파악 가능
- 디버깅 및 관리가 쉬워짐

### 3. 중복 방지
- 타임스탬프로 동일한 이름의 파일도 구분 가능
- 회사 ID로 폴더 분리하여 충돌 가능성 감소

## 구현 방법

### 1. Workers API 수정

#### `handlePresignedUrl` 함수 수정

**요청 파라미터 추가:**
- 캠페인 이미지: `companyId`, `productName` 추가
- 사업자등록증: `companyName` 추가 (AI 추출 후)

**파일 경로 생성 로직:**

```typescript
async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
  try {
    const { 
      fileName, 
      userId, 
      contentType, 
      fileType, 
      method = 'PUT',
      // 새로운 파라미터
      companyId,      // 캠페인 이미지용
      productName,    // 캠페인 이미지용
      companyName     // 사업자등록증용
    } = await request.json();

    // 파일 경로 생성
    const now = new Date();
    const timestamp = formatTimestamp(now);
    let filePath: string;

    if (fileType === 'campaign-images') {
      // 캠페인 이미지: campaign-images/{companyId}/product/{timestamp}_{productName}.jpg
      if (!companyId || !productName) {
        return new Response(
          JSON.stringify({ success: false, error: 'companyId and productName are required for campaign-images' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      const extension = fileName.substring(fileName.lastIndexOf('.'));
      filePath = `${fileType}/${companyId}/product/${timestamp}_${productName}${extension}`;
    } else if (fileType === 'business-registration') {
      // 사업자등록증: business-registration/{timestamp}_{companyName}.png
      if (!companyName) {
        return new Response(
          JSON.stringify({ success: false, error: 'companyName is required for business-registration' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      const extension = fileName.substring(fileName.lastIndexOf('.'));
      filePath = `${fileType}/${timestamp}_${companyName}${extension}`;
    } else {
      // 기타 파일 타입은 기존 방식 유지
      filePath = `${fileType}/${timestamp}_${fileName}`;
    }

    // Presigned URL 생성
    // ... 나머지 로직
  }
}
```

#### `generateFilePath` 함수 수정

```typescript
function generateFilePath(
  userId: string, 
  fileName: string, 
  companyName?: string
): string {
  const now = new Date();
  const timestamp = formatTimestamp(now);
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  
  if (companyName) {
    // 사업자등록증: AI가 추출한 회사명 사용
    return `business-registration/${timestamp}_${companyName}${extension}`;
  }
  
  // 기본값 (사용되지 않을 예정)
  return `business-registration/${timestamp}_${fileName}`;
}
```

#### `handleVerifyAndRegister` 함수 수정

```typescript
async function handleVerifyAndRegister(request: Request, env: Env): Promise<Response> {
  // ... AI 추출 및 검증 로직 ...

  // AI 추출 데이터에서 회사명 가져오기
  const companyName = extractedData?.business_name || 'unknown';
  
  // 파일 경로 생성 (회사명 사용)
  const contentType = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png';
  const filePath = generateFilePath(userId, fileName, companyName);
  
  // Presigned URL 생성
  const presignedUrl = await createPresignedUrlSignature(
    'PUT',
    filePath,
    contentType,
    900,
    env
  );

  return new Response(
    JSON.stringify({
      success: true,
      extractedData,
      validationResult,
      presignedUrl,
      filePath,
      publicUrl: `${env.R2_PUBLIC_URL}/${filePath}`,
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

### 2. Flutter 클라이언트 수정

#### 캠페인 이미지 업로드 (`campaign_creation_screen.dart`)

```dart
Future<String?> _uploadProductImage(
  Uint8List imageBytes, {
  required String companyId,
  required String productName,
  int maxRetries = 3,
}) async {
  // ... 기존 로직 ...

  // Presigned URL 요청 (companyId, productName 추가)
  final presignedUrlResponse = await CloudflareWorkersService.getPresignedUrl(
    fileName: 'product.jpg', // 확장자만 사용
    userId: user.id,
    contentType: 'image/jpeg',
    fileType: 'campaign-images',
    method: 'PUT',
    companyId: companyId,      // 추가
    productName: productName,  // 추가
  );

  // ... 나머지 로직 ...
}
```

#### 사업자등록증 업로드 (`business_registration_form.dart`)

AI가 추출한 회사명은 이미 Workers에서 처리되므로, Flutter에서는 추가 수정이 필요 없습니다.

단, `handleVerifyAndRegister` 응답에서 `filePath`를 확인하여 올바른 경로가 생성되었는지 확인할 수 있습니다.

#### `CloudflareWorkersService` 수정

```dart
static Future<PresignedUrlResponse> getPresignedUrl({
  required String fileName,
  required String userId,
  required String contentType,
  required String fileType,
  String method = 'PUT',
  String? companyId,      // 추가
  String? productName,    // 추가
  String? companyName,    // 추가
}) async {
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/presigned-url'),
      headers: {'Content-Type': 'application/json'},
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
    );
    // ... 나머지 로직 ...
  }
}
```

## 파일명 정규화

한글 파일명을 사용하되, 파일 시스템 호환성을 위해 일부 문자를 정규화할 수 있습니다:

```typescript
function sanitizeFileName(name: string): string {
  return name
    .replace(/[<>:"/\\|?*]/g, '_')  // 파일 시스템 예약 문자 제거
    .replace(/\s+/g, '_')            // 공백을 언더스코어로
    .replace(/_{2,}/g, '_')          // 연속된 언더스코어 제거
    .trim();
}
```

## 마이그레이션 계획

### 1. 기존 파일 처리
- 기존 파일은 그대로 유지
- 새로운 구조는 새로 업로드되는 파일부터 적용
- 필요시 기존 파일을 새 구조로 마이그레이션하는 스크립트 작성

### 2. 단계적 적용
1. **1단계**: Workers API 수정 및 배포
2. **2단계**: Flutter 클라이언트 수정 및 배포
3. **3단계**: 테스트 및 검증
4. **4단계**: 프로덕션 적용

## 예상되는 파일 경로 예시

### 캠페인 이미지
```
campaign-images/3aa3545b-ed63-40e9-8735-576686170346/product/20250115143025_욕실선반.jpg
campaign-images/3aa3545b-ed63-40e9-8735-576686170346/product/20250115143026_키보드.jpg
campaign-images/2234639c-59f0-4861-8448-103febfa612f/product/20250115143027_마우스.jpg
```

### 사업자등록증
```
business-registration/20250115143025_포인터스.png
business-registration/20250115143026_삼성전자.png
business-registration/20250115143027_LG전자.png
```

## 주의사항 및 처리 방법

### 1. 파일명 길이 제한

**설명:**
- AI가 추출한 회사명/상품명은 일반적으로 짧음 (수십 자 이내)
- 악의적으로 수정할 수 없으므로 (AI가 직접 추출) 길이 제한 불필요
- R2/S3 키 길이 제한(1024바이트)은 충분히 여유 있음

**처리 방법:**
- 별도의 길이 제한 로직 불필요
- AI 추출 데이터를 그대로 사용

### 2. 특수 문자 처리

**설명:**
- AI가 추출한 회사명/상품명은 일반적으로 정상적인 문자만 포함
- 악의적으로 수정할 수 없으므로 (AI가 직접 추출) 특수 문자 문제 발생 가능성 낮음
- 기본적인 정규화만 수행

**처리 방법:**

```typescript
// 기본 파일명 정규화 함수 (최소한의 처리)
function sanitizeFileName(name: string): string {
  if (!name || name.trim().length === 0) {
    return 'unknown';
  }

  return name
    // 파일 시스템 예약 문자만 제거 (슬래시는 경로 구분자이므로 제거)
    .replace(/[<>:"/\\|?*]/g, '_')
    // 공백을 언더스코어로 변환
    .replace(/\s+/g, '_')
    // 연속된 언더스코어를 하나로
    .replace(/_{2,}/g, '_')
    // 앞뒤 언더스코어 제거
    .replace(/^_+|_+$/g, '')
    .trim() || 'unknown';
}

// 사용 예시
const sanitizedProductName = sanitizeFileName(extractedProductName);
const sanitizedCompanyName = sanitizeFileName(extractedCompanyName);
```

### 3. AI 추출 실패 시 처리

**문제:**
- AI가 상품명/회사명을 추출하지 못하는 경우
- 빈 문자열이나 null 값 반환
- **트랜잭션으로 DB 등록을 막아야 함** (파일 업로드 전에 검증)

**처리 방법:**

**Workers API에서 AI 추출 실패 시 Presigned URL 생성하지 않음:**

```typescript
async function handleVerifyAndRegister(request: Request, env: Env): Promise<Response> {
  // ... AI 추출 및 검증 로직 ...

  // AI 추출 데이터 검증
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

  // 회사명 정규화
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

  // 검증 실패 시에도 Presigned URL 생성하지 않음
  if (!validationResult.isValid) {
    return new Response(
      JSON.stringify({
        success: false,
        extractedData,
        validationResult,
        error: validationResult.errorMessage || '유효하지 않은 사업자등록번호입니다.',
        step: 'validation',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 모든 검증 통과 후에만 Presigned URL 생성
  const contentType = fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png';
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  const timestamp = formatTimestampWithMillis(new Date());
  const filePath = `business-registration/${timestamp}_${companyName}${extension}`;

  const presignedUrl = await createPresignedUrlSignature(
    'PUT',
    filePath,
    contentType,
    900,
    env
  );

  return new Response(
    JSON.stringify({
      success: true,
      extractedData,
      validationResult,
      presignedUrl,
      filePath,
      publicUrl: `${env.R2_PUBLIC_URL}/${filePath}`,
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

**Flutter에서 트랜잭션 처리:**

```dart
// business_registration_form.dart
try {
  // 1. Workers API 호출 (AI 추출 + 검증)
  final response = await http.post(
    Uri.parse('$workersApiUrl/api/verify-and-register'),
    // ...
  );

  final responseData = json.decode(response.body) as Map<String, dynamic>;

  // 2. 성공 여부 확인 (AI 추출 실패 시 success = false)
  if (responseData['success'] != true) {
    // AI 추출 실패 또는 검증 실패 시 DB 저장하지 않음
    final error = responseData['error'] ?? '처리 실패';
    throw Exception(error);
  }

  // 3. DB 저장 (트랜잭션 시작)
  String? savedCompanyId;
  try {
    savedCompanyId = await _saveCompanyToDatabase(
      extractedData: extractedData,
      validationResult: validationResult,
      fileUrl: publicUrl,
    );
  } catch (dbError) {
    // DB 저장 실패 시 파일 업로드하지 않음
    throw Exception('DB 저장 실패: $dbError');
  }

  // 4. 파일 업로드 (DB 저장 성공 후)
  final uploadResponse = await http.put(
    Uri.parse(presignedUrl),
    // ...
  );

  if (uploadResponse.statusCode != 200) {
    // 파일 업로드 실패 → DB 롤백
    await _deleteCompanyFromDatabase(savedCompanyId);
    throw Exception('파일 업로드 실패');
  }

  // 성공
} catch (error) {
  // 에러 처리
}
```

**핵심 원칙:**
- ✅ AI 추출 실패 시 Presigned URL 생성하지 않음
- ✅ 검증 실패 시 Presigned URL 생성하지 않음
- ✅ DB 저장 실패 시 파일 업로드하지 않음
- ✅ 파일 업로드 실패 시 DB 롤백

### 4. 중복 파일명 방지

**문제:**
- 동일한 상품명/회사명으로 여러 파일 업로드 시
- 타임스탬프가 같을 수 있음 (같은 초에 업로드)
- 파일 덮어쓰기 가능성

**처리 방법: 타임스탬프 + 밀리초 (방법 2)**

```typescript
// 밀리초까지 포함한 타임스탬프
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

**최종 구현:**

```typescript
// 캠페인 이미지 파일명 생성
function generateCampaignImagePath(
  companyId: string,
  productName: string,
  extension: string
): string {
  const timestamp = formatTimestampWithMillis(new Date());
  const sanitized = sanitizeFileName(productName);
  return `campaign-images/${companyId}/product/${timestamp}_${sanitized}${extension}`;
}

// 사업자등록증 파일명 생성
function generateBusinessRegistrationPath(
  companyName: string,
  extension: string
): string {
  const timestamp = formatTimestampWithMillis(new Date());
  const sanitized = sanitizeFileName(companyName);
  return `business-registration/${timestamp}_${sanitized}${extension}`;
}
```

**예상 파일 경로:**

```
campaign-images/3aa3545b-ed63-40e9-8735-576686170346/product/20250115143025123_욕실선반.jpg
business-registration/20250115143025123_포인터스.png
```

**장점:**
- ✅ 밀리초 단위로 구분하여 동시 업로드 가능
- ✅ 랜덤 문자열 불필요 (타임스탬프만으로 충분)
- ✅ 파일명이 더 간결함
- ✅ 상품명/회사명으로 의미 파악 가능

## 테스트 시나리오

### 1. 캠페인 이미지 업로드
- [ ] 정상적인 상품명으로 업로드
- [ ] 한글 상품명으로 업로드
- [ ] 특수 문자가 포함된 상품명
- [ ] 매우 긴 상품명
- [ ] companyId 누락 시 에러 처리

### 2. 사업자등록증 업로드
- [ ] 정상적인 회사명으로 업로드
- [ ] 한글 회사명으로 업로드
- [ ] 특수 문자가 포함된 회사명
- [ ] AI 추출 실패 시 처리

## 결론

이 구조 변경으로:
1. ✅ 한글 파일명 인코딩 문제 해결
2. ✅ 더 의미있는 파일명으로 관리 용이성 향상
3. ✅ 회사별 폴더 구분으로 구조화
4. ✅ 개발자 친화적인 파일명

개발자만 보는 파일명이므로 한글 사용이 가능하며, AI가 추출한 의미있는 이름을 사용하여 파일 관리가 더 쉬워집니다.

