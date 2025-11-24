-- 캠페인 생성/수정/삭제 로그 테이블 생성
-- 목적: 캠페인 관련 모든 액션을 추적하기 위한 로그 테이블

CREATE TABLE IF NOT EXISTS public.campaign_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID,  -- NULL 가능 (생성 실패 시)
    company_id UUID NOT NULL,
    user_id UUID NOT NULL,  -- 생성자
    
    -- 로그 타입
    log_type TEXT NOT NULL,  -- 'creation', 'update', 'status_change', 'deletion'
    action TEXT NOT NULL,  -- 'create', 'update', 'activate', 'deactivate', 'delete'
    
    -- 이전/이후 값 (JSONB)
    previous_data JSONB,  -- 변경 전 데이터
    new_data JSONB,  -- 변경 후 데이터
    
    -- 결과
    status TEXT NOT NULL,  -- 'success', 'failed', 'pending'
    error_message TEXT,  -- 실패 시 에러 메시지
    
    -- 메타데이터
    ip_address TEXT,
    user_agent TEXT,
    request_id UUID,  -- 요청 추적용
    
    -- 비용 정보
    points_spent INTEGER,
    points_before INTEGER,
    points_after INTEGER,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- 제약 조건
    CONSTRAINT campaign_logs_log_type_check CHECK (
        log_type IN ('creation', 'update', 'status_change', 'deletion')
    ),
    CONSTRAINT campaign_logs_action_check CHECK (
        action IN ('create', 'update', 'activate', 'deactivate', 'delete', 'cancel')
    ),
    CONSTRAINT campaign_logs_status_check CHECK (
        status IN ('success', 'failed', 'pending')
    ),
    
    -- 외래 키
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_campaign_logs_campaign_id ON campaign_logs(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_company_id ON campaign_logs(company_id);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_user_id ON campaign_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_log_type ON campaign_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_status ON campaign_logs(status);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_created_at ON campaign_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_company_created ON campaign_logs(company_id, created_at DESC);

-- RLS 활성화
ALTER TABLE campaign_logs ENABLE ROW LEVEL SECURITY;

-- 회사 멤버는 자신의 회사 로그 조회 가능
CREATE POLICY "Company members can view their company campaign logs"
ON campaign_logs FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM company_users
        WHERE user_id = auth.uid() AND status = 'active'
    )
);

-- 시스템만 INSERT 가능 (RPC 함수에서)
CREATE POLICY "System can insert campaign logs"
ON campaign_logs FOR INSERT
WITH CHECK (true);  -- RPC 함수에서만 사용

-- 테이블 코멘트
COMMENT ON TABLE public.campaign_logs IS '캠페인 생성/수정/삭제 등의 모든 액션을 추적하기 위한 로그 테이블';
COMMENT ON COLUMN public.campaign_logs.campaign_id IS '캠페인 ID (생성 실패 시 NULL)';
COMMENT ON COLUMN public.campaign_logs.company_id IS '회사 ID';
COMMENT ON COLUMN public.campaign_logs.user_id IS '액션을 수행한 사용자 ID';
COMMENT ON COLUMN public.campaign_logs.log_type IS '로그 타입: creation, update, status_change, deletion';
COMMENT ON COLUMN public.campaign_logs.action IS '액션: create, update, activate, deactivate, delete, cancel';
COMMENT ON COLUMN public.campaign_logs.previous_data IS '변경 전 데이터 (JSONB)';
COMMENT ON COLUMN public.campaign_logs.new_data IS '변경 후 데이터 (JSONB)';
COMMENT ON COLUMN public.campaign_logs.status IS '결과 상태: success, failed, pending';
COMMENT ON COLUMN public.campaign_logs.error_message IS '실패 시 에러 메시지';
COMMENT ON COLUMN public.campaign_logs.points_spent IS '사용된 포인트';
COMMENT ON COLUMN public.campaign_logs.points_before IS '포인트 차감 전 잔액';
COMMENT ON COLUMN public.campaign_logs.points_after IS '포인트 차감 후 잔액';

