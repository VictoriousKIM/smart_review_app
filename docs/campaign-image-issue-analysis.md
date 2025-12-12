# 캠페인 이미지 표시/삭제 문제 분석

## 📋 문제 요약

사업자 등록 워커스와 R2로 이미지 업로드/보기는 정상 동작하지만, **캠페인 이미지 등록 시 업로드는 되지만 표시와 삭제 로직에 문제**가 있습니다.

## 🔍 문제 분석

### 1. 이미지 업로드 흐름

**업로드 시 생성되는 파일 경로:**
```
campaign-images/{companyId}/product/{timestamp}_{uuid}.jpg
```

**업로드 후 저장되는 URL:**
```dart
final publicUrl = '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrlResponse.filePath}';
// 예: http://localhost:8787/api/files/campaign-images/{companyId}/product/{timestamp}_{uuid}.jpg
```

### 2. 이미지 표시 문제

**현재 구현:**
- `CachedNetworkImage`에서 `campaign.productImageUrl`을 직접 사용
- URL 형식: `http://localhost:8787/api/files/campaign-images/{companyId}/product/{timestamp}_{uuid}.jpg`

**Workers `handleGetFile` 함수:**
```typescript
async function handleGetFile(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const key = url.pathname.replace('/api/files/', '');
  // 예: /api/files/campaign-images/123/product/xxx.jpg
  //     → campaign-images/123/product/xxx.jpg
  const object = await env.FILES.get(key);
  // ...
}
```

**잠재적 문제점:**
1. ✅ 경로 추출 로직은 정상적으로 보임
2. ⚠️ URL 인코딩 문제: 경로에 특수문자가 있을 경우 디코딩 필요
3. ⚠️ 쿼리 파라미터 처리: URL에 쿼리 파라미터가 있을 경우 제거 필요
4. ⚠️ 에러 처리: 파일이 없을 때 404 반환하지만, Flutter에서 적절히 처리되는지 확인 필요

### 3. 이미지 삭제 문제

**현재 구현:**
```dart
// campaign_service.dart
await CloudflareWorkersService.deleteFile(productImageUrl);
```

**Workers `handleDeleteFile` 함수:**
```typescript
async function handleDeleteFile(request: Request, env: Env): Promise<Response> {
  const urlObj = new URL(fileUrl);
  let filePath = urlObj.pathname.substring(1); // 첫 번째 '/' 제거
  // 예: /api/files/campaign-images/123/product/xxx.jpg
  //     → api/files/campaign-images/123/product/xxx.jpg
  
  // Workers API URL 형식인 경우 (/api/files/ 제거)
  if (filePath.startsWith('api/files/')) {
    filePath = filePath.substring('api/files/'.length);
  }
  // → campaign-images/123/product/xxx.jpg
}
```

**잠재적 문제점:**
1. ✅ 경로 추출 로직은 정상적으로 보임
2. ⚠️ URL 인코딩 문제: 경로가 인코딩되어 있을 경우 디코딩 필요
3. ⚠️ 쿼리 파라미터/해시 처리: URL에 쿼리 파라미터나 해시가 있을 경우 제거 필요
4. ⚠️ 에러 로깅: 실패 시 상세한 로그가 없어 디버깅 어려움

### 4. Flutter `extractFilePathFromUrl` 함수

**현재 구현:**
```dart
static String extractFilePathFromUrl(String fileUrl) {
  final uri = Uri.parse(fileUrl);
  final pathSegments = uri.pathSegments;
  
  if (pathSegments.isNotEmpty) {
    return pathSegments.join('/');
  }
  // ...
}
```

**문제점:**
- `pathSegments`는 자동으로 디코딩되지만, `/api/files/`를 제거하지 않음
- 예: `http://localhost:8787/api/files/campaign-images/123/product/xxx.jpg`
  - `pathSegments` = `['api', 'files', 'campaign-images', '123', 'product', 'xxx.jpg']`
  - `join('/')` = `api/files/campaign-images/123/product/xxx.jpg`
- 이 함수는 `getPresignedUrlForViewing`에서만 사용되고, `deleteFile`에서는 직접 URL을 전달하므로 문제 없음

## 🐛 발견된 문제

### 문제 1: URL 인코딩 미처리

**증상:**
- URL에 특수문자나 공백이 있을 경우 인코딩되어 전달됨
- Workers에서 디코딩하지 않으면 파일을 찾을 수 없음

**예시:**
```
원본 경로: campaign-images/123/product/20250115_abc-def.jpg
인코딩된 URL: http://localhost:8787/api/files/campaign-images/123/product/20250115_abc-def.jpg
```

### 문제 2: 쿼리 파라미터/해시 미처리

**증상:**
- URL에 쿼리 파라미터나 해시가 있을 경우 경로 추출 실패

**예시:**
```
URL: http://localhost:8787/api/files/campaign-images/123/product/xxx.jpg?v=1#hash
pathname: /api/files/campaign-images/123/product/xxx.jpg
→ 정상 처리됨 (URL 객체가 자동으로 pathname만 추출)
```

### 문제 3: 에러 처리 및 로깅 부족

**증상:**
- 파일을 찾을 수 없을 때 상세한 로그가 없어 디버깅 어려움
- Flutter에서 에러 메시지가 명확하지 않음

## 🔧 해결 방안

### 1. Workers `handleGetFile` 개선

```typescript
async function handleGetFile(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    
    // 경로 추출 및 디코딩
    let key = url.pathname.replace('/api/files/', '');
    if (!key) {
      return new Response(
        JSON.stringify({ error: 'File key is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    // URL 디코딩 (인코딩된 경로 처리)
    try {
      key = decodeURIComponent(key);
    } catch (e) {
      console.warn('⚠️ URL 디코딩 실패 (원본 사용):', key);
    }
    
    console.log('📂 파일 조회 시도:', { originalPath: url.pathname, extractedKey: key });
    
    const object = await env.FILES.get(key);
    if (!object) {
      console.error('❌ 파일을 찾을 수 없음:', key);
      return new Response(
        JSON.stringify({ error: 'File not found', key }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    // ... 나머지 코드
  } catch (error) {
    console.error('❌ 파일 조회 실패:', error);
    // ... 에러 처리
  }
}
```

### 2. Workers `handleDeleteFile` 개선

```typescript
async function handleDeleteFile(request: Request, env: Env): Promise<Response> {
  try {
    const requestData: DeleteFileRequest = await request.json();
    const { fileUrl } = requestData;

    if (!fileUrl) {
      return new Response(
        JSON.stringify({ success: false, error: 'fileUrl이 필요합니다.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const urlObj = new URL(fileUrl);
    let filePath = urlObj.pathname.substring(1); // 첫 번째 '/' 제거

    // Workers API URL 형식인 경우 (/api/files/ 제거)
    if (filePath.startsWith('api/files/')) {
      filePath = filePath.substring('api/files/'.length);
    }

    // URL 디코딩 (인코딩된 경로 처리)
    try {
      filePath = decodeURIComponent(filePath);
    } catch (e) {
      console.warn('⚠️ URL 디코딩 실패 (원본 사용):', filePath);
    }

    // 허용된 파일 경로 확인
    if (!filePath.startsWith('business-registration/') && 
        !filePath.startsWith('campaign-images/')) {
      console.error('❌ 유효하지 않은 파일 경로:', filePath, '원본 URL:', fileUrl);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `유효하지 않은 파일 경로입니다: ${filePath}` 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('🗑️ 파일 삭제 시도:', { 
      originalUrl: fileUrl, 
      extractedPath: filePath,
      pathname: urlObj.pathname 
    });

    // R2에서 파일 삭제
    try {
      await env.FILES.delete(filePath);
      console.log('✅ 파일 삭제 성공:', filePath);
      return new Response(
        JSON.stringify({ success: true, message: '파일이 삭제되었습니다.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } catch (deleteError) {
      console.error('❌ R2 파일 삭제 실패:', deleteError, '경로:', filePath);
      throw deleteError;
    }
  } catch (error) {
    console.error('❌ 파일 삭제 실패:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : '파일 삭제 실패',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}
```

### 3. Flutter 에러 처리 개선

```dart
// campaign_service.dart의 deleteCampaign 메서드
if (productImageUrl != null && productImageUrl.isNotEmpty) {
  try {
    debugPrint('🗑️ R2 이미지 삭제 시도: $productImageUrl');
    await CloudflareWorkersService.deleteFile(productImageUrl);
    debugPrint('✅ 캠페인 이미지 삭제 성공: $productImageUrl');
  } catch (e, stackTrace) {
    // 이미지 삭제 실패해도 캠페인 삭제는 성공한 것으로 처리
    debugPrint('⚠️ 캠페인 이미지 삭제 실패 (무시): $e');
    debugPrint('⚠️ 스택 트레이스: $stackTrace');
    debugPrint('⚠️ 이미지 URL: $productImageUrl');
  }
}
```

## 📝 테스트 시나리오

### 테스트 1: 이미지 표시
1. 캠페인 이미지 업로드
2. 업로드된 URL 확인
3. 이미지가 정상적으로 표시되는지 확인
4. 브라우저 개발자 도구에서 네트워크 요청 확인

### 테스트 2: 이미지 삭제
1. 캠페인 생성 (이미지 포함)
2. 캠페인 삭제
3. Workers 로그에서 삭제 성공 메시지 확인
4. R2에서 파일이 실제로 삭제되었는지 확인

### 테스트 3: 에러 케이스
1. 존재하지 않는 파일 조회 시도
2. 잘못된 URL 형식으로 삭제 시도
3. 에러 메시지가 명확한지 확인

## 🎯 우선순위

1. **높음**: Workers 함수에 URL 디코딩 추가
2. **높음**: 에러 로깅 개선
3. **중간**: Flutter 에러 처리 개선
4. **낮음**: 추가적인 에러 케이스 처리

