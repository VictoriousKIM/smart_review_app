# Presigned URL 한글 파일명 업로드 오류 분석 및 해결책

## 문제 개요

한글 파일명이 포함된 파일을 Presigned URL을 사용하여 Cloudflare R2에 업로드할 때 다음과 같은 오류가 발생합니다:

```
ClientException: Failed to fetch, uri=https://...r2.cloudflarestorage.com/.../business-registration/20251122005526_%EC%82%AC%EC%97%85%EC%9E%90%EB%93%B1%EB%A1%9D%EC%A6%9D(%ED%8F%AC%EC%9D%B8%ED%84%B0%EC%8A%A4).png?X-Amz-Algorithm=...
```

## 원인 분석

### 1. AWS Signature V4 경로 인코딩 규칙

AWS Signature V4에서 Presigned URL을 생성할 때, **Canonical Request**의 경로 부분은 다음과 같은 규칙을 따라야 합니다:

1. **경로 세그먼트 인코딩**: 각 경로 세그먼트는 RFC 3986에 따라 인코딩되어야 합니다.
2. **슬래시 유지**: 경로 구분자(`/`)는 인코딩하지 않아야 합니다.
3. **일관성 유지**: Canonical Request의 경로와 실제 URL의 경로가 동일하게 인코딩되어야 합니다.

### 2. 현재 코드의 문제점

현재 `workers/index.ts`의 `createPresignedUrlSignature` 함수에서:

```typescript
// 경로 세그먼트 인코딩 (슬래시는 유지, 각 세그먼트만 인코딩)
const encodePathSegment = (segment: string): string => {
  return encodeURIComponent(segment).replace(/%2F/g, '/');
};

const encodedPathSegments = filePath.split('/').map(encodePathSegment).join('/');
const canonicalPath = `/${env.R2_BUCKET_NAME}/${encodedPathSegments}`;
```

**문제점:**
- `encodeURIComponent`는 JavaScript의 표준 URL 인코딩 함수이지만, AWS Signature V4의 Canonical Request에서는 **더 엄격한 인코딩 규칙**이 필요합니다.
- AWS는 경로 세그먼트를 인코딩할 때 **모든 예약되지 않은 문자(reserved characters)를 인코딩**해야 합니다.
- 하지만 실제 URL 생성 시와 Canonical Request 생성 시의 인코딩이 일치하지 않을 수 있습니다.

### 3. Flutter/Dart HTTP 클라이언트의 URL 처리

Flutter의 `http` 패키지에서 `Uri.parse()`를 사용할 때:

```dart
final response = await http.put(
  Uri.parse(presignedUrl),
  headers: {'Content-Type': contentType},
  body: fileBytes,
);
```

**문제점:**
- `Uri.parse()`는 이미 인코딩된 URL을 파싱할 때, 일부 문자를 자동으로 디코딩할 수 있습니다.
- HTTP 요청을 보낼 때, Dart의 HTTP 클라이언트가 URL을 다시 인코딩할 수 있습니다.
- 이로 인해 서버에서 받은 URL과 실제 요청 URL이 달라질 수 있습니다.

### 4. R2/S3의 서명 검증

R2는 AWS S3 호환 API를 사용하므로, 서명 검증 과정에서:

1. 요청 URL의 경로를 디코딩합니다.
2. 디코딩된 경로로 Canonical Request를 재구성합니다.
3. 재구성된 Canonical Request로 서명을 다시 계산합니다.
4. 계산된 서명과 요청의 서명을 비교합니다.

**문제점:**
- 서버에서 생성한 Canonical Request의 경로와 클라이언트가 보낸 요청의 경로가 다르면 서명 불일치가 발생합니다.
- 한글 파일명의 경우, 인코딩 방식이 일치하지 않으면 서명 검증이 실패합니다.

## 해결책

### 해결책 1: AWS Signature V4 호환 경로 인코딩 함수 구현

AWS Signature V4의 Canonical Request에서 요구하는 경로 인코딩은 RFC 3986을 따르되, **예약되지 않은 문자(unreserved characters)만 유지**하고 나머지는 인코딩해야 합니다.

```typescript
// AWS Signature V4 호환 경로 인코딩
function encodeURIComponentStrict(str: string): string {
  return encodeURIComponent(str)
    .replace(/[!'()*]/g, (c) => {
      return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
}

// 경로 세그먼트 인코딩 (슬래시는 유지)
function encodePathSegment(segment: string): string {
  if (!segment) return segment;
  return encodeURIComponentStrict(segment);
}

// 전체 경로 인코딩
function encodePath(path: string): string {
  return path.split('/').map(encodePathSegment).join('/');
}
```

### 해결책 2: Canonical Request와 실제 URL의 일관성 보장

Canonical Request를 생성할 때와 실제 URL을 생성할 때 **동일한 인코딩 함수**를 사용해야 합니다.

```typescript
async function createPresignedUrlSignature(
  method: string,
  filePath: string,
  contentType: string,
  expiresIn: number,
  env: Env
): Promise<string> {
  const region = 'auto';
  const service = 's3';
  const algorithm = 'AWS4-HMAC-SHA256';
  
  // 경로 인코딩 (Canonical Request와 실제 URL에서 동일하게 사용)
  const encodedPath = encodePath(filePath);
  const canonicalPath = `/${env.R2_BUCKET_NAME}/${encodedPath}`;
  
  const host = `${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
  const date = new Date();
  const dateStamp = date.toISOString().slice(0, 10).replace(/-/g, '');
  const amzDate = date.toISOString().replace(/[:\-]|\.\d{3}/g, '');
  
  // Query string parameters
  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': algorithm,
    'X-Amz-Credential': `${env.R2_ACCESS_KEY_ID}/${dateStamp}/${region}/${service}/aws4_request`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host',
  });
  
  // Canonical Request (인코딩된 경로 사용)
  const canonicalHeaders = `host:${host}\n`;
  const signedHeaders = 'host';
  const canonicalRequest = [
    method,
    canonicalPath,  // 인코딩된 경로 사용
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    'UNSIGNED-PAYLOAD'
  ].join('\n');
  
  // ... 서명 생성 ...
  
  // Presigned URL 생성 (동일한 인코딩된 경로 사용)
  queryParams.set('X-Amz-Signature', signature);
  const fullPath = `/${env.R2_BUCKET_NAME}/${encodedPath}`;
  return `https://${host}${fullPath}?${queryParams.toString()}`;
}
```

### 해결책 3: Flutter 클라이언트에서 URL 처리 개선

Flutter에서 Presigned URL을 사용할 때, URL을 파싱하지 않고 **원본 문자열을 그대로 사용**하는 것이 좋습니다.

```dart
static Future<void> uploadToPresignedUrl({
  required String presignedUrl,
  required Uint8List fileBytes,
  required String contentType,
}) async {
  try {
    // Uri.parse() 대신 직접 문자열 사용
    final uri = Uri.parse(presignedUrl);
    
    // URL이 이미 인코딩되어 있으므로, path는 그대로 사용
    final request = http.Request('PUT', uri);
    request.headers['Content-Type'] = contentType;
    request.bodyBytes = fileBytes;
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Presigned URL 업로드 실패: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Presigned URL 업로드 실패: $e');
    rethrow;
  }
}
```

### 해결책 4: 대안 - 파일명을 영문으로 변환

가장 간단한 해결책은 파일명을 영문으로 변환하는 것입니다:

```typescript
function sanitizeFileName(fileName: string): string {
  // 한글 파일명을 영문으로 변환하거나, 타임스탬프만 사용
  const extension = fileName.substring(fileName.lastIndexOf('.'));
  const timestamp = Date.now();
  return `${timestamp}${extension}`;
}
```

하지만 이 방법은 원본 파일명 정보를 잃게 됩니다.

## 권장 해결 방법

### 단계 1: Workers에서 경로 인코딩 함수 개선

```typescript
// AWS Signature V4 호환 경로 인코딩
function encodeURIComponentStrict(str: string): string {
  return encodeURIComponent(str)
    .replace(/[!'()*]/g, (c) => {
      return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
}

function encodePathSegment(segment: string): string {
  if (!segment) return segment;
  return encodeURIComponentStrict(segment);
}

function encodePath(path: string): string {
  return path.split('/').map(encodePathSegment).join('/');
}
```

### 단계 2: createPresignedUrlSignature 함수 수정

Canonical Request와 실제 URL에서 동일한 인코딩된 경로를 사용하도록 수정합니다.

### 단계 3: 테스트

다양한 한글 파일명으로 테스트:
- `사업자등록증(포인터스).png`
- `한글 파일명 테스트.jpg`
- `특수문자!@#$%^&*().png`

## 추가 고려사항

### 1. 파일명 길이 제한

URL 인코딩으로 인해 파일명이 길어질 수 있습니다. R2/S3의 키 길이 제한(최대 1024바이트)을 초과하지 않도록 주의해야 합니다.

### 2. 파일명 정규화

파일명에 포함된 특수 문자를 정규화하는 것을 고려할 수 있습니다:
- 공백을 언더스코어(`_`)로 변환
- 특수 문자 제거 또는 변환
- 파일명 길이 제한

### 3. 에러 처리 개선

서명 불일치 오류 발생 시 더 자세한 디버깅 정보를 제공:
- Canonical Request 로깅
- 인코딩 전/후 경로 비교
- 서명 계산 과정 로깅

## 참고 자료

- [AWS Signature Version 4 Signing Process](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html)
- [RFC 3986 - URI Generic Syntax](https://tools.ietf.org/html/rfc3986)
- [Cloudflare R2 S3 API Compatibility](https://developers.cloudflare.com/r2/api/s3/api/)
- [AWS S3 Presigned URL Troubleshooting](https://repost.aws/ko/knowledge-center/s3-presigned-url-signature-mismatch)

## 디버깅 방법

### 1. Canonical Request 로깅

Workers에서 Canonical Request를 로깅하여 실제로 어떤 경로가 사용되는지 확인:

```typescript
console.log('Canonical Request:', canonicalRequest);
console.log('Encoded Path:', encodedPath);
console.log('Canonical Path:', canonicalPath);
```

### 2. Flutter 클라이언트에서 URL 확인

Flutter에서 Presigned URL을 받은 후 실제로 어떤 URL이 사용되는지 확인:

```dart
print('Presigned URL: $presignedUrl');
final uri = Uri.parse(presignedUrl);
print('Parsed Path: ${uri.path}');
print('Path Segments: ${uri.pathSegments}');
```

### 3. 서명 불일치 오류 응답 확인

R2에서 반환하는 에러 응답을 확인하여 실제 문제를 파악:

```dart
if (response.statusCode != 200 && response.statusCode != 204) {
  print('Error Response: ${response.body}');
  // XML 응답에서 CanonicalRequest, StringToSign 등을 확인
}
```

## 실제 구현된 해결책

현재 코드에서는 다음과 같이 수정되었습니다:

1. **경로 인코딩 함수 분리**: `encodePathSegment`와 `encodePath` 함수를 별도로 구현
2. **일관성 보장**: Canonical Request와 실제 URL에서 동일한 `encodedPath` 변수 사용
3. **슬래시 유지**: 경로 세그먼트만 인코딩하고 슬래시는 그대로 유지

하지만 여전히 문제가 발생한다면, 다음을 확인해야 합니다:

### 추가 확인 사항

1. **Flutter HTTP 클라이언트의 URL 처리**
   - `Uri.parse()`가 URL을 자동으로 디코딩하는지 확인
   - 필요시 `Uri.https()`를 사용하여 직접 구성

2. **R2의 실제 동작**
   - R2가 AWS S3와 완전히 동일하게 동작하는지 확인
   - R2 문서에서 특별한 요구사항이 있는지 확인

3. **대안: 파일명 정규화**
   - 한글 파일명을 영문으로 변환하거나 해시값 사용
   - 원본 파일명은 메타데이터로 저장

## 결론

한글 파일명이 포함된 Presigned URL 업로드 오류는 주로 **경로 인코딩의 불일치**로 인해 발생합니다. AWS Signature V4의 Canonical Request와 실제 URL에서 동일한 인코딩 방식을 사용하고, Flutter 클라이언트에서도 URL을 올바르게 처리하면 문제를 해결할 수 있습니다.

가장 중요한 것은 **Canonical Request 생성 시 사용한 경로 인코딩과 실제 URL의 경로 인코딩이 정확히 일치**해야 한다는 점입니다.

만약 위의 해결책으로도 문제가 해결되지 않는다면, **파일명을 영문으로 정규화**하는 방법을 고려하는 것이 실용적일 수 있습니다.

