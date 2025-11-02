-- SNS 플랫폼 연결 테이블 생성
-- 다계정 허용: 같은 사용자가 같은 플랫폼의 여러 계정 등록 가능
-- 스토어 플랫폼: 주소 필수 (쿠팡, 스마트스토어 등)
-- SNS 플랫폼: 주소 불필요 (블로그, 인스타그램 등)

-- 1. 테이블 생성
CREATE TABLE IF NOT EXISTS "public"."sns_platform_connections" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "user_id" uuid NOT NULL REFERENCES "public"."users"("id") ON DELETE CASCADE,
    
    -- 플랫폼 정보
    "platform" text NOT NULL, -- 'coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice', 'blog', 'instagram', 'youtube', 'tiktok', 'naver' 등
    "platform_account_id" text NOT NULL, -- 플랫폼 내 계정 ID
    "platform_account_name" text NOT NULL, -- 플랫폼 내 표시 이름
    
    -- 연락처 정보
    "phone" text NOT NULL,
    
    -- 주소 정보 (스토어 플랫폼만 필수, 애플리케이션 레벨에서 검증)
    "address" text,
    
    -- 다계정 허용: 같은 사용자가 같은 플랫폼의 다른 계정을 여러 개 등록 가능
    -- 단, 같은 계정 ID는 중복 방지
    CONSTRAINT "sns_platform_connections_unique_user_platform_account" 
        UNIQUE ("user_id", "platform", "platform_account_id"),
    
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. 인덱스 생성
CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_user_id" 
    ON "public"."sns_platform_connections"("user_id");

CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_platform" 
    ON "public"."sns_platform_connections"("platform");

CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_user_platform" 
    ON "public"."sns_platform_connections"("user_id", "platform");

-- 3. 코멘트 추가
COMMENT ON TABLE "public"."sns_platform_connections" IS 'SNS 플랫폼 연결 정보 (다계정 허용)';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform" IS '플랫폼 이름 (coupang, smartstore, blog, instagram 등)';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform_account_id" IS '플랫폼 내 계정 ID';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform_account_name" IS '플랫폼 내 표시 이름';
COMMENT ON COLUMN "public"."sns_platform_connections"."address" IS '주소 (스토어 플랫폼만 필수, SNS 플랫폼은 NULL)';

-- 4. RLS 활성화
ALTER TABLE "public"."sns_platform_connections" ENABLE ROW LEVEL SECURITY;

-- 5. RLS 정책 생성
-- 사용자는 자신의 SNS 연결만 조회 가능
CREATE POLICY "Users can view their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR SELECT
    TO authenticated
    USING (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 생성 가능
CREATE POLICY "Users can create their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 수정 가능
CREATE POLICY "Users can update their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = "user_id")
    WITH CHECK (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 삭제 가능
CREATE POLICY "Users can delete their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR DELETE
    TO authenticated
    USING (auth.uid() = "user_id");

-- 6. 권한 설정
GRANT ALL ON TABLE "public"."sns_platform_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."sns_platform_connections" TO "service_role";

-- 7. 트리거 함수: updated_at 자동 업데이트
CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connections_updated_at"()
RETURNS TRIGGER
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER "set_sns_platform_connections_updated_at"
    BEFORE UPDATE ON "public"."sns_platform_connections"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_sns_platform_connections_updated_at"();

-- 8. RPC 함수: SNS 플랫폼 연결 생성 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."create_sns_platform_connection"(
    "p_user_id" uuid,
    "p_platform" text,
    "p_platform_account_id" text,
    "p_platform_account_name" text,
    "p_phone" text,
    "p_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_result jsonb;
BEGIN
    -- 트랜잭션 시작 (함수 내부는 자동으로 트랜잭션)
    
    -- 1. 사용자 존재 확인
    IF NOT EXISTS (SELECT 1 FROM "public"."users" WHERE "id" = "p_user_id") THEN
        RAISE EXCEPTION '사용자를 찾을 수 없습니다';
    END IF;
    
    -- 2. 스토어 플랫폼 주소 필수 검증
    IF "p_platform" = ANY(v_store_platforms) AND ("p_address" IS NULL OR "p_address" = '') THEN
        RAISE EXCEPTION '스토어 플랫폼(%)은 주소 입력이 필수입니다', "p_platform";
    END IF;
    
    -- 3. 중복 확인 (같은 계정 ID 중복 방지)
    IF EXISTS (
        SELECT 1 FROM "public"."sns_platform_connections"
        WHERE "user_id" = "p_user_id"
          AND "platform" = "p_platform"
          AND "platform_account_id" = "p_platform_account_id"
    ) THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    END IF;
    
    -- 4. SNS 연결 생성
    INSERT INTO "public"."sns_platform_connections" (
        "user_id",
        "platform",
        "platform_account_id",
        "platform_account_name",
        "phone",
        "address"
    ) VALUES (
        "p_user_id",
        "p_platform",
        "p_platform_account_id",
        "p_platform_account_name",
        "p_phone",
        CASE 
            WHEN "p_platform" = ANY(v_store_platforms) THEN "p_address"
            ELSE NULL -- SNS 플랫폼은 주소 무시
        END
    )
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'created_at', "created_at"
    ) INTO v_result;
    
    -- 5. 성공 응답 반환
    RETURN jsonb_build_object(
        'success', true,
        'data', v_result
    );
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    WHEN OTHERS THEN
        RAISE;
END;
$$;

-- 9. RPC 함수: SNS 플랫폼 연결 수정 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connection"(
    "p_id" uuid,
    "p_user_id" uuid,
    "p_platform_account_name" text DEFAULT NULL,
    "p_phone" text DEFAULT NULL,
    "p_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_platform text;
    v_result jsonb;
BEGIN
    -- 플랫폼 확인
    SELECT "platform" INTO v_platform
    FROM "public"."sns_platform_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id";
    
    IF v_platform IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    -- 스토어 플랫폼 주소 필수 검증
    IF v_platform = ANY(v_store_platforms) AND 
       ("p_address" IS NULL OR "p_address" = '') AND
       NOT EXISTS (
           SELECT 1 FROM "public"."sns_platform_connections"
           WHERE "id" = "p_id" AND "address" IS NOT NULL AND "address" != ''
       ) THEN
        RAISE EXCEPTION '스토어 플랫폼은 주소가 필수입니다';
    END IF;
    
    -- 업데이트
    UPDATE "public"."sns_platform_connections"
    SET
        "platform_account_name" = COALESCE("p_platform_account_name", "platform_account_name"),
        "phone" = COALESCE("p_phone", "phone"),
        "address" = CASE 
            WHEN v_platform = ANY(v_store_platforms) THEN COALESCE("p_address", "address")
            ELSE NULL -- SNS 플랫폼은 주소 제거
        END,
        "updated_at" = now()
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'updated_at', "updated_at"
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object('success', true, 'data', v_result);
END;
$$;

-- 10. RPC 함수: SNS 플랫폼 연결 삭제 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."delete_sns_platform_connection"(
    "p_id" uuid,
    "p_user_id" uuid
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_deleted_id uuid;
BEGIN
    DELETE FROM "public"."sns_platform_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING "id" INTO v_deleted_id;
    
    IF v_deleted_id IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'id', v_deleted_id
    );
END;
$$;

-- 11. RPC 함수 권한 설정
GRANT EXECUTE ON FUNCTION "public"."create_sns_platform_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_sns_platform_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_sns_platform_connection" TO "authenticated";

