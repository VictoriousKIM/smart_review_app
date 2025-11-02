-- 테이블 이름 변경 및 회수 주소 필드 추가
-- 1. 기존 테이블 이름 변경
ALTER TABLE "public"."sns_platform_connections" RENAME TO "sns_connections";

-- 2. 제약 조건 이름 변경
ALTER TABLE "public"."sns_connections" 
    RENAME CONSTRAINT "sns_platform_connections_unique_user_platform_account" 
    TO "sns_connections_unique_user_platform_account";

-- 3. 인덱스 이름 변경
ALTER INDEX "idx_sns_platform_connections_user_id" RENAME TO "idx_sns_connections_user_id";
ALTER INDEX "idx_sns_platform_connections_platform" RENAME TO "idx_sns_connections_platform";
ALTER INDEX "idx_sns_platform_connections_user_platform" RENAME TO "idx_sns_connections_user_platform";

-- 4. 회수 주소 필드 추가
ALTER TABLE "public"."sns_connections" 
    ADD COLUMN "return_address" text;

COMMENT ON COLUMN "public"."sns_connections"."return_address" IS '회수 주소 (선택 사항)';

-- 5. 코멘트 업데이트
COMMENT ON TABLE "public"."sns_connections" IS 'SNS 플랫폼 연결 정보 (다계정 허용)';

-- 6. RLS 정책은 테이블 이름 변경 시 자동으로 적용되므로 이름 변경 불필요

-- 7. 트리거 함수 이름 변경 및 업데이트
DROP TRIGGER IF EXISTS "set_sns_platform_connections_updated_at" ON "public"."sns_connections";
CREATE OR REPLACE FUNCTION "public"."update_sns_connections_updated_at"()
RETURNS TRIGGER
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER "set_sns_connections_updated_at"
    BEFORE UPDATE ON "public"."sns_connections"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_sns_connections_updated_at"();

-- 8. RPC 함수 업데이트: create_sns_platform_connection -> create_sns_connection
CREATE OR REPLACE FUNCTION "public"."create_sns_connection"(
    "p_user_id" uuid,
    "p_platform" text,
    "p_platform_account_id" text,
    "p_platform_account_name" text,
    "p_phone" text,
    "p_address" text DEFAULT NULL,
    "p_return_address" text DEFAULT NULL
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
        SELECT 1 FROM "public"."sns_connections"
        WHERE "user_id" = "p_user_id"
          AND "platform" = "p_platform"
          AND "platform_account_id" = "p_platform_account_id"
    ) THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    END IF;
    
    -- 4. SNS 연결 생성
    INSERT INTO "public"."sns_connections" (
        "user_id",
        "platform",
        "platform_account_id",
        "platform_account_name",
        "phone",
        "address",
        "return_address"
    ) VALUES (
        "p_user_id",
        "p_platform",
        "p_platform_account_id",
        "p_platform_account_name",
        "p_phone",
        CASE 
            WHEN "p_platform" = ANY(v_store_platforms) THEN "p_address"
            ELSE NULL
        END,
        "p_return_address"
    )
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'return_address', "return_address",
        'created_at', "created_at"
    ) INTO v_result;
    
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

-- 9. RPC 함수 업데이트: update_sns_platform_connection -> update_sns_connection
CREATE OR REPLACE FUNCTION "public"."update_sns_connection"(
    "p_id" uuid,
    "p_user_id" uuid,
    "p_platform_account_name" text DEFAULT NULL,
    "p_phone" text DEFAULT NULL,
    "p_address" text DEFAULT NULL,
    "p_return_address" text DEFAULT NULL
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
    SELECT "platform" INTO v_platform
    FROM "public"."sns_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id";
    
    IF v_platform IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    -- 스토어 플랫폼 주소 필수 검증
    IF v_platform = ANY(v_store_platforms) AND 
       ("p_address" IS NULL OR "p_address" = '') AND
       NOT EXISTS (
           SELECT 1 FROM "public"."sns_connections"
           WHERE "id" = "p_id" AND "address" IS NOT NULL AND "address" != ''
       ) THEN
        RAISE EXCEPTION '스토어 플랫폼은 주소가 필수입니다';
    END IF;
    
    UPDATE "public"."sns_connections"
    SET
        "platform_account_name" = COALESCE("p_platform_account_name", "platform_account_name"),
        "phone" = COALESCE("p_phone", "phone"),
        "address" = CASE 
            WHEN v_platform = ANY(v_store_platforms) THEN COALESCE("p_address", "address")
            ELSE NULL
        END,
        "return_address" = COALESCE("p_return_address", "return_address"),
        "updated_at" = now()
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'return_address', "return_address",
        'updated_at', "updated_at"
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object('success', true, 'data', v_result);
END;
$$;

-- 10. RPC 함수 업데이트: delete_sns_platform_connection -> delete_sns_connection
CREATE OR REPLACE FUNCTION "public"."delete_sns_connection"(
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
    DELETE FROM "public"."sns_connections"
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
GRANT EXECUTE ON FUNCTION "public"."create_sns_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_sns_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_sns_connection" TO "authenticated";

-- 12. 기존 함수 삭제 (선택사항)
DROP FUNCTION IF EXISTS "public"."create_sns_platform_connection"(uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS "public"."update_sns_platform_connection"(uuid, uuid, text, text, text);
DROP FUNCTION IF EXISTS "public"."delete_sns_platform_connection"(uuid, uuid);

