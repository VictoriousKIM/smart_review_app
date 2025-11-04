SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict eHzBWTfSMZIHEvyDox0XjnTHstBCDwaVj5Td8JaNYtBzHlC8YFSpvgzSUJRLbML

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."audit_log_entries" ("instance_id", "id", "payload", "created_at", "ip_address") VALUES
	('00000000-0000-0000-0000-000000000000', '3b7a82c8-34a5-498d-b510-0f8c1dd09e69', '{"action":"user_signedup","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-11-03 08:11:32.927068+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd53ecb7a-6b7a-48ed-b613-d605115de548', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-03 08:11:32.930756+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e62529ed-7f41-49fe-9644-7b3a506f1853', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 00:42:53.397057+00', ''),
	('00000000-0000-0000-0000-000000000000', '2babcee2-1e1d-4920-8ec9-b4d78842107a', '{"action":"user_signedup","actor_id":"2eb8c022-92d6-4c42-988c-166e83050e09","actor_username":"test@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-11-04 01:11:36.749055+00', ''),
	('00000000-0000-0000-0000-000000000000', '331eb7f2-1508-4e96-89e0-a7f2cb3cfa4a', '{"action":"login","actor_id":"2eb8c022-92d6-4c42-988c-166e83050e09","actor_username":"test@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:11:36.75298+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f8c9a5f2-aa5c-4dbf-83c0-a04e3ee592ea', '{"action":"logout","actor_id":"2eb8c022-92d6-4c42-988c-166e83050e09","actor_username":"test@example.com","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:11:41.722728+00', ''),
	('00000000-0000-0000-0000-000000000000', '6983874e-1dd1-4ca6-9b19-4f510b8d3ab2', '{"action":"user_signedup","actor_id":"f0214704-7b33-4168-829c-c1e0fcb96ce9","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-11-04 01:11:54.254598+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c36cca71-cba6-48a4-8d13-724bf1def6de', '{"action":"login","actor_id":"f0214704-7b33-4168-829c-c1e0fcb96ce9","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:11:54.258272+00', ''),
	('00000000-0000-0000-0000-000000000000', '8c2b48d6-e9fb-48cb-8b52-9e1f889a8139', '{"action":"logout","actor_id":"f0214704-7b33-4168-829c-c1e0fcb96ce9","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:12:03.285845+00', ''),
	('00000000-0000-0000-0000-000000000000', '09db6f18-22ef-4227-9198-8fdb1077d52b', '{"action":"user_signedup","actor_id":"420e4945-845a-4e93-849c-3fba45632cf3","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-11-04 01:12:09.050349+00', ''),
	('00000000-0000-0000-0000-000000000000', '22da17db-ac85-4e49-916a-01d9ef0d8e3e', '{"action":"login","actor_id":"420e4945-845a-4e93-849c-3fba45632cf3","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:12:09.053755+00', ''),
	('00000000-0000-0000-0000-000000000000', '5a853e30-51fb-4f4a-978c-b4be1ed9eecc', '{"action":"logout","actor_id":"420e4945-845a-4e93-849c-3fba45632cf3","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:12:12.915947+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a76f85d6-9a3a-44ea-8bd8-bf9f5b63add5', '{"action":"user_signedup","actor_id":"201cf9ca-15f0-45a1-8033-b9fd08a99445","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-11-04 01:13:32.607644+00', ''),
	('00000000-0000-0000-0000-000000000000', '630bfb2d-b530-4aa8-9e27-d813d8763b83', '{"action":"login","actor_id":"201cf9ca-15f0-45a1-8033-b9fd08a99445","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:13:32.612731+00', ''),
	('00000000-0000-0000-0000-000000000000', '1d3ce925-0c5c-437a-b6ea-9dd31fa5a0e1', '{"action":"logout","actor_id":"201cf9ca-15f0-45a1-8033-b9fd08a99445","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:16:31.999027+00', ''),
	('00000000-0000-0000-0000-000000000000', '69c2b70d-6d26-460c-8fa2-40a4527fadbb', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:16:41.348814+00', ''),
	('00000000-0000-0000-0000-000000000000', '366c7760-546a-4677-b57d-8841e12bffdf', '{"action":"logout","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account"}', '2025-11-04 01:17:34.402905+00', ''),
	('00000000-0000-0000-0000-000000000000', '60f68355-fc99-4c71-8435-a248aea78a26', '{"action":"login","actor_id":"201cf9ca-15f0-45a1-8033-b9fd08a99445","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:17:55.375767+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', 'f0214704-7b33-4168-829c-c1e0fcb96ce9', 'authenticated', 'authenticated', 'reviewer@example.com', '$2a$10$KRiAM3LJ7AZcHibBWrtQ3u3k/Jsfx1X5qBKgKZpgDH.PzskDzXriu', '2025-11-04 01:11:54.254931+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:11:54.25874+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "f0214704-7b33-4168-829c-c1e0fcb96ce9", "email": "reviewer@example.com", "display_name": "reviewer@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:11:54.25228+00', '2025-11-04 01:11:54.259839+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '2234639c-59f0-4861-8448-103febfa612f', 'authenticated', 'authenticated', 'dev@example.com', '$2a$10$wdT8PoxcJHcfFNvdWQk.DunYNajFsIHYF17kpOF2/JihT184tfIze', '2025-11-03 08:11:32.927618+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:16:41.349264+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "2234639c-59f0-4861-8448-103febfa612f", "email": "dev@example.com", "display_name": "dev", "email_verified": true, "phone_verified": false}', NULL, '2025-11-03 08:11:32.920969+00', '2025-11-04 01:16:41.350492+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '201cf9ca-15f0-45a1-8033-b9fd08a99445', 'authenticated', 'authenticated', 'company_manger@example.com', '$2a$10$3etwD1cLy8EIiKTa2pwT5eAJarYxqlH7DTDcdutKEL0UTAcUEPBpy', '2025-11-04 01:13:32.607995+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:17:55.376237+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "201cf9ca-15f0-45a1-8033-b9fd08a99445", "email": "company_manger@example.com", "display_name": "company_manger@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:13:32.604686+00', '2025-11-04 01:17:55.377096+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '420e4945-845a-4e93-849c-3fba45632cf3', 'authenticated', 'authenticated', 'company_owner@example.com', '$2a$10$NonQqcIVL.6mRkS3KW9Mc.bAR1zyAZatI3CtdIZ4xGwvsifRIlRCW', '2025-11-04 01:12:09.050715+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:12:09.054102+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "420e4945-845a-4e93-849c-3fba45632cf3", "email": "company_owner@example.com", "display_name": "company_owner@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:12:09.047403+00', '2025-11-04 01:12:09.054832+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '2eb8c022-92d6-4c42-988c-166e83050e09', 'authenticated', 'authenticated', 'test@example.com', '$2a$10$tV2fNK8QNnzLkzY51Spw8eqBjBnoTo5r/TbwYQRxYgobMiy9dqu/a', '2025-11-04 01:11:36.749428+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:11:36.753281+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "2eb8c022-92d6-4c42-988c-166e83050e09", "email": "test@example.com", "display_name": "test@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:11:36.742448+00', '2025-11-04 01:11:36.754278+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('2234639c-59f0-4861-8448-103febfa612f', '2234639c-59f0-4861-8448-103febfa612f', '{"sub": "2234639c-59f0-4861-8448-103febfa612f", "email": "dev@example.com", "display_name": "dev", "email_verified": false, "phone_verified": false}', 'email', '2025-11-03 08:11:32.925201+00', '2025-11-03 08:11:32.925222+00', '2025-11-03 08:11:32.925222+00', '2acb313a-bf03-494e-9c92-9482aa9dc895'),
	('2eb8c022-92d6-4c42-988c-166e83050e09', '2eb8c022-92d6-4c42-988c-166e83050e09', '{"sub": "2eb8c022-92d6-4c42-988c-166e83050e09", "email": "test@example.com", "display_name": "test@example.com", "email_verified": false, "phone_verified": false}', 'email', '2025-11-04 01:11:36.745815+00', '2025-11-04 01:11:36.745836+00', '2025-11-04 01:11:36.745836+00', '3ed8dc05-1fc4-4cf4-bf9d-22eda89ddb9d'),
	('f0214704-7b33-4168-829c-c1e0fcb96ce9', 'f0214704-7b33-4168-829c-c1e0fcb96ce9', '{"sub": "f0214704-7b33-4168-829c-c1e0fcb96ce9", "email": "reviewer@example.com", "display_name": "reviewer@example.com", "email_verified": false, "phone_verified": false}', 'email', '2025-11-04 01:11:54.25365+00', '2025-11-04 01:11:54.253666+00', '2025-11-04 01:11:54.253666+00', '38198bb0-36e9-4ece-a5ce-229aa4649ded'),
	('420e4945-845a-4e93-849c-3fba45632cf3', '420e4945-845a-4e93-849c-3fba45632cf3', '{"sub": "420e4945-845a-4e93-849c-3fba45632cf3", "email": "company_owner@example.com", "display_name": "company_owner@example.com", "email_verified": false, "phone_verified": false}', 'email', '2025-11-04 01:12:09.049115+00', '2025-11-04 01:12:09.049134+00', '2025-11-04 01:12:09.049134+00', 'd30ba3b9-e2ff-4a5b-ad7e-5c717fa0a237'),
	('201cf9ca-15f0-45a1-8033-b9fd08a99445', '201cf9ca-15f0-45a1-8033-b9fd08a99445', '{"sub": "201cf9ca-15f0-45a1-8033-b9fd08a99445", "email": "company_manger@example.com", "display_name": "company_manger@example.com", "email_verified": false, "phone_verified": false}', 'email', '2025-11-04 01:13:32.606246+00', '2025-11-04 01:13:32.606272+00', '2025-11-04 01:13:32.606272+00', 'c21f99b9-2f05-40bd-b2d3-bc584dd2c715');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag") VALUES
	('5e9c22ba-3b38-444f-8476-d8f69ebde5de', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-03 08:11:32.931341+00', '2025-11-03 08:11:32.931341+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL),
	('de049b11-c334-4a4f-a086-d53f42b70e38', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-04 00:42:53.399236+00', '2025-11-04 00:42:53.399236+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL),
	('33dbcef9-d7d2-4b95-a368-38b9d6a93c8d', '201cf9ca-15f0-45a1-8033-b9fd08a99445', '2025-11-04 01:17:55.376314+00', '2025-11-04 01:17:55.376314+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('5e9c22ba-3b38-444f-8476-d8f69ebde5de', '2025-11-03 08:11:32.933358+00', '2025-11-03 08:11:32.933358+00', 'password', '389c67d3-353e-471f-82a3-6a08f702fa0e'),
	('de049b11-c334-4a4f-a086-d53f42b70e38', '2025-11-04 00:42:53.405274+00', '2025-11-04 00:42:53.405274+00', 'password', '556bca3f-7459-4cb0-89c7-cc0de778e708'),
	('33dbcef9-d7d2-4b95-a368-38b9d6a93c8d', '2025-11-04 01:17:55.377231+00', '2025-11-04 01:17:55.377231+00', 'password', '58275151-f7c7-4823-9494-79b18096b019');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 1, '6yqc6dvjriyb', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-03 08:11:32.932218+00', '2025-11-03 08:11:32.932218+00', NULL, '5e9c22ba-3b38-444f-8476-d8f69ebde5de'),
	('00000000-0000-0000-0000-000000000000', 2, 'htm3ev5uafnn', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-04 00:42:53.401416+00', '2025-11-04 00:42:53.401416+00', NULL, 'de049b11-c334-4a4f-a086-d53f42b70e38'),
	('00000000-0000-0000-0000-000000000000', 8, 'sv75k4db265a', '201cf9ca-15f0-45a1-8033-b9fd08a99445', false, '2025-11-04 01:17:55.376694+00', '2025-11-04 01:17:55.376694+00', NULL, '33dbcef9-d7d2-4b95-a368-38b9d6a93c8d');


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."users" ("id", "created_at", "updated_at", "display_name", "user_type", "status") VALUES
	('2234639c-59f0-4861-8448-103febfa612f', '2025-11-03 08:11:33.033199+00', '2025-11-03 08:11:33.033199+00', 'dev', 'user', 'active'),
	('2eb8c022-92d6-4c42-988c-166e83050e09', '2025-11-04 01:11:36.8133+00', '2025-11-04 01:11:36.8133+00', 'test@example.com', 'user', 'active'),
	('f0214704-7b33-4168-829c-c1e0fcb96ce9', '2025-11-04 01:11:54.281747+00', '2025-11-04 01:11:54.281747+00', 'reviewer@example.com', 'user', 'active'),
	('420e4945-845a-4e93-849c-3fba45632cf3', '2025-11-04 01:12:09.087909+00', '2025-11-04 01:12:09.087909+00', 'company_owner@example.com', 'user', 'active'),
	('201cf9ca-15f0-45a1-8033-b9fd08a99445', '2025-11-04 01:13:32.651223+00', '2025-11-04 01:13:32.651223+00', 'company_manger@example.com', 'user', 'active');


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."companies" ("id", "business_name", "business_number", "contact_email", "contact_phone", "address", "representative_name", "business_type", "registration_file_url", "user_id", "created_at", "updated_at") VALUES
	('eefe8bd9-9a75-4081-96d9-a4f6b464a2ef', '포인터스', '8677000726', NULL, NULL, '충청남도 천안시 서북구 직산읍 부송상덕길 28', '김동익', '도매 및 소매업', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/2025/11/04/2234639c-59f0-4861-8448-103febfa612f_1762219023804.png', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-04 01:17:02.598767+00', '2025-11-04 01:17:02.598767+00');


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_events; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_user_status; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: company_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."company_users" ("company_id", "user_id", "company_role", "created_at", "status") VALUES
	('eefe8bd9-9a75-4081-96d9-a4f6b464a2ef', '2234639c-59f0-4861-8448-103febfa612f', 'owner', '2025-11-04 01:17:02.598767+00', 'active'),
	('eefe8bd9-9a75-4081-96d9-a4f6b464a2ef', '201cf9ca-15f0-45a1-8033-b9fd08a99445', 'manager', '2025-11-04 01:18:27.508559+00', 'active');


--
-- Data for Name: deleted_users; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: point_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."point_wallets" ("id", "wallet_type", "user_id", "current_points", "created_at", "updated_at") VALUES
	('e594e797-bb02-4f62-af1f-e9357e8e028a', 'reviewer', '2234639c-59f0-4861-8448-103febfa612f', 0, '2025-11-03 08:11:33.033199+00', '2025-11-03 08:11:33.033199+00'),
	('327c17bf-7610-4b2e-847f-ae0cd41bf5d7', 'reviewer', '2eb8c022-92d6-4c42-988c-166e83050e09', 0, '2025-11-04 01:11:36.8133+00', '2025-11-04 01:11:36.8133+00'),
	('7ccbf495-1d06-4b77-92b6-e7f53a79da3b', 'reviewer', 'f0214704-7b33-4168-829c-c1e0fcb96ce9', 0, '2025-11-04 01:11:54.281747+00', '2025-11-04 01:11:54.281747+00'),
	('64398801-cc4d-444f-94b1-a7f867996fbd', 'reviewer', '420e4945-845a-4e93-849c-3fba45632cf3', 0, '2025-11-04 01:12:09.087909+00', '2025-11-04 01:12:09.087909+00'),
	('7e448c17-6118-413b-ae49-a7c603e6a669', 'reviewer', '201cf9ca-15f0-45a1-8033-b9fd08a99445', 0, '2025-11-04 01:13:32.651223+00', '2025-11-04 01:13:32.651223+00');


--
-- Data for Name: point_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sns_connections; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: supabase_functions_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 8, true);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict eHzBWTfSMZIHEvyDox0XjnTHstBCDwaVj5Td8JaNYtBzHlC8YFSpvgzSUJRLbML

RESET ALL;
