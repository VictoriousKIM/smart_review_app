# R2 버킷 정리 스크립트

## 개요
Cloudflare R2 버킷의 객체와 미완료 멀티파트 업로드를 정리하는 유틸리티 스크립트입니다.

## 사용법

### 1. 의존성 설치
```bash
cd workers
npm install
```

### 2. 현재 상태 확인 (삭제하지 않음)
```bash
# PowerShell
Get-Content .dev.vars | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') } } ; node scripts/cleanup-r2.js

# 또는 npm 스크립트 사용 (Windows에서는 작동하지 않을 수 있음)
npm run cleanup:r2
```

### 3. 실제 정리 실행
```bash
# PowerShell
Get-Content .dev.vars | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') } } ; node scripts/cleanup-r2.js --cleanup

# 또는 npm 스크립트 사용 (Windows에서는 작동하지 않을 수 있음)
npm run cleanup:r2:execute
```

## 기능

### ✅ 수행 작업
- 버킷의 모든 객체 조회 및 삭제
- 미완료 멀티파트 업로드 조회 및 중단
- 삭제된 객체 크기 및 개수 통계 제공

### 🔒 안전 기능
- 기본적으로 조회만 수행 (--cleanup 플래그 필요)
- 각 작업의 진행 상황 실시간 표시
- 실패한 작업 로깅 및 보고

## 출력 예시

### 확인 모드 (--cleanup 없이)
```
═══════════════════════════════════════════════════════════════
🧹 R2 버킷 정리 스크립트
═══════════════════════════════════════════════════════════════
버킷: smart-review-files
계정 ID: 7b72031b240604b8e9f88904de2f127c

📋 버킷 "smart-review-files"의 모든 객체 조회 중...

  1. business-registration/2025/11/02/test.png
     크기: 245.5 KB | 수정: 2025. 11. 02. 오후 5:30:15

✅ 총 1개의 객체 발견
📊 총 크기: 245.5 KB

📋 버킷 "smart-review-files"의 미완료 멀티파트 업로드 조회 중...

✅ 총 0개의 미완료 업로드 발견

═══════════════════════════════════════════════════════════════
📊 최종 결과
═══════════════════════════════════════════════════════════════
📦 현재 객체: 1개
📦 미완료 업로드: 0개

⚠️  정리를 실행하려면 --cleanup 플래그를 추가하세요
═══════════════════════════════════════════════════════════════
```

### 정리 모드 (--cleanup 포함)
```
🗑️  1개의 객체 삭제 중...

  ✅ 1/1 객체 삭제 완료

✅ 총 1개의 객체가 삭제되었습니다.

═══════════════════════════════════════════════════════════════
📊 최종 결과
═══════════════════════════════════════════════════════════════
✅ 삭제된 객체: 1개
✅ 중단된 업로드: 0개

💡 버킷 크기는 몇 분 후 Cloudflare 대시보드에 반영됩니다.
═══════════════════════════════════════════════════════════════
```

## 환경 변수
`.dev.vars` 파일에 다음 환경 변수가 필요합니다:

```env
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=smart-review-files
```

## 주의 사항

⚠️ **중요**: 이 스크립트는 버킷의 **모든 데이터를 삭제**합니다!
- 프로덕션 환경에서 실행하기 전에 반드시 백업하세요
- 테스트 환경에서 먼저 실행해보세요
- `--cleanup` 플래그 없이 먼저 확인하세요

## 문제 해결

### 환경 변수 오류
```
❌ R2 환경 변수가 설정되지 않았습니다.
```
→ `.dev.vars` 파일이 `workers/` 디렉토리에 있는지 확인하세요.

### 권한 오류
```
❌ Access Denied
```
→ R2 API 토큰에 버킷 관리 권한이 있는지 확인하세요.

### 모듈 오류
```
(node:xxx) Warning: Module type of file:///... is not specified
```
→ `package.json`에 `"type": "module"`이 추가되어 있는지 확인하세요.

