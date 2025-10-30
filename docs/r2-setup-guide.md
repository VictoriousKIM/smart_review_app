# Cloudflare R2 Presigned URL 설정 가이드

## 환경 변수 설정

Supabase Functions에서 R2에 접근하기 위해 다음 환경 변수들을 설정해야 합니다:

### 1. Supabase 프로젝트 설정

다음 환경 변수들을 Supabase 프로젝트에 설정해야 합니다:

#### 1.1 로컬 개발 환경 (이미 설정 완료)
`supabase/config.toml` 파일에 다음 설정이 추가되었습니다:
```toml
[edge_runtime.secrets]
R2_ACCOUNT_ID = "7b72031b240604b8e9f88904de2f127c"
R2_ACCESS_KEY_ID = "e4db9133661a4317e540091157c49da7"
R2_SECRET_ACCESS_KEY = "f8db6f7d4723f36252a12941f87e0df6110229a59afee113228b76b3f2aa2d1e"
R2_BUCKET_NAME = "smart-review-files"
R2_PUBLIC_URL = "https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com"
```

#### 1.2 프로덕션 환경 설정 (Supabase CLI 사용)
```bash
# Supabase CLI를 사용하여 프로덕션 환경 변수 설정
supabase secrets set R2_ACCOUNT_ID=7b72031b240604b8e9f88904de2f127c
supabase secrets set R2_ACCESS_KEY_ID=e4db9133661a4317e540091157c49da7
supabase secrets set R2_SECRET_ACCESS_KEY=f8db6f7d4723f36252a12941f87e0df6110229a59afee113228b76b3f2aa2d1e
supabase secrets set R2_BUCKET_NAME=smart-review-files
supabase secrets set R2_PUBLIC_URL=https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com
```

#### 1.3 Supabase 대시보드에서 설정
1. **Supabase Dashboard** 접속 (https://supabase.com/dashboard)
2. 프로젝트 선택
3. **Settings** → **Edge Functions** 메뉴
4. **Environment Variables** 섹션에서 다음 변수들 추가:
   - `R2_ACCOUNT_ID`: `7b72031b240604b8e9f88904de2f127c`
   - `R2_ACCESS_KEY_ID`: `e4db9133661a4317e540091157c49da7`
   - `R2_SECRET_ACCESS_KEY`: `f8db6f7d4723f36252a12941f87e0df6110229a59afee113228b76b3f2aa2d1e`
   - `R2_BUCKET_NAME`: `smart-review-files`
   - `R2_PUBLIC_URL`: `https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com`

### 2. Cloudflare R2 설정

#### 2.1 R2 버킷 생성
1. Cloudflare 대시보드에 로그인
2. R2 Object Storage 메뉴 선택
3. "Create bucket" 클릭
4. 버킷 이름 입력 (예: `smart-review-app-files`)

#### 2.2 API 토큰 생성
1. R2 버킷 설정에서 "Manage R2 API tokens" 클릭
2. "Create API token" 클릭
3. 권한 설정:
   - **Permissions**: Object Read & Write
   - **Bucket**: 생성한 버킷 선택
4. 토큰 생성 후 다음 정보 저장:
   - `Account ID`
   - `Access Key ID`
   - `Secret Access Key`

#### 2.3 커스텀 도메인 설정 (선택사항)
1. R2 버킷 설정에서 "Custom Domains" 클릭
2. "Connect Domain" 클릭
3. 도메인 입력 (예: `files.yourdomain.com`)
4. DNS 설정 완료 후 공개 URL로 사용

### 3. 파일 구조

업로드된 파일들은 다음 구조로 저장됩니다:

```
bucket-name/
├── business-registrations/
│   └── 2024/
│       └── 01/
│           └── 15/
│               └── user123_1705123456789.pdf
├── profile-images/
│   └── 2024/
│       └── 01/
│           └── 15/
│               └── user123_1705123456789.jpg
└── review-images/
    └── 2024/
        └── 01/
            └── 15/
                └── user123_1705123456789.png
```

### 4. 사용 예시

#### 4.1 사업자등록증 업로드
```dart
try {
  final fileBytes = await file.readAsBytes();
  final uploadedUrl = await R2UploadService.uploadBusinessRegistration(
    fileBytes: fileBytes,
    fileName: 'business_registration.pdf',
    userId: 'user123',
  );
  print('업로드 완료: $uploadedUrl');
} catch (e) {
  print('업로드 실패: $e');
}
```

#### 4.2 프로필 이미지 업로드
```dart
try {
  final fileBytes = await imageFile.readAsBytes();
  final uploadedUrl = await R2UploadService.uploadProfileImage(
    fileBytes: fileBytes,
    fileName: 'profile.jpg',
    userId: 'user123',
  );
  print('업로드 완료: $uploadedUrl');
} catch (e) {
  print('업로드 실패: $e');
}
```

### 5. 보안 고려사항

#### 5.1 파일 타입 제한
- **사업자등록증**: JPG, PNG, PDF (최대 10MB)
- **프로필 이미지**: JPG, PNG, WEBP (최대 5MB)
- **리뷰 이미지**: JPG, PNG, WEBP (최대 5MB)

#### 5.2 접근 제어
- Presigned URL은 1시간 후 만료
- 파일은 사용자별로 격리된 경로에 저장
- 서버에서만 R2 자격 증명 관리

#### 5.3 파일 검증
- 확장자 검증
- MIME 타입 검증
- 파일 크기 제한
- 사용자 인증 확인

### 6. 배포 및 테스트

#### 6.1 Supabase Functions 배포
```bash
supabase functions deploy get-presigned-url
```

#### 6.2 테스트
```bash
# 함수 테스트
curl -X POST 'https://your-project.supabase.co/functions/v1/get-presigned-url' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "fileName": "test.jpg",
    "userId": "test-user",
    "contentType": "image/jpeg",
    "fileType": "profile_image"
  }'
```

### 7. 모니터링 및 로그

#### 7.1 Supabase Functions 로그 확인
```bash
supabase functions logs get-presigned-url
```

#### 7.2 Cloudflare R2 사용량 모니터링
- Cloudflare 대시보드에서 R2 사용량 확인
- 월별 비용 추적
- 파일 접근 패턴 분석

### 8. 문제 해결

#### 8.1 일반적인 오류
- **403 Forbidden**: API 토큰 권한 확인
- **404 Not Found**: 버킷 이름 및 경로 확인
- **413 Payload Too Large**: 파일 크기 제한 확인

#### 8.2 디버깅 팁
- Supabase Functions 로그 확인
- 네트워크 탭에서 요청/응답 확인
- 파일 크기 및 형식 재확인

### 9. 비용 최적화

#### 9.1 파일 압축
- 이미지 파일은 WebP 형식 사용 권장
- PDF 파일은 필요시 압축

#### 9.2 CDN 활용
- 커스텀 도메인 설정으로 CDN 활용
- 전 세계 빠른 파일 접근

#### 9.3 라이프사이클 정책
- 오래된 파일 자동 삭제 설정
- 스토리지 클래스 최적화
