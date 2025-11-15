SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict lGH1JpwYlE0s44fWWEdDO7E0y2DWEheV7MAYFHnk7slP0rwBizS20qxHWCKdSOd

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
	('00000000-0000-0000-0000-000000000000', '60f68355-fc99-4c71-8435-a248aea78a26', '{"action":"login","actor_id":"201cf9ca-15f0-45a1-8033-b9fd08a99445","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-04 01:17:55.375767+00', ''),
	('00000000-0000-0000-0000-000000000000', '107a426c-9a11-4ffc-a86e-8c14895fddb5', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-10 15:21:25.174954+00', ''),
	('00000000-0000-0000-0000-000000000000', '81ce16f3-4199-40c5-a762-612e4b478627', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-11 01:29:19.482202+00', ''),
	('00000000-0000-0000-0000-000000000000', 'dda317d2-343c-4770-be5b-90b308b0c233', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-13 23:09:32.454052+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a82534c9-d4d6-4815-9236-8e3e23d0d1d4', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-15 03:29:11.860642+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c13376fe-f35e-4e7b-be6e-ab2779f7e413', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-15 08:15:28.945422+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b13a44eb-a579-420d-ab9a-186f9abecc17', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-15 11:09:35.130535+00', ''),
	('00000000-0000-0000-0000-000000000000', 'dde878b8-263a-48fc-b4ce-0bb2a58b8a12', '{"action":"login","actor_id":"2234639c-59f0-4861-8448-103febfa612f","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-15 11:10:55.496795+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', 'f0214704-7b33-4168-829c-c1e0fcb96ce9', 'authenticated', 'authenticated', 'reviewer@example.com', '$2a$10$KRiAM3LJ7AZcHibBWrtQ3u3k/Jsfx1X5qBKgKZpgDH.PzskDzXriu', '2025-11-04 01:11:54.254931+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:11:54.25874+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "f0214704-7b33-4168-829c-c1e0fcb96ce9", "email": "reviewer@example.com", "display_name": "reviewer@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:11:54.25228+00', '2025-11-04 01:11:54.259839+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '201cf9ca-15f0-45a1-8033-b9fd08a99445', 'authenticated', 'authenticated', 'company_manger@example.com', '$2a$10$3etwD1cLy8EIiKTa2pwT5eAJarYxqlH7DTDcdutKEL0UTAcUEPBpy', '2025-11-04 01:13:32.607995+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:17:55.376237+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "201cf9ca-15f0-45a1-8033-b9fd08a99445", "email": "company_manger@example.com", "display_name": "company_manger@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:13:32.604686+00', '2025-11-04 01:17:55.377096+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '420e4945-845a-4e93-849c-3fba45632cf3', 'authenticated', 'authenticated', 'company_owner@example.com', '$2a$10$NonQqcIVL.6mRkS3KW9Mc.bAR1zyAZatI3CtdIZ4xGwvsifRIlRCW', '2025-11-04 01:12:09.050715+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:12:09.054102+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "420e4945-845a-4e93-849c-3fba45632cf3", "email": "company_owner@example.com", "display_name": "company_owner@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:12:09.047403+00', '2025-11-04 01:12:09.054832+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '2eb8c022-92d6-4c42-988c-166e83050e09', 'authenticated', 'authenticated', 'test@example.com', '$2a$10$tV2fNK8QNnzLkzY51Spw8eqBjBnoTo5r/TbwYQRxYgobMiy9dqu/a', '2025-11-04 01:11:36.749428+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-04 01:11:36.753281+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "2eb8c022-92d6-4c42-988c-166e83050e09", "email": "test@example.com", "display_name": "test@example.com", "email_verified": true, "phone_verified": false}', NULL, '2025-11-04 01:11:36.742448+00', '2025-11-04 01:11:36.754278+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '2234639c-59f0-4861-8448-103febfa612f', 'authenticated', 'authenticated', 'dev@example.com', '$2a$10$wdT8PoxcJHcfFNvdWQk.DunYNajFsIHYF17kpOF2/JihT184tfIze', '2025-11-03 08:11:32.927618+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-15 11:10:55.497362+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "2234639c-59f0-4861-8448-103febfa612f", "email": "dev@example.com", "display_name": "dev", "email_verified": true, "phone_verified": false}', NULL, '2025-11-03 08:11:32.920969+00', '2025-11-15 11:10:55.498295+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


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
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag", "oauth_client_id", "refresh_token_hmac_key", "refresh_token_counter") VALUES
	('5e9c22ba-3b38-444f-8476-d8f69ebde5de', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-03 08:11:32.931341+00', '2025-11-03 08:11:32.931341+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('de049b11-c334-4a4f-a086-d53f42b70e38', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-04 00:42:53.399236+00', '2025-11-04 00:42:53.399236+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('33dbcef9-d7d2-4b95-a368-38b9d6a93c8d', '201cf9ca-15f0-45a1-8033-b9fd08a99445', '2025-11-04 01:17:55.376314+00', '2025-11-04 01:17:55.376314+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('f2dbe689-ca4a-46a8-a76c-d0aa761cd089', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-10 15:21:25.176122+00', '2025-11-10 15:21:25.176122+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('e781d008-1f05-4a81-ac59-49d284fdb091', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-11 01:29:19.483197+00', '2025-11-11 01:29:19.483197+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('e1a52437-b8bc-4fdd-b496-364d9e5ffd87', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-13 23:09:32.455867+00', '2025-11-13 23:09:32.455867+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('7063f576-681a-4d92-b995-064445d66f67', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 03:29:11.861642+00', '2025-11-15 03:29:11.861642+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('246bc426-addd-41d7-bd4f-7ae541ba30b2', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 08:15:28.946009+00', '2025-11-15 08:15:28.946009+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('e62416ec-cb95-49d2-98a8-745dd7a1c1d3', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 11:09:35.132294+00', '2025-11-15 11:09:35.132294+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL),
	('613fc08c-8cb6-400e-aeb4-6854c1f75739', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 11:10:55.497398+00', '2025-11-15 11:10:55.497398+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36', '172.18.0.1', NULL, NULL, NULL, NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('5e9c22ba-3b38-444f-8476-d8f69ebde5de', '2025-11-03 08:11:32.933358+00', '2025-11-03 08:11:32.933358+00', 'password', '389c67d3-353e-471f-82a3-6a08f702fa0e'),
	('de049b11-c334-4a4f-a086-d53f42b70e38', '2025-11-04 00:42:53.405274+00', '2025-11-04 00:42:53.405274+00', 'password', '556bca3f-7459-4cb0-89c7-cc0de778e708'),
	('33dbcef9-d7d2-4b95-a368-38b9d6a93c8d', '2025-11-04 01:17:55.377231+00', '2025-11-04 01:17:55.377231+00', 'password', '58275151-f7c7-4823-9494-79b18096b019'),
	('f2dbe689-ca4a-46a8-a76c-d0aa761cd089', '2025-11-10 15:21:25.178136+00', '2025-11-10 15:21:25.178136+00', 'password', '7dce76fa-49e3-4107-84b0-618c829ead68'),
	('e781d008-1f05-4a81-ac59-49d284fdb091', '2025-11-11 01:29:19.486226+00', '2025-11-11 01:29:19.486226+00', 'password', 'd2d23f8d-1d4c-4066-aedc-4949a78a8702'),
	('e1a52437-b8bc-4fdd-b496-364d9e5ffd87', '2025-11-13 23:09:32.46062+00', '2025-11-13 23:09:32.46062+00', 'password', '572b5e0e-2739-4993-bd2b-247a0293fc1a'),
	('7063f576-681a-4d92-b995-064445d66f67', '2025-11-15 03:29:11.86365+00', '2025-11-15 03:29:11.86365+00', 'password', '5f5da977-16e1-4bb1-8274-aa4e283b30f0'),
	('246bc426-addd-41d7-bd4f-7ae541ba30b2', '2025-11-15 08:15:28.946952+00', '2025-11-15 08:15:28.946952+00', 'password', '04908959-fd9d-4dc1-8095-f8020e5780ca'),
	('e62416ec-cb95-49d2-98a8-745dd7a1c1d3', '2025-11-15 11:09:35.134838+00', '2025-11-15 11:09:35.134838+00', 'password', 'f7ef5311-562a-418e-8493-aca9ec53423d'),
	('613fc08c-8cb6-400e-aeb4-6854c1f75739', '2025-11-15 11:10:55.498443+00', '2025-11-15 11:10:55.498443+00', 'password', '1839eff5-0416-4400-862a-0f8121a18e08');


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
	('00000000-0000-0000-0000-000000000000', 1, '6yqc6dvjriyb', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-03 08:11:32.932218+00', '2025-11-03 08:11:32.932218+00', NULL, '5e9c22ba-3b38-444f-8476-d8f69ebde5de'),
	('00000000-0000-0000-0000-000000000000', 2, 'htm3ev5uafnn', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-04 00:42:53.401416+00', '2025-11-04 00:42:53.401416+00', NULL, 'de049b11-c334-4a4f-a086-d53f42b70e38'),
	('00000000-0000-0000-0000-000000000000', 8, 'sv75k4db265a', '201cf9ca-15f0-45a1-8033-b9fd08a99445', false, '2025-11-04 01:17:55.376694+00', '2025-11-04 01:17:55.376694+00', NULL, '33dbcef9-d7d2-4b95-a368-38b9d6a93c8d'),
	('00000000-0000-0000-0000-000000000000', 9, 'spoydu75muf7', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-10 15:21:25.177032+00', '2025-11-10 15:21:25.177032+00', NULL, 'f2dbe689-ca4a-46a8-a76c-d0aa761cd089'),
	('00000000-0000-0000-0000-000000000000', 10, 'efqbhkqllb7p', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-11 01:29:19.484692+00', '2025-11-11 01:29:19.484692+00', NULL, 'e781d008-1f05-4a81-ac59-49d284fdb091'),
	('00000000-0000-0000-0000-000000000000', 11, '3vd77ad37t5g', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-13 23:09:32.457841+00', '2025-11-13 23:09:32.457841+00', NULL, 'e1a52437-b8bc-4fdd-b496-364d9e5ffd87'),
	('00000000-0000-0000-0000-000000000000', 12, 'h5t4jfv74nsk', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-15 03:29:11.862447+00', '2025-11-15 03:29:11.862447+00', NULL, '7063f576-681a-4d92-b995-064445d66f67'),
	('00000000-0000-0000-0000-000000000000', 13, '5onarreabn67', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-15 08:15:28.946363+00', '2025-11-15 08:15:28.946363+00', NULL, '246bc426-addd-41d7-bd4f-7ae541ba30b2'),
	('00000000-0000-0000-0000-000000000000', 14, '3y47ratm7sui', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-15 11:09:35.133336+00', '2025-11-15 11:09:35.133336+00', NULL, 'e62416ec-cb95-49d2-98a8-745dd7a1c1d3'),
	('00000000-0000-0000-0000-000000000000', 15, 'oobwm4bsqlyv', '2234639c-59f0-4861-8448-103febfa612f', false, '2025-11-15 11:10:55.497794+00', '2025-11-15 11:10:55.497794+00', NULL, '613fc08c-8cb6-400e-aeb4-6854c1f75739');


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
	('2eb8c022-92d6-4c42-988c-166e83050e09', '2025-11-04 01:11:36.8133+00', '2025-11-04 01:11:36.8133+00', 'test@example.com', 'user', 'active'),
	('f0214704-7b33-4168-829c-c1e0fcb96ce9', '2025-11-04 01:11:54.281747+00', '2025-11-04 01:11:54.281747+00', 'reviewer@example.com', 'user', 'active'),
	('420e4945-845a-4e93-849c-3fba45632cf3', '2025-11-04 01:12:09.087909+00', '2025-11-04 01:12:09.087909+00', 'company_owner@example.com', 'user', 'active'),
	('201cf9ca-15f0-45a1-8033-b9fd08a99445', '2025-11-04 01:13:32.651223+00', '2025-11-04 01:13:32.651223+00', 'company_manger@example.com', 'user', 'active'),
	('2234639c-59f0-4861-8448-103febfa612f', '2025-11-03 08:11:33.033199+00', '2025-11-15 08:16:15.809506+00', 'dev1', 'admin', 'active');


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."companies" ("id", "business_name", "business_number", "contact_email", "contact_phone", "address", "representative_name", "business_type", "registration_file_url", "user_id", "created_at", "updated_at") VALUES
	('3aa3545b-ed63-40e9-8735-576686170346', '포인터스', '8677000726', NULL, NULL, '충청남도 천안시 서북구 직산읍 부송상덕길 28', '김동익', '도매 및 소매업', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/2025/11/06/2234639c-59f0-4861-8448-103febfa612f_1762409956018.png', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-06 06:19:13.099002+00', '2025-11-06 06:19:13.099002+00');


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_action_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_actions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."wallets" ("id", "company_id", "user_id", "current_points", "withdraw_bank_name", "withdraw_account_number", "withdraw_account_holder", "created_at", "updated_at") VALUES
	('8827b875-1eeb-4067-a3ca-dbcd65ad83e1', NULL, '2eb8c022-92d6-4c42-988c-166e83050e09', 0, NULL, NULL, NULL, '2025-11-04 01:11:36.8133+00', '2025-11-04 01:11:36.8133+00'),
	('2e36b811-87ed-4c19-91bb-7524501a849e', NULL, 'f0214704-7b33-4168-829c-c1e0fcb96ce9', 0, NULL, NULL, NULL, '2025-11-04 01:11:54.281747+00', '2025-11-04 01:11:54.281747+00'),
	('9e4b706a-92ca-4f35-851e-d38a56078b73', NULL, '420e4945-845a-4e93-849c-3fba45632cf3', 0, NULL, NULL, NULL, '2025-11-04 01:12:09.087909+00', '2025-11-04 01:12:09.087909+00'),
	('9d90e6ef-bdfd-42e9-ae5b-eed0997682f5', NULL, '201cf9ca-15f0-45a1-8033-b9fd08a99445', 0, NULL, NULL, NULL, '2025-11-04 01:13:32.651223+00', '2025-11-04 01:13:32.651223+00'),
	('314af2ba-ae38-4eb6-9d28-545abeddf488', NULL, '2234639c-59f0-4861-8448-103febfa612f', 0, '농협은행2', '312-0172-8650-01', '김동익', '2025-11-03 08:11:33.033199+00', '2025-11-11 00:49:32.13134+00'),
	('da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', '3aa3545b-ed63-40e9-8735-576686170346', NULL, 500000, '농협은행1', '312-0172-8650-12', '김동익', '2025-11-06 06:19:13.099002+00', '2025-11-15 11:14:42.458697+00');


--
-- Data for Name: cash_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."cash_transactions" ("id", "wallet_id", "transaction_type", "cash_amount", "payment_method", "bank_name", "account_number", "account_holder", "status", "approved_by", "rejected_by", "rejection_reason", "description", "created_by_user_id", "created_at", "updated_at", "point_amount") VALUES
	('ff698ed7-98d9-4b52-831f-6788199394ee', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', 'deposit', 220000.00, NULL, NULL, NULL, NULL, 'approved', '2234639c-59f0-4861-8448-103febfa612f', NULL, NULL, '포인트 충전 요청', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 03:29:24.841468+00', '2025-11-15 03:29:46.959531+00', 200000),
	('37b34a91-5009-4d52-b4da-afa78f159539', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', 'withdraw', 200000.00, NULL, '농협은행1', '312-0172-8650-12', '김동익', 'approved', '2234639c-59f0-4861-8448-103febfa612f', NULL, NULL, '포인트 출금 요청', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 03:31:38.4956+00', '2025-11-15 03:35:22.230523+00', 200000),
	('65913078-4b30-4d7d-93fc-6228abe74370', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', 'deposit', 55000.00, NULL, NULL, NULL, NULL, 'rejected', NULL, '2234639c-59f0-4861-8448-103febfa612f', 'ss', '포인트 충전 요청', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 08:17:16.671387+00', '2025-11-15 08:17:48.779448+00', 50000),
	('b73287c6-646a-44e4-9955-8341b2b94c42', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', 'deposit', 550000.00, NULL, NULL, NULL, NULL, 'approved', '2234639c-59f0-4861-8448-103febfa612f', NULL, NULL, '포인트 충전 요청', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 11:11:30.07444+00', '2025-11-15 11:14:42.458697+00', 500000),
	('45e653e3-282c-4b51-93f4-8c84e6745999', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', 'deposit', 110000.00, NULL, NULL, NULL, NULL, 'pending', NULL, NULL, NULL, '포인트 충전 요청', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-15 11:15:14.167856+00', '2025-11-15 11:15:14.167856+00', 100000);


--
-- Data for Name: cash_transaction_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."cash_transaction_logs" ("id", "transaction_id", "status", "changed_by", "change_reason", "created_at") VALUES
	('953aef7d-3e51-4874-a475-96da95b0f060', 'ff698ed7-98d9-4b52-831f-6788199394ee', 'pending', '2234639c-59f0-4861-8448-103febfa612f', NULL, '2025-11-15 03:29:24.841468+00'),
	('871788d2-6eec-47e4-aa0a-fa97090a2f1e', 'ff698ed7-98d9-4b52-831f-6788199394ee', 'approved', '2234639c-59f0-4861-8448-103febfa612f', 'Status changed to approved', '2025-11-15 03:29:46.959531+00'),
	('6d81b2d5-5ad4-46ef-bfb9-b1efc5dce55f', '37b34a91-5009-4d52-b4da-afa78f159539', 'pending', '2234639c-59f0-4861-8448-103febfa612f', NULL, '2025-11-15 03:31:38.4956+00'),
	('d1467e38-f1ea-4611-ad6c-0adea6bc1f12', '37b34a91-5009-4d52-b4da-afa78f159539', 'approved', '2234639c-59f0-4861-8448-103febfa612f', 'Status changed to approved', '2025-11-15 03:35:22.230523+00'),
	('a871d8d8-c7f5-47ce-9629-8d7481de7a51', '65913078-4b30-4d7d-93fc-6228abe74370', 'pending', '2234639c-59f0-4861-8448-103febfa612f', NULL, '2025-11-15 08:17:16.671387+00'),
	('f1ebb215-67f5-4954-9c91-5a04f7c205c0', '65913078-4b30-4d7d-93fc-6228abe74370', 'rejected', '2234639c-59f0-4861-8448-103febfa612f', 'ss', '2025-11-15 08:17:48.779448+00'),
	('f68b1af2-65a6-48a3-b960-856d04477970', 'b73287c6-646a-44e4-9955-8341b2b94c42', 'pending', '2234639c-59f0-4861-8448-103febfa612f', NULL, '2025-11-15 11:11:30.07444+00'),
	('ca2d8ee7-59ec-49b3-8d71-f2ef1f206358', 'b73287c6-646a-44e4-9955-8341b2b94c42', 'approved', '2234639c-59f0-4861-8448-103febfa612f', 'Status changed to approved', '2025-11-15 11:14:42.458697+00'),
	('3ebbb2e2-44e2-4ab0-9f08-df562ef513ac', '45e653e3-282c-4b51-93f4-8c84e6745999', 'pending', '2234639c-59f0-4861-8448-103febfa612f', NULL, '2025-11-15 11:15:14.167856+00');


--
-- Data for Name: company_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."company_users" ("company_id", "user_id", "company_role", "created_at", "status") VALUES
	('3aa3545b-ed63-40e9-8735-576686170346', '2234639c-59f0-4861-8448-103febfa612f', 'owner', '2025-11-06 06:19:13.099002+00', 'active');


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
-- Data for Name: point_transaction_logs; Type: TABLE DATA; Schema: public; Owner: postgres
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

INSERT INTO "public"."wallet_logs" ("id", "wallet_id", "old_bank_name", "old_account_number", "old_account_holder", "new_bank_name", "new_account_number", "new_account_holder", "changed_by", "created_at") VALUES
	('183254a5-8e25-4111-afbe-333ca44bf771', '314af2ba-ae38-4eb6-9d28-545abeddf488', NULL, NULL, NULL, '농협', '312-0172-8650-01', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-10 15:21:45.844997+00'),
	('3f8217d0-5956-40d7-91fe-ba64c8214537', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', NULL, NULL, NULL, '신한', '312-0172-8650-12', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-10 15:22:37.16533+00'),
	('513faa2f-1477-47eb-8e19-7dbfedc9c307', '314af2ba-ae38-4eb6-9d28-545abeddf488', '농협', '312-0172-8650-01', '김동익', '농협은행', '312-0172-8650-01', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-11 00:47:58.887536+00'),
	('a3b39475-a4e2-4dfd-8e65-7d1eac29fff2', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', '신한', '312-0172-8650-12', '김동익', '농협은행', '312-0172-8650-12', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-11 00:48:40.214799+00'),
	('ae3a8f57-800c-4144-b05e-80a0313d5583', 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e', '농협은행', '312-0172-8650-12', '김동익', '농협은행1', '312-0172-8650-12', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-11 00:49:26.627725+00'),
	('aa429093-1f5f-4982-aaab-63831f19b937', '314af2ba-ae38-4eb6-9d28-545abeddf488', '농협은행', '312-0172-8650-01', '김동익', '농협은행2', '312-0172-8650-01', '김동익', '2234639c-59f0-4861-8448-103febfa612f', '2025-11-11 00:49:32.13134+00');


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

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 15, true);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict lGH1JpwYlE0s44fWWEdDO7E0y2DWEheV7MAYFHnk7slP0rwBizS20qxHWCKdSOd

RESET ALL;
