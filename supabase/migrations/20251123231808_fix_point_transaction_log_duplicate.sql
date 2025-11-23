-- point_transactions UPDATE 시 불필요한 로그 생성 방지
-- 의미 있는 변경이 있을 때만 로그를 생성하도록 수정

CREATE OR REPLACE FUNCTION "public"."log_point_transaction_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- INSERT 시: 항상 로그 생성
        INSERT INTO public.point_transaction_logs (
            transaction_id,
            action,
            changed_by
        ) VALUES (
            NEW.id,
            'created',
            NEW.created_by_user_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- UPDATE 시: 의미 있는 변경이 있을 때만 로그 생성
        -- updated_at 필드만 변경된 경우는 로그 생성하지 않음
        IF (OLD.wallet_id IS DISTINCT FROM NEW.wallet_id) OR
           (OLD.transaction_type IS DISTINCT FROM NEW.transaction_type) OR
           (OLD.amount IS DISTINCT FROM NEW.amount) OR
           (OLD.campaign_id IS DISTINCT FROM NEW.campaign_id) OR
           (OLD.related_entity_type IS DISTINCT FROM NEW.related_entity_type) OR
           (OLD.related_entity_id IS DISTINCT FROM NEW.related_entity_id) OR
           (OLD.description IS DISTINCT FROM NEW.description) OR
           (OLD.created_by_user_id IS DISTINCT FROM NEW.created_by_user_id) OR
           (OLD.completed_at IS DISTINCT FROM NEW.completed_at) THEN
            -- 의미 있는 필드가 변경된 경우에만 로그 생성
            INSERT INTO public.point_transaction_logs (
                transaction_id,
                action,
                changed_by,
                change_reason
            ) VALUES (
                NEW.id,
                'updated',
                NEW.created_by_user_id,
                'Transaction updated'
            );
        END IF;
        -- updated_at만 변경된 경우는 로그 생성하지 않음
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

