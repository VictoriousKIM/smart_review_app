# 캠페인 로그 및 R2 이미지 문제 해결 로드맵

## 📋 개요

이 문서는 다음 두 가지 주요 작업에 대한 로드맵을 제공합니다:
1. **캠페인 로그 기록**: 생성/편집/삭제 시 `campaign_logs` 테이블에 자동 기록
2. **R2 이미지 업로드/표시 문제 해결**: 이미지 업로드 및 표시 관련 이슈 해결

---

## 🎯 목표

### 1. 캠페인 로그 기록
- **필수 필드만 사용**: `campaign_id`, `user_id`, `status` (create/edit), `changes` (jsonb), `created_at`
- 캠페인 생성 시: `status='create'`, `changes`는 NULL (생성 시 변경사항 없음)
- 캠페인 편집 시: `status='edit'`, `changes`에 변경된 필드만 저장 (예: `{"title": {"old": "이전 제목", "new": "새 제목"}, "max_participants": {"old": 10, "new": 20}}`)
- 캠페인 삭제 시: 로그 기록하지 않음 (캠페인 삭제 시 관련 로그도 함께 삭제되므로)

### 2. R2 이미지 문제 해결
- 이미지 업로드 후 URL이 올바르게 저장되는지 확인
- 이미지 표시 시 CORS 문제 해결
- Workers 프록시 URL이 올바르게 생성되는지 확인

---

## 📝 작업 단계

### Phase 1: 캠페인 로그 기록 기능 구현

#### 1.1 데이터베이스 테이블 재구성
**파일**: `supabase/migrations/`

**작업 내용**:
- [ ] **기존 `campaign_logs` 테이블 백업** (필요 시)
  ```sql
  -- 기존 데이터 백업 (필요한 경우)
  CREATE TABLE campaign_logs_backup AS 
  SELECT * FROM campaign_logs;
  ```

- [ ] **기존 테이블 삭제 및 재생성** (필수 필드만 사용)
  ```sql
  -- 기존 테이블 삭제
  DROP TABLE IF EXISTS campaign_logs CASCADE;
  
  -- 새 테이블 생성 (필수 필드만)
  CREATE TABLE campaign_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID NOT NULL,  -- 스냅샷 (외래키 없음)
    user_id UUID NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('create', 'edit')),
    changes JSONB,  -- 변경사항 (생성/삭제 시 NULL)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
  );
  
  -- 인덱스 생성 (조회 성능 향상)
  CREATE INDEX idx_campaign_logs_campaign_id ON campaign_logs(campaign_id);
  CREATE INDEX idx_campaign_logs_user_id ON campaign_logs(user_id);
  CREATE INDEX idx_campaign_logs_status ON campaign_logs(status);
  CREATE INDEX idx_campaign_logs_created_at ON campaign_logs(created_at);
  ```

- [ ] **외래키 CASCADE DELETE 설정 확인**
  - `campaign_action_logs` 테이블의 `campaign_id` 외래키에 `ON DELETE CASCADE` 설정
  - 캠페인 삭제 시 관련 액션 로그도 자동 삭제
  - 예시:
    ```sql
    -- 기존 외래키 제약조건 확인
    SELECT constraint_name, delete_rule
    FROM information_schema.referential_constraints
    WHERE constraint_schema = 'public'
      AND table_name = 'campaign_action_logs'
      AND constraint_name LIKE '%campaign_id%';
    
    -- CASCADE DELETE 설정 (없는 경우)
    ALTER TABLE campaign_action_logs
    DROP CONSTRAINT IF EXISTS campaign_action_logs_campaign_id_fkey;
    
    ALTER TABLE campaign_action_logs
    ADD CONSTRAINT campaign_action_logs_campaign_id_fkey
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
    ON DELETE CASCADE;
    ```

- [ ] **`campaign_logs` 테이블 외래키 설정** (CASCADE DELETE)
  - `campaign_id`에 외래키 설정하여 캠페인 삭제 시 로그도 함께 삭제
  - 캠페인 삭제 시 관련 로그도 자동 삭제됨
  - 예시:
    ```sql
    ALTER TABLE campaign_logs
    ADD CONSTRAINT campaign_logs_campaign_id_fkey
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
    ON DELETE CASCADE;
    ```

**예상 시간**: 1-2시간

#### 1.2 데이터베이스 함수 수정
**파일**: `supabase/migrations/`

**작업 내용**:
- [ ] `create_campaign_with_points_v2` 함수에 로그 기록 로직 추가
  - 캠페인 생성 성공 시 `campaign_logs` 테이블에 레코드 삽입
  - 필수 필드만 저장: `campaign_id`, `user_id`, `status='create'`, `changes=NULL`, `created_at`
  - 예시:
    ```sql
    INSERT INTO campaign_logs (campaign_id, user_id, status, changes, created_at)
    VALUES (v_campaign_id, p_user_id, 'create', NULL, NOW());
    ```

- [ ] `update_campaign_v2` 함수에 로그 기록 로직 추가
  - 캠페인 업데이트 전 기존 데이터 조회
  - 업데이트 후 새 데이터와 비교하여 **변경된 필드만** 추출
  - `campaign_logs` 테이블에 레코드 삽입
  - 필수 필드: `campaign_id`, `user_id`, `status='edit'`, `changes` (변경사항만), `created_at`
  - 예시:
    ```sql
    -- 변경사항 추출 로직
    changes := jsonb_build_object(
      'title', jsonb_build_object('old', old_title, 'new', new_title),
      'max_participants', jsonb_build_object('old', old_max, 'new', new_max)
    ) WHERE old_title != new_title OR old_max != new_max;
    
    INSERT INTO campaign_logs (campaign_id, user_id, status, changes, created_at)
    VALUES (p_campaign_id, p_user_id, 'edit', changes, NOW());
    ```

- [ ] `delete_campaign` 함수 수정 (로그 기록 제외)
  - **삭제 조건 확인**: 유저가 아무것도 수행하지 않았을 때만 삭제 가능
    - `campaign_action_logs` 테이블에 해당 캠페인 로그가 있는지 확인
    - 로그가 있으면 삭제 불가 (에러 반환)
  - 캠페인 삭제 시 CASCADE DELETE로 관련 데이터 자동 삭제
    - `campaign_action_logs` (외래키 CASCADE)
    - `campaign_logs` (캠페인 삭제 시 관련 로그도 함께 삭제)
    - 기타 관련 테이블들
  - **중요**: 캠페인 삭제 시 로그도 함께 삭제되므로 삭제 로그를 기록하지 않음
  - 예시:
    ```sql
    -- 삭제 가능 여부 확인
    IF EXISTS (
      SELECT 1 FROM campaign_action_logs 
      WHERE campaign_id = p_campaign_id
    ) THEN
      RAISE EXCEPTION '캠페인에 참여한 유저가 있어 삭제할 수 없습니다.';
    END IF;
    
    -- 캠페인 삭제 (CASCADE DELETE로 관련 데이터 자동 삭제)
    -- campaign_logs도 CASCADE로 함께 삭제됨
    DELETE FROM campaigns WHERE id = p_campaign_id;
    ```

**예상 시간**: 2-3시간

#### 1.3 Dart 서비스 레이어 수정 (선택사항)
**파일**: `lib/services/campaign_service.dart`

**작업 내용**:
- [ ] 로그 기록이 DB 함수에서 자동으로 처리되므로 Dart 코드 수정 불필요
- [ ] 필요 시 로그 조회 기능 추가 (관리자용)
  - `campaign_logs` 테이블에서 로그 조회
  - `status`와 `changes` 필드 파싱

**예상 시간**: 1시간 (선택사항)

---