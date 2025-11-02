-- ============================================================================
-- Migration: Add status to users and redesign deleted_users table
-- ============================================================================
-- Description:
--   1. Add status field to users table
--   2. Redesign deleted_users table with FK relationship
-- ============================================================================

-- ============================================================================
-- Step 1: Add status field to users table
-- ============================================================================

-- Add status column with default 'active'
ALTER TABLE "public"."users"
  ADD COLUMN IF NOT EXISTS "status" text DEFAULT 'active' NOT NULL;

-- Add check constraint for allowed status values (drop if exists first)
ALTER TABLE "public"."users"
  DROP CONSTRAINT IF EXISTS "users_status_check";

ALTER TABLE "public"."users"
  ADD CONSTRAINT "users_status_check" 
  CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended'));

-- Update existing users to 'active' if not set (should be all)
UPDATE "public"."users"
SET status = 'active'
WHERE status IS NULL;

-- Create partial index for active users (performance optimization)
CREATE INDEX IF NOT EXISTS "idx_users_status_active" 
ON "public"."users" ("id") 
WHERE "status" = 'active';

-- ============================================================================
-- Step 2: Backup existing deleted_users data to temp table
-- ============================================================================

-- Create temp table to hold existing data (before dropping the table)
CREATE TEMP TABLE IF NOT EXISTS "temp_deleted_users" AS
SELECT 
    id as user_id,
    deletion_reason,
    deleted_at
FROM "public"."deleted_users"
WHERE EXISTS (
    SELECT 1 FROM "public"."users" u WHERE u.id = "public"."deleted_users".id
);

-- ============================================================================
-- Step 3: Update users.status for existing deleted users
-- ============================================================================

-- Mark existing deleted_users as 'deleted' in users table (using temp table)
UPDATE "public"."users" u
SET status = 'deleted', updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM "temp_deleted_users" tdu 
    WHERE tdu.user_id = u.id
);

-- ============================================================================
-- Step 4: Drop and recreate deleted_users table with FK
-- ============================================================================

-- Drop existing table (will fail if there are dependencies, so we handle it)
DROP TABLE IF EXISTS "public"."deleted_users" CASCADE;

-- Create new deleted_users table with FK
CREATE TABLE "public"."deleted_users" (
    "user_id" uuid NOT NULL PRIMARY KEY,
    "deletion_reason" text,
    "deleted_at" timestamp with time zone DEFAULT now() NOT NULL,
    
    -- Foreign Key constraint
    CONSTRAINT "deleted_users_user_id_fkey" 
        FOREIGN KEY ("user_id") 
        REFERENCES "public"."users"("id") 
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Set table owner
ALTER TABLE "public"."deleted_users" OWNER TO "postgres";

-- ============================================================================
-- Step 5: Migrate existing deleted_users data from temp table
-- ============================================================================

-- Migrate data from temp table
INSERT INTO "public"."deleted_users" ("user_id", "deletion_reason", "deleted_at")
SELECT 
    user_id,
    deletion_reason,
    deleted_at
FROM "temp_deleted_users"
ON CONFLICT ("user_id") DO NOTHING;

-- ============================================================================
-- Step 6: Create indexes
-- ============================================================================

-- Index for deleted_at (for date-based queries)
CREATE INDEX IF NOT EXISTS "idx_deleted_users_deleted_at" 
ON "public"."deleted_users" ("deleted_at");

-- ============================================================================
-- Step 7: Grant permissions
-- ============================================================================

GRANT ALL ON TABLE "public"."deleted_users" TO "anon";
GRANT ALL ON TABLE "public"."deleted_users" TO "authenticated";
GRANT ALL ON TABLE "public"."deleted_users" TO "service_role";

-- ============================================================================
-- Step 8: Enable RLS (if needed)
-- ============================================================================

ALTER TABLE "public"."deleted_users" ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Step 9: Cleanup (temp table is automatically dropped at session end)
-- ============================================================================

-- ============================================================================
-- Migration complete
-- ============================================================================

