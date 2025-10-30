-- Remove unused tables and related constraints
-- This migration removes business_registrations and reviews tables that are not being used

-- Drop the tables (this will cascade drop constraints, indexes, and policies)
DROP TABLE IF EXISTS "public"."business_registrations" CASCADE;
DROP TABLE IF EXISTS "public"."reviews" CASCADE;

-- Remove the get-presigned-url function if it exists as a stored function
-- Note: Edge Functions are not in SQL migration, they're deployed separately

