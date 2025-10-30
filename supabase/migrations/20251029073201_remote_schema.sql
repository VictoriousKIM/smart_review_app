drop policy "Admins can update all business registrations" on "public"."business_registrations";

drop policy "Admins can view all business registrations" on "public"."business_registrations";

drop policy "Users can insert own business registrations" on "public"."business_registrations";

drop policy "Users can update own pending business registrations" on "public"."business_registrations";

drop policy "Users can view own business registrations" on "public"."business_registrations";

revoke delete on table "public"."business_registrations" from "anon";

revoke insert on table "public"."business_registrations" from "anon";

revoke references on table "public"."business_registrations" from "anon";

revoke select on table "public"."business_registrations" from "anon";

revoke trigger on table "public"."business_registrations" from "anon";

revoke truncate on table "public"."business_registrations" from "anon";

revoke update on table "public"."business_registrations" from "anon";

revoke delete on table "public"."business_registrations" from "authenticated";

revoke insert on table "public"."business_registrations" from "authenticated";

revoke references on table "public"."business_registrations" from "authenticated";

revoke select on table "public"."business_registrations" from "authenticated";

revoke trigger on table "public"."business_registrations" from "authenticated";

revoke truncate on table "public"."business_registrations" from "authenticated";

revoke update on table "public"."business_registrations" from "authenticated";

revoke delete on table "public"."business_registrations" from "service_role";

revoke insert on table "public"."business_registrations" from "service_role";

revoke references on table "public"."business_registrations" from "service_role";

revoke select on table "public"."business_registrations" from "service_role";

revoke trigger on table "public"."business_registrations" from "service_role";

revoke truncate on table "public"."business_registrations" from "service_role";

revoke update on table "public"."business_registrations" from "service_role";

alter table "public"."business_registrations" drop constraint "business_registrations_reviewed_by_fkey";

alter table "public"."business_registrations" drop constraint "business_registrations_status_check";

alter table "public"."business_registrations" drop constraint "business_registrations_user_id_fkey";

alter table "public"."business_registrations" drop constraint "business_registrations_pkey";

drop index if exists "public"."business_registrations_pkey";

drop index if exists "public"."idx_business_registrations_business_number";

drop index if exists "public"."idx_business_registrations_status";

drop index if exists "public"."idx_business_registrations_submitted_at";

drop index if exists "public"."idx_business_registrations_user_id";

drop table "public"."business_registrations";



