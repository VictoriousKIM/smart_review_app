SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict DEoUwIzI0mAmcvgC5I9BHHaSg0pBpxsAi7gwgZzoXHAZnXigptuZHUy7UsIY9Gd

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
	('00000000-0000-0000-0000-000000000000', '53b1cc9b-ee48-4334-a380-ee18fddc9b35', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"effectivesun@naver.com","user_id":"4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8","user_phone":""}}', '2025-12-09 23:50:39.972684+00', ''),
	('00000000-0000-0000-0000-000000000000', '3a65472e-4407-4845-955c-033c90615788', '{"action":"user_signedup","actor_id":"578ef7a3-65e9-44ba-8515-4d9802b21a7d","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"kakao"}}', '2025-12-09 23:51:36.094566+00', ''),
	('00000000-0000-0000-0000-000000000000', 'cda60a09-d133-4902-88b7-31d06dacffae', '{"action":"login","actor_id":"578ef7a3-65e9-44ba-8515-4d9802b21a7d","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"kakao"}}', '2025-12-09 23:51:39.004601+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b83c675e-38d0-42fa-ac81-1b8e4b15b1b5', '{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"effectivesun2@naver.com","user_id":"26df45f9-92bf-47f1-93bb-81f042b45e6d","user_phone":""}}', '2025-12-20 01:16:41.817752+00', ''),
	('00000000-0000-0000-0000-000000000000', '6e54c39e-bfdb-417d-9fa7-10f96f155248', '{"action":"user_modified","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"user","traits":{"user_email":"effectivesun@naver.com","user_id":"4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8","user_phone":""}}', '2025-12-20 01:37:00.695297+00', ''),
	('00000000-0000-0000-0000-000000000000', '625b3d70-d7e0-4ccf-8cfe-20d2d50fe0f7', '{"action":"user_modified","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"user","traits":{"user_email":"effectivesun@naver.com","user_id":"4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8","user_phone":""}}', '2025-12-23 00:33:52.101295+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', '578ef7a3-65e9-44ba-8515-4d9802b21a7d', 'authenticated', 'authenticated', 'nightkille@naver.com', NULL, '2025-12-09 23:51:36.094999+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-12-09 23:51:39.005607+00', '{"provider": "kakao", "providers": ["kakao"]}', '{"iss": "https://kapi.kakao.com", "sub": "4343386874", "name": "동익", "email": "nightkille@naver.com", "full_name": "동익", "user_name": "동익", "provider_id": "4343386874", "email_verified": true, "phone_verified": false, "preferred_username": "동익"}', NULL, '2025-12-09 23:51:36.089413+00', '2025-12-09 23:51:39.010946+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '26df45f9-92bf-47f1-93bb-81f042b45e6d', 'authenticated', 'authenticated', 'effectivesun2@naver.com', '$2a$10$GgjyEujXqgdPxfp5K/2fYuZDrHJQpQeIWJjGSWRFNdv/SfSFPdjwO', '2025-12-20 01:16:41.819506+00', NULL, '', NULL, '', NULL, '', '', NULL, NULL, '{"provider": "naver", "providers": ["naver"]}', '{"naver_id": "sXmKHT8eXoSiWZihO6AKBnR5t8JEHiYXGVlX1kOtrPs", "provider": "naver", "full_name": "김동익", "avatar_url": "", "email_verified": true}', NULL, '2025-12-20 01:16:41.814247+00', '2025-12-20 01:16:41.819952+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'authenticated', 'authenticated', 'effectivesun@naver.com', '$2a$10$HOYyCPmesQT0Y8G6GQJ7NOV.htYvtKmR.Ux7uuODD6cap/tqKUASe', '2025-12-09 23:50:39.976874+00', NULL, '', NULL, '', NULL, '', '', NULL, NULL, '{"provider": "naver", "providers": ["naver"]}', '{"naver_id": "PV1QisBsJwdOYQX4XmuuWWlx4CZipGG0z7_pkgS6V5I", "provider": "naver", "full_name": "김동익", "avatar_url": "", "email_verified": true}', NULL, '2025-12-09 23:50:39.968384+00', '2025-12-23 00:33:52.099989+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', '{"sub": "4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8", "email": "effectivesun@naver.com", "email_verified": false, "phone_verified": false}', 'email', '2025-12-09 23:50:39.97142+00', '2025-12-09 23:50:39.971443+00', '2025-12-09 23:50:39.971443+00', 'eea4d0db-08a8-4d29-b85c-3b240e2e24ba'),
	('4343386874', '578ef7a3-65e9-44ba-8515-4d9802b21a7d', '{"iss": "https://kapi.kakao.com", "sub": "4343386874", "name": "동익", "email": "nightkille@naver.com", "full_name": "동익", "user_name": "동익", "provider_id": "4343386874", "email_verified": true, "phone_verified": false, "preferred_username": "동익"}', 'kakao', '2025-12-09 23:51:36.09216+00', '2025-12-09 23:51:36.092193+00', '2025-12-09 23:51:36.092193+00', '772777e9-fc4b-4ccd-b624-bd8a57d48711'),
	('26df45f9-92bf-47f1-93bb-81f042b45e6d', '26df45f9-92bf-47f1-93bb-81f042b45e6d', '{"sub": "26df45f9-92bf-47f1-93bb-81f042b45e6d", "email": "effectivesun2@naver.com", "email_verified": false, "phone_verified": false}', 'email', '2025-12-20 01:16:41.816738+00', '2025-12-20 01:16:41.816773+00', '2025-12-20 01:16:41.816773+00', '0497b685-7824-4eae-93f6-351a0b339948');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter", "scopes") VALUES
	('3f2f7e0d-1803-4f93-824d-4c64c1fa4c17', '578ef7a3-65e9-44ba-8515-4d9802b21a7d', '2025-12-09 23:51:39.005723+00', '2025-12-09 23:51:39.005723+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('3f2f7e0d-1803-4f93-824d-4c64c1fa4c17', '2025-12-09 23:51:39.011417+00', '2025-12-09 23:51:39.011417+00', 'oauth', '21e2fc9a-3041-4655-af4a-c6d0d78fe1c1');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."refresh_tokens" ("instance_id", "id", "token", "user_id", "revoked", "created_at", "updated_at", "parent", "session_id") VALUES
	('00000000-0000-0000-0000-000000000000', 1, 'kyu7oulqihfu', '578ef7a3-65e9-44ba-8515-4d9802b21a7d', false, '2025-12-09 23:51:39.008397+00', '2025-12-09 23:51:39.008397+00', NULL, '3f2f7e0d-1803-4f93-824d-4c64c1fa4c17');


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

INSERT INTO "public"."users" ("id", "created_at", "updated_at", "display_name", "user_type", "status", "phone", "address") VALUES
	('4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', '2025-12-09 23:51:02.67479+00', '2025-12-09 23:51:02.67479+00', '김동익', 'user', 'active', '', NULL),
	('578ef7a3-65e9-44ba-8515-4d9802b21a7d', '2025-12-09 23:51:49.929071+00', '2025-12-09 23:51:49.929071+00', '동익', 'user', 'active', '', NULL),
	('26df45f9-92bf-47f1-93bb-81f042b45e6d', '2025-12-20 01:17:29.896083+00', '2025-12-20 01:17:29.896083+00', '김동익', 'user', 'active', '', NULL);


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."companies" ("id", "business_name", "business_number", "contact_email", "contact_phone", "address", "representative_name", "business_type", "registration_file_url", "user_id", "created_at", "updated_at", "auto_approve_reviewers") VALUES
	('d0776631-8596-4148-931d-634085bb6183', '포인터스', '867-70-00726', NULL, NULL, '충청남도 천안시 서북구 직산읍 부송상덕길 28', '김동익', '도매 및 소매업', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/20251219163356_사업자등록증(포인터스).png', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', '2025-12-19 07:33:54.851403+00', '2025-12-19 07:33:54.851403+00', true);


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."campaigns" ("id", "title", "description", "company_id", "product_name", "product_price", "platform", "max_participants", "current_participants", "status", "created_at", "updated_at", "product_image_url", "user_id", "campaign_type", "completed_applicants_count", "keyword", "option", "quantity", "seller", "product_number", "purchase_method", "review_type", "review_text_length", "review_image_count", "prevent_product_duplicate", "prevent_store_duplicate", "duplicate_prevent_days", "payment_method", "total_cost", "campaign_reward", "max_per_reviewer", "review_start_date", "apply_start_date", "apply_end_date", "review_end_date", "product_provision_type") VALUES
	('68493aeb-1a01-4fbe-96e4-903915a1a0b4', '브림유 BRIMU 무타공 흡착식 욕실선반 세면대선반 U자형', '', 'd0776631-8596-4148-931d-634085bb6183', '브림유 BRIMU 무타공 흡착식 욕실선반 세면대선반 U자형', 13800, 'coupang', 10, 0, 'inactive', '2025-12-22 07:33:31.075781+00', '2025-12-22 07:33:43.575533+00', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/smart-review-files/campaign-images/d0776631-8596-4148-931d-634085bb6183/product/20251222163329_fd2cdf5e-4594-41cf-b892-d615f3b11301.jpg', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'store', 0, '욕실 선반', '투명실버', 1, '브림유(BRIMU)', '8325154393-24032199045', 'mobile', 'star_text', 100, NULL, true, true, 14, 'direct', 0, 1000, 1, '2025-12-23 23:00:00+00', '2025-12-22 09:30:00+00', '2025-12-22 10:00:00+00', '2025-12-27 11:00:00+00', '실배송'),
	('53f106f9-6eac-4cef-8384-1f5ca8810f5a', '토탈블록 블록시티 장난감 블록 레고 호환 경찰특공대 858피스', '', 'd0776631-8596-4148-931d-634085bb6183', '토탈블록 블록시티 장난감 블록 레고 호환 경찰특공대 858피스', 5700, 'coupang', 10, 0, 'inactive', '2025-12-23 01:46:44.704373+00', '2025-12-23 01:46:53.613655+00', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/smart-review-files/campaign-images/d0776631-8596-4148-931d-634085bb6183/product/20251223104643_be94ceee-8a32-425f-a329-7d9bb54139a8.jpg', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'store', 0, '레고 블록', '', 1, '토탈블록', '', 'mobile', 'star_text', 100, NULL, true, true, 14, 'direct', 0, 1000, 1, '2025-12-24 23:00:00+00', '2025-12-23 09:30:00+00', '2025-12-23 10:00:00+00', '2025-12-28 11:00:00+00', '실배송');


--
-- Data for Name: campaign_action_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_actions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."campaign_logs" ("id", "campaign_id", "user_id", "status", "changes", "created_at") VALUES
	('cdc6042c-2ee8-4a93-a260-05cc2be33f38', '68493aeb-1a01-4fbe-96e4-903915a1a0b4', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'create', NULL, '2025-12-22 07:33:31.075781+00'),
	('e9992166-baf4-491a-b2a3-673da0cb2bc2', '53f106f9-6eac-4cef-8384-1f5ca8810f5a', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'create', NULL, '2025-12-23 01:46:44.704373+00');


--
-- Data for Name: wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."wallets" ("id", "company_id", "user_id", "current_points", "withdraw_bank_name", "withdraw_account_number", "withdraw_account_holder", "created_at", "updated_at") VALUES
	('41a9c30d-49d8-44d0-bb27-3ddf16cc21f6', NULL, '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 0, NULL, NULL, NULL, '2025-12-09 23:51:02.67479+00', '2025-12-09 23:51:02.67479+00'),
	('87ce51aa-3081-46aa-8d2e-94642a6997bb', NULL, '578ef7a3-65e9-44ba-8515-4d9802b21a7d', 0, NULL, NULL, NULL, '2025-12-09 23:51:49.929071+00', '2025-12-09 23:51:49.929071+00'),
	('8054dde6-8a97-4b38-a8ef-0ab1b132e8ee', 'd0776631-8596-4148-931d-634085bb6183', NULL, 0, NULL, NULL, NULL, '2025-12-19 07:33:54.851403+00', '2025-12-19 07:33:54.851403+00'),
	('def12c50-f12e-4b89-8ee4-6c9c44359964', NULL, '26df45f9-92bf-47f1-93bb-81f042b45e6d', 0, NULL, NULL, NULL, '2025-12-20 01:17:29.896083+00', '2025-12-20 01:17:29.896083+00');


--
-- Data for Name: cash_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: cash_transaction_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: company_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."company_users" ("company_id", "user_id", "company_role", "created_at", "status", "updated_at") VALUES
	('d0776631-8596-4148-931d-634085bb6183', '4f0b890f-c88f-44c6-9f4a-e3e8b274d9c8', 'owner', '2025-12-19 07:33:54.851403+00', 'active', '2025-12-19 07:33:54.851403+00'),
	('d0776631-8596-4148-931d-634085bb6183', '26df45f9-92bf-47f1-93bb-81f042b45e6d', 'reviewer', '2025-12-20 01:17:29.896083+00', 'active', '2025-12-20 01:17:29.896083+00');


--
-- Data for Name: deleted_users; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: point_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: point_transfers; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sns_connections; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: wallet_logs; Type: TABLE DATA; Schema: public; Owner: postgres
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

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, true);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict DEoUwIzI0mAmcvgC5I9BHHaSg0pBpxsAi7gwgZzoXHAZnXigptuZHUy7UsIY9Gd

RESET ALL;
