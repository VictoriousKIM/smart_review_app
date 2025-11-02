SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict 1RvMhVJKmNIlDjbeZqIci1NNNwocXPpwcDPn0nVtFE6gQ55rhvHlq8hmjZKmB31

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
	('00000000-0000-0000-0000-000000000000', 'd19e380e-d86d-4514-9fd9-0aec6de249e5', '{"action":"user_signedup","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"google"}}', '2025-09-26 02:04:14.974543+00', ''),
	('00000000-0000-0000-0000-000000000000', '61b46b5e-2bac-4a9a-8e6c-cd1f51ff91d8', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 02:05:43.311625+00', ''),
	('00000000-0000-0000-0000-000000000000', '2e8fa92b-6521-4891-97cb-1e0a347caf72', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 02:06:29.046954+00', ''),
	('00000000-0000-0000-0000-000000000000', '928f2171-9a48-4272-8fe0-9817c98caf34', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 02:06:45.352147+00', ''),
	('00000000-0000-0000-0000-000000000000', '91b3c1f0-cd6f-4c2e-a1b0-f04103401d1f', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 02:06:46.588586+00', ''),
	('00000000-0000-0000-0000-000000000000', '5296d191-bf10-452d-b2ab-1c83b992488c', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 02:11:24.403766+00', ''),
	('00000000-0000-0000-0000-000000000000', '514475ad-8810-4c6b-b2f9-5ade609decf4', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 02:11:26.776728+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b64cb91d-5b77-4354-adf0-0c8d4e45de2d', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 02:11:38.476552+00', ''),
	('00000000-0000-0000-0000-000000000000', '3c7634ed-a050-4422-b9c3-8d0638000b0c', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 02:13:47.845501+00', ''),
	('00000000-0000-0000-0000-000000000000', '79d514e9-a756-4552-80ea-5a8ee97a5f9d', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 02:13:50.038994+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a346b895-022e-4aea-8a53-b8e5228a2855', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 02:15:13.316857+00', ''),
	('00000000-0000-0000-0000-000000000000', '61141c62-c0bb-42a7-872b-fd7b6a8a4691', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:23:28.621265+00', ''),
	('00000000-0000-0000-0000-000000000000', '2e9189a0-54e6-45df-9ef2-5c1af79ffa41', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:23:29.90209+00', ''),
	('00000000-0000-0000-0000-000000000000', '3d1dd9a4-1d01-4e45-9545-39bb04cad746', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:26:50.011472+00', ''),
	('00000000-0000-0000-0000-000000000000', '83790821-1b33-4e77-9e67-8d040637c8c7', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:26:52.105224+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c73f8973-8af2-4937-9d6a-a2668eb93c83', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:27:29.299507+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b0c101cf-c7c5-45c1-a5db-1bc44b5b498a', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:29:15.892149+00', ''),
	('00000000-0000-0000-0000-000000000000', '37558f26-acac-46dd-a166-390e6978919c', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:29:58.222175+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f171be67-eabb-4619-b368-25d77faf9e49', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:29:59.363045+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f1f08be0-bb62-42d8-9bf4-cbb63615914c', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:30:51.889689+00', ''),
	('00000000-0000-0000-0000-000000000000', '8ce4e41b-f89e-4662-90e4-8b949ea80ed0', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:31:18.035464+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f91fd534-7824-4df5-a22f-628dd8eb7c38', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:31:19.20619+00', ''),
	('00000000-0000-0000-0000-000000000000', '3b3c5cae-69a7-4d0b-b350-262f96590172', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:31:23.541063+00', ''),
	('00000000-0000-0000-0000-000000000000', '1bce5fe5-9341-4e33-88b1-11e5dbe598e6', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:32:50.070843+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ce7a9d95-51c2-4a5f-875d-9b01e1940e0f', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:32:51.37997+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e4f22293-b1ef-4984-aa59-927588e9d26d', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:33:15.895661+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e07d5098-9b21-47c0-8a75-8ea2fd88abb0', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:35:01.461247+00', ''),
	('00000000-0000-0000-0000-000000000000', '134b38bf-8f4d-41ef-b03f-22534ad605de', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:35:56.897085+00', ''),
	('00000000-0000-0000-0000-000000000000', '5cf91e68-2cb5-400e-b6aa-44b6520ee519', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:35:58.460139+00', ''),
	('00000000-0000-0000-0000-000000000000', '55c70100-6064-429d-8c9a-5d0152e2eece', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:36:18.218395+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e12d1001-843a-42cd-9f72-f9b8d265ff2c', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:37:08.776452+00', ''),
	('00000000-0000-0000-0000-000000000000', '94edd2aa-1737-4db2-b574-8f1932f1aa7e', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:37:09.992386+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c36667ba-8e2d-4f8f-b151-60f1bd319510', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:37:32.285316+00', ''),
	('00000000-0000-0000-0000-000000000000', '90ce7c4d-23d3-4c9e-80bb-c376fd34bf5c', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:39:07.674217+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e2e51c7b-8d94-4cb2-bcd7-10fc9576c2fb', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:39:09.877033+00', ''),
	('00000000-0000-0000-0000-000000000000', '1d08d725-4faa-4787-a7b5-9c9f8db3d526', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:39:41.544849+00', ''),
	('00000000-0000-0000-0000-000000000000', '4e00a214-7baa-44a1-9de5-e46fa65c3767', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:43:22.062599+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a49e0122-5061-47b7-a58a-d9359d74d553', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:43:23.415007+00', ''),
	('00000000-0000-0000-0000-000000000000', 'af346db5-e1e7-4286-b4f3-403cbaf474da', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:43:50.506448+00', ''),
	('00000000-0000-0000-0000-000000000000', 'bf78db8c-1178-4163-910f-c6c4f360a9f2', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:45:13.086724+00', ''),
	('00000000-0000-0000-0000-000000000000', '72c76136-9490-40fc-bc61-c41807b356bd', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:45:14.21583+00', ''),
	('00000000-0000-0000-0000-000000000000', '9a206a95-6c98-47ab-bd9a-523514d2e839', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:45:33.710231+00', ''),
	('00000000-0000-0000-0000-000000000000', '7773afdb-c888-4acc-b466-334bf1216fd2', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:46:31.291349+00', ''),
	('00000000-0000-0000-0000-000000000000', '11eb7902-a521-422f-897b-a70ad1f15d3f', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:46:32.39401+00', ''),
	('00000000-0000-0000-0000-000000000000', '0ddfe6bd-7ff0-4893-8ed2-86b35a36d33e', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:46:56.81466+00', ''),
	('00000000-0000-0000-0000-000000000000', '6b840366-7490-4fc1-9872-b6b16adb24d6', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 04:47:36.752292+00', ''),
	('00000000-0000-0000-0000-000000000000', '67e74064-7e4b-4979-9570-41121c553144', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 04:47:37.899448+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f891d40e-f5b0-4b39-82be-de9a1ffa7734', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 04:47:42.093487+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c4621bb5-62e7-4f5e-b0e9-9b17a8fb4d30', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 05:08:07.494835+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f4466c2d-708e-47b7-a394-600610ba1b82', '{"action":"login","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 05:08:09.154033+00', ''),
	('00000000-0000-0000-0000-000000000000', '0ae35ddf-ec1b-4fb0-93f5-cf6576289068', '{"action":"logout","actor_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 05:09:05.545965+00', ''),
	('00000000-0000-0000-0000-000000000000', '2f8ae04b-dc38-4b26-bb9c-7aad4874dc3e', '{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"nightkille@gmail.com","user_id":"dffb5b3c-0c95-4def-b0d9-6769e7ec3653","user_phone":""}}', '2025-09-26 05:09:16.306089+00', ''),
	('00000000-0000-0000-0000-000000000000', '138f4e34-d06a-469d-9ff2-c105c8ef8253', '{"action":"user_signedup","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"google"}}', '2025-09-26 05:09:25.604269+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f4b5685c-b66b-434e-acdf-d67e850417a6', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 05:09:26.685008+00', ''),
	('00000000-0000-0000-0000-000000000000', '300d00cd-bd9d-4ba8-9f84-e3e04b068019', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 05:13:40.405573+00', ''),
	('00000000-0000-0000-0000-000000000000', 'eda47b57-559e-4dc9-b094-467923cc7c29', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 05:14:04.31253+00', ''),
	('00000000-0000-0000-0000-000000000000', 'fcad7a00-1b41-4360-bc9d-85e6796f8d1e', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 05:14:05.403527+00', ''),
	('00000000-0000-0000-0000-000000000000', '5deaeefc-4cc5-4721-8270-c7ec61702229', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 05:14:12.709265+00', ''),
	('00000000-0000-0000-0000-000000000000', '1d9513a5-0cad-49f4-9a9b-56fcc0409189', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 05:16:35.158872+00', ''),
	('00000000-0000-0000-0000-000000000000', '8c6e87aa-7295-4717-8162-20ee29aa6e30', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 05:16:36.576151+00', ''),
	('00000000-0000-0000-0000-000000000000', '26b1d4eb-df33-4cbb-8791-e2d9adaabefa', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 06:24:15.179819+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e9b2cc48-ee16-4c2d-a4e4-c72f341f5e57', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-26 23:58:26.088356+00', ''),
	('00000000-0000-0000-0000-000000000000', '293b67fc-8c3e-4784-b300-aa184688ac87', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-26 23:58:27.248146+00', ''),
	('00000000-0000-0000-0000-000000000000', '5b1b595d-801b-4184-97b1-c34840e827f0', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-26 23:58:33.801905+00', ''),
	('00000000-0000-0000-0000-000000000000', '6aec6240-2352-49a8-bf40-fe55ac242d28', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:01:22.834131+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c2e046af-e2ed-427e-a257-ea4bf2f74234', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:01:23.910269+00', ''),
	('00000000-0000-0000-0000-000000000000', '42b82ccc-b968-48ba-808e-ea697f261a03', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:01:28.830119+00', ''),
	('00000000-0000-0000-0000-000000000000', '1e8cd5f0-d77c-40a6-a32c-bd04232b35d5', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:03:49.508764+00', ''),
	('00000000-0000-0000-0000-000000000000', '9b90d72f-676d-4ec9-adaa-aa5a3761e1f1', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:03:50.962004+00', ''),
	('00000000-0000-0000-0000-000000000000', '42ab27b3-bfab-4037-b34c-c3285faac0c9', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:04:09.709464+00', ''),
	('00000000-0000-0000-0000-000000000000', '9bcdf065-dabc-4b92-8461-6296308970c7', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:05:36.563675+00', ''),
	('00000000-0000-0000-0000-000000000000', '57e7fcf8-e78c-4936-bfff-96c3d44207eb', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:05:37.754268+00', ''),
	('00000000-0000-0000-0000-000000000000', '817e8677-0234-45fa-a5cb-8749e5ef5beb', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:05:55.149805+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a4de80a0-b152-4acb-bac0-f2de092e40e8', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:13:49.810556+00', ''),
	('00000000-0000-0000-0000-000000000000', '5ed4371c-0cd5-45bb-b6f4-6914e1375a14', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:13:51.012221+00', ''),
	('00000000-0000-0000-0000-000000000000', '78e6b1bc-451c-4622-973d-0b6b84ab3161', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:13:56.511948+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd3517cfe-0d57-4b6d-8636-46317d1ad3b2', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:14:16.065666+00', ''),
	('00000000-0000-0000-0000-000000000000', '2d2668f4-0d59-47b4-a624-221508563a6a', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:14:17.126937+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd7899785-81ab-4759-90f5-850599b26f8f', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:14:21.710284+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd6029d17-9884-42c3-88a8-3e5c757fc43b', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:16:29.181563+00', ''),
	('00000000-0000-0000-0000-000000000000', '541d7ef3-9923-4b4e-8c1a-be87253eceb3', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:16:30.80233+00', ''),
	('00000000-0000-0000-0000-000000000000', '833a76f3-df78-4cf1-975b-cecb3604080e', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:16:51.761138+00', ''),
	('00000000-0000-0000-0000-000000000000', '62a6c0e7-7a54-486e-b810-5f5a5324a52d', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:19:18.011705+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a2ddca9c-f729-4917-a51f-5f0749a46794', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:19:19.125668+00', ''),
	('00000000-0000-0000-0000-000000000000', '5dee7709-5f6a-438f-b25f-f6c19596c776', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:19:23.906803+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ef1dd5eb-7d02-4986-8cb8-f762291ff00d', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:21:50.733483+00', ''),
	('00000000-0000-0000-0000-000000000000', '367f5b7c-a3a9-429c-9d10-6ddfc7810c1f', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:21:52.099872+00', ''),
	('00000000-0000-0000-0000-000000000000', '09154a00-25bf-44ec-aa6d-0e01e0e77970', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:22:17.490002+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a76f1ddd-a82e-45c8-8d08-9398235fa46d', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:23:06.458162+00', ''),
	('00000000-0000-0000-0000-000000000000', '09f540da-d8f4-44b4-9518-fa787ccb0c93', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:23:07.582129+00', ''),
	('00000000-0000-0000-0000-000000000000', '499635b6-f4e1-4594-9f3c-4380c304ffdb', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:23:53.192784+00', ''),
	('00000000-0000-0000-0000-000000000000', '77aa97db-aad8-4630-9eeb-78dfcc6c2cb7', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:24:19.848344+00', ''),
	('00000000-0000-0000-0000-000000000000', 'bead7ed1-4aed-46c0-ac3d-c4d47e46dd83', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:24:21.055797+00', ''),
	('00000000-0000-0000-0000-000000000000', 'be2c4b5a-8735-4012-88ba-14704f391859', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:24:26.2388+00', ''),
	('00000000-0000-0000-0000-000000000000', 'eb1bf3e7-3b8d-4b2c-9f3d-4e98e7c4fd01', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:26:24.659032+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e47185c0-4a1c-4b7d-b8bb-970b8d3e5366', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:26:25.708972+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e25d08b0-876c-4a36-be3a-bc3174fbcbf4', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 00:26:46.342649+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e88575b9-c0ce-487d-bb30-419b9be0424d', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:30:14.579254+00', ''),
	('00000000-0000-0000-0000-000000000000', '9ba73766-4204-4675-a0cc-25e9b1176b05', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 00:30:15.694542+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a22cea7c-362b-4208-9f81-eb8020ba927b', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 00:53:56.587587+00', ''),
	('00000000-0000-0000-0000-000000000000', '1bf2fd42-a8fc-4715-8441-611e856011f5', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:03:06.535715+00', ''),
	('00000000-0000-0000-0000-000000000000', '312f1328-8157-4127-9d1e-120bb61f5fbf', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:05:38.408625+00', ''),
	('00000000-0000-0000-0000-000000000000', '3b873553-27f1-459d-8490-77f951fb4269', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:05:40.114585+00', ''),
	('00000000-0000-0000-0000-000000000000', '348ed541-941e-43dc-975e-f6826cd56272', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:06:39.2167+00', ''),
	('00000000-0000-0000-0000-000000000000', 'bd1fa27d-9824-4a30-8e12-36dd45783e84', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:23:37.658245+00', ''),
	('00000000-0000-0000-0000-000000000000', '4ac53d8f-7cd1-4653-86ca-de8a23d65063', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:23:39.284144+00', ''),
	('00000000-0000-0000-0000-000000000000', 'acbe23c5-fe87-49d1-9f1f-c74ef86c18a5', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:31:33.278807+00', ''),
	('00000000-0000-0000-0000-000000000000', '93a9ebb2-9824-4c75-a7ea-b3a13bf5b1ab', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:34:28.891776+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b113ffa6-d504-4dbd-9996-1b32366dbc29', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:34:30.365317+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ae75676a-5a6a-4eeb-b401-246c8a81cc96', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:34:38.469968+00', ''),
	('00000000-0000-0000-0000-000000000000', '60750b8f-1a1b-4830-8ed3-3c99fc6fd1fe', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:36:08.40063+00', ''),
	('00000000-0000-0000-0000-000000000000', '2c24d810-3b0f-4c50-a58e-26782c94bf7e', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:36:09.655997+00', ''),
	('00000000-0000-0000-0000-000000000000', 'a0bd431b-9b6d-4c94-878c-532c4c0c81c9', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:36:18.393816+00', ''),
	('00000000-0000-0000-0000-000000000000', '81e3e60b-f231-495f-ac6e-dd470f81fbcd', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:42:07.426284+00', ''),
	('00000000-0000-0000-0000-000000000000', '2da134c7-89ff-4920-b036-a4433abf3c22', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:42:08.968783+00', ''),
	('00000000-0000-0000-0000-000000000000', '2a2e4e57-fb32-4a23-91b4-e8b0eee1ba7b', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:54:01.343117+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ac5bd557-4fb4-4381-9b39-9574be52fa86', '{"action":"user_signedup","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"google"}}', '2025-09-27 01:54:16.207235+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f54b907d-971e-4be8-bc5b-2d3afe3ded45', '{"action":"login","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:54:17.498993+00', ''),
	('00000000-0000-0000-0000-000000000000', '54d579bf-f151-40ec-b2c0-ded3698ebb9e', '{"action":"logout","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 01:54:24.202969+00', ''),
	('00000000-0000-0000-0000-000000000000', 'cd11837a-45f8-4dbc-95f9-278f0e7aba93', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 01:58:09.148483+00', ''),
	('00000000-0000-0000-0000-000000000000', '6db3416f-2749-47e5-acf0-1f3772f76f3e', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 01:58:11.56318+00', ''),
	('00000000-0000-0000-0000-000000000000', '51d3d556-a705-4f93-b126-d854b029a51f', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 02:00:44.253466+00', ''),
	('00000000-0000-0000-0000-000000000000', '1ba06c38-e55e-432c-b19f-1f45c6575f56', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 02:00:48.016846+00', ''),
	('00000000-0000-0000-0000-000000000000', '2e00d73f-700a-45fe-87d2-2d055e2c071e', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 02:03:55.661015+00', ''),
	('00000000-0000-0000-0000-000000000000', '2f57c730-c04e-403a-a662-f4ad44dbf766', '{"action":"login","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 02:04:07.340572+00', ''),
	('00000000-0000-0000-0000-000000000000', '712ed8f5-18bc-478d-bb35-25063acc1890', '{"action":"login","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 02:04:08.943636+00', ''),
	('00000000-0000-0000-0000-000000000000', '7376dd86-ee78-4a7a-a0e0-b140bf76bb49', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 02:57:38.768275+00', ''),
	('00000000-0000-0000-0000-000000000000', '43b09e5f-d62c-4d46-825f-8dfc63cf95ea', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 02:57:38.785911+00', ''),
	('00000000-0000-0000-0000-000000000000', '38cef2b7-90f8-4c0b-9a53-3a98d3b56c58', '{"action":"token_refreshed","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 03:04:08.61581+00', ''),
	('00000000-0000-0000-0000-000000000000', '4d390706-a5e2-45d5-afba-de93c3c822f5', '{"action":"token_revoked","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 03:04:08.623551+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f533d4f8-c2bc-4234-a430-199304acaa93', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 03:57:08.827512+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd95d9d03-720d-4f3d-b7cc-dea6d61d750e', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 03:57:08.840078+00', ''),
	('00000000-0000-0000-0000-000000000000', '49166fc3-6cd0-41fc-b736-2f55c9d7168a', '{"action":"token_refreshed","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 04:04:09.147177+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ba45f1d4-0523-4a0c-af9c-a2e6f156c8df', '{"action":"token_revoked","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 04:04:09.162685+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e4c1a4ea-4390-4fc2-b0a5-65db5c893208', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 04:56:38.956357+00', ''),
	('00000000-0000-0000-0000-000000000000', '5f030f26-e8b2-4f38-a28f-ff1e5fb0389d', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 04:56:38.971973+00', ''),
	('00000000-0000-0000-0000-000000000000', 'eedf0739-7198-46ab-9a4d-2b0b80681b91', '{"action":"token_refreshed","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 05:04:08.722606+00', ''),
	('00000000-0000-0000-0000-000000000000', '1a1d74ef-d5d0-44e7-b548-4bc706f5a5a6', '{"action":"token_revoked","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 05:04:08.725108+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f783d988-cc28-41fb-a201-6df36ff15b48', '{"action":"token_refreshed","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 14:12:34.772185+00', ''),
	('00000000-0000-0000-0000-000000000000', '617330bd-98be-4e17-ae4a-26d9e61f2d45', '{"action":"token_revoked","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 14:12:34.794523+00', ''),
	('00000000-0000-0000-0000-000000000000', '02883856-79e9-4d19-89e0-a4254d61c28e', '{"action":"logout","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:12:48.768577+00', ''),
	('00000000-0000-0000-0000-000000000000', '4e37cb99-4905-4231-9ac4-27de367189f4', '{"action":"login","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:13:00.069729+00', ''),
	('00000000-0000-0000-0000-000000000000', '34c36885-962f-4642-b878-eb0a8d8fe33e', '{"action":"login","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 14:13:01.40012+00', ''),
	('00000000-0000-0000-0000-000000000000', '6ea8d32c-0f92-4333-9ba0-d9f9c8436234', '{"action":"logout","actor_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","actor_name":"치즈두번먹기","actor_username":"effectivesun@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:13:09.689269+00', ''),
	('00000000-0000-0000-0000-000000000000', '134dc4df-f5f7-4f9f-a290-e3e626a73154', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:19:47.473207+00', ''),
	('00000000-0000-0000-0000-000000000000', '3099dd80-9966-4677-95cc-adfdca6a2ba4', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 14:19:50.163162+00', ''),
	('00000000-0000-0000-0000-000000000000', 'fc277bb1-2206-4ffa-8486-67a1d1c4aeba', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 14:22:19.839961+00', ''),
	('00000000-0000-0000-0000-000000000000', '3e8b68f0-c2cb-4e79-aa72-73d1460014c3', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 14:22:19.841623+00', ''),
	('00000000-0000-0000-0000-000000000000', '7ba8901b-9370-478a-9085-95d59cf3fc6f', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:22:28.985441+00', ''),
	('00000000-0000-0000-0000-000000000000', '561d7d9b-59c0-4f3b-b4c8-08ad4efba646', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:22:35.8754+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ed021139-813e-4b86-9790-d41aab026d52', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:25:06.691939+00', ''),
	('00000000-0000-0000-0000-000000000000', '5947b18e-49a8-484f-880c-d0d897fdaf09', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 14:25:08.395319+00', ''),
	('00000000-0000-0000-0000-000000000000', '7c56452d-b4be-4e4a-a44c-d5605bc36597', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:28:04.321902+00', ''),
	('00000000-0000-0000-0000-000000000000', '9a9ce6e7-ed5a-468e-a2a5-109872c52625', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:28:16.823148+00', ''),
	('00000000-0000-0000-0000-000000000000', '626e13fd-1b68-4d80-b852-03f6fff1a3a6', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 14:28:18.33294+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd190ec47-f3ea-4754-9fd1-84a51d7f7648', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:32:34.791262+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f0ee8d7d-e702-49ab-8202-4dc4d142cc3b', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 14:32:47.165959+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd9a3e88b-e855-48f0-9d76-00f34ec24d1d', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 14:32:48.678763+00', ''),
	('00000000-0000-0000-0000-000000000000', '472a209b-94d6-475c-8b1a-1f2e01d988ad', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:36:29.222361+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f6ca1f17-13b2-4270-be69-325a4eaaf211', '{"action":"user_signedup","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"kakao"}}', '2025-09-27 14:50:35.778552+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c2009b9b-c1d3-4818-9e9a-f856aea09304', '{"action":"login","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"kakao"}}', '2025-09-27 14:50:37.465199+00', ''),
	('00000000-0000-0000-0000-000000000000', 'edd8316a-b487-41bf-9ae6-81aac0fe945d', '{"action":"logout","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 14:51:16.292451+00', ''),
	('00000000-0000-0000-0000-000000000000', 'efb123e4-fdcd-4d09-8c6e-fa7790b8c5d5', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 15:06:41.269957+00', ''),
	('00000000-0000-0000-0000-000000000000', '963baa9d-7b6e-45d4-8466-32a6790b13df', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 15:06:43.876281+00', ''),
	('00000000-0000-0000-0000-000000000000', '9236e0d6-f892-4a77-a3e2-e05632757b0c', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 15:06:53.712168+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ce1e9311-bf8a-4789-b076-52717044b39a', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 15:08:00.940553+00', ''),
	('00000000-0000-0000-0000-000000000000', 'b1e7bdb3-076a-4ab1-8425-85a7e33dce05', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 15:08:03.064569+00', ''),
	('00000000-0000-0000-0000-000000000000', '22ca8129-c3e3-4ebf-8522-d023aa7dd20d', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 15:13:29.574409+00', ''),
	('00000000-0000-0000-0000-000000000000', '49311269-1bfd-4fac-b896-7c7b056c843c', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 15:26:14.908288+00', ''),
	('00000000-0000-0000-0000-000000000000', '2b4d9424-5169-4e80-9a64-522fd6b950d0', '{"action":"logout","actor_id":"00464045-9627-489e-a9c8-b8f5c9529d73","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"account"}', '2025-10-31 02:02:03.886605+00', ''),
	('00000000-0000-0000-0000-000000000000', 'ff7c5e56-55d2-46f4-a65f-f5fc2d3af2e9', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 15:26:17.112566+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e29dddd0-de21-46cb-9282-f383bc181704', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 15:34:42.256594+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e8cb97c1-86da-44ae-802a-ff0749bf3aa6', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 15:34:42.26433+00', ''),
	('00000000-0000-0000-0000-000000000000', '640bd288-56ae-4e13-9528-edb7e031d6fa', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-27 15:34:48.796425+00', ''),
	('00000000-0000-0000-0000-000000000000', '1f72e310-756c-4c77-a127-e0be531707b2', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"google"}}', '2025-09-27 15:35:13.136746+00', ''),
	('00000000-0000-0000-0000-000000000000', '685364a5-b0bf-4319-83a3-e13ea127cc63', '{"action":"login","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"google"}}', '2025-09-27 15:35:14.485657+00', ''),
	('00000000-0000-0000-0000-000000000000', '7dbf7def-da38-45b0-88a6-a997b93c50c5', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 16:35:10.643287+00', ''),
	('00000000-0000-0000-0000-000000000000', '84e489f1-a4a2-4097-ab26-3b130db4077f', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-27 16:35:10.665513+00', ''),
	('00000000-0000-0000-0000-000000000000', '672f7282-c61f-4440-9771-5bb18ee8b67b', '{"action":"token_refreshed","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-28 08:21:42.866333+00', ''),
	('00000000-0000-0000-0000-000000000000', '9610e909-0f07-4110-b9c1-3c67425198f7', '{"action":"token_revoked","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"token"}', '2025-09-28 08:21:42.888844+00', ''),
	('00000000-0000-0000-0000-000000000000', '62bbf438-af9c-4679-9345-49ca53ab2eb1', '{"action":"logout","actor_id":"57061130-ac8c-4189-804a-5cd11f493608","actor_name":"dave kim","actor_username":"nightkille@gmail.com","actor_via_sso":false,"log_type":"account"}', '2025-09-28 08:21:54.806737+00', ''),
	('00000000-0000-0000-0000-000000000000', 'd6cc7354-b286-44fd-a24c-c1fc83b1994d', '{"action":"login","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"kakao"}}', '2025-09-28 08:22:03.617582+00', ''),
	('00000000-0000-0000-0000-000000000000', '8ce9c67f-b3d2-44a2-98a0-d47da4372733', '{"action":"login","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"account","traits":{"provider_type":"kakao"}}', '2025-09-28 08:22:05.053662+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c3ed4943-4e92-4994-86c0-472ae3196e51', '{"action":"token_refreshed","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"token"}', '2025-09-28 09:22:15.939907+00', ''),
	('00000000-0000-0000-0000-000000000000', '6a2675a9-d5f2-4596-83cb-857b2047b9d0', '{"action":"token_revoked","actor_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","actor_name":"동익","actor_username":"nightkille@naver.com","actor_via_sso":false,"log_type":"token"}', '2025-09-28 09:22:15.958201+00', ''),
	('00000000-0000-0000-0000-000000000000', '9c26c4f4-c272-4efb-a09f-f134ca76d928', '{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"nightkille@naver.com","user_id":"8ae1e736-7fc1-4717-a4ee-057d89013894","user_phone":""}}', '2025-10-31 01:59:14.189548+00', ''),
	('00000000-0000-0000-0000-000000000000', '2de425ee-726a-4311-b841-a0b10d83ca0c', '{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"effectivesun@gmail.com","user_id":"f9fbdfee-1ff4-49fc-a0ce-ab9819e5fe33","user_phone":""}}', '2025-10-31 01:59:14.189625+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f1481449-4650-41f8-9a1f-f2b16b6443f0', '{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"nightkille@gmail.com","user_id":"57061130-ac8c-4189-804a-5cd11f493608","user_phone":""}}', '2025-10-31 01:59:14.194584+00', ''),
	('00000000-0000-0000-0000-000000000000', '3d4d5797-7a17-4eec-acc3-e4c082bd8015', '{"action":"user_signedup","actor_id":"a05db6f3-12d2-4b22-a9de-0fd636cbdb22","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-10-31 02:00:09.303167+00', ''),
	('00000000-0000-0000-0000-000000000000', '78c1fff8-26c2-4e11-9aae-c4c9a29d0059', '{"action":"login","actor_id":"a05db6f3-12d2-4b22-a9de-0fd636cbdb22","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-10-31 02:00:09.306863+00', ''),
	('00000000-0000-0000-0000-000000000000', 'c54f2428-a3b4-49df-b5c0-09b53332d212', '{"action":"logout","actor_id":"a05db6f3-12d2-4b22-a9de-0fd636cbdb22","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account"}', '2025-10-31 02:00:24.187171+00', ''),
	('00000000-0000-0000-0000-000000000000', '3e9cca75-9fe1-43f1-b2c4-9333e5deaabb', '{"action":"user_signedup","actor_id":"407c6527-5afd-4a16-96fa-266f10f2606f","actor_username":"test@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-10-31 02:00:44.151697+00', ''),
	('00000000-0000-0000-0000-000000000000', 'bc6fd844-ccb9-47b1-b1df-da0aafbf7cf0', '{"action":"login","actor_id":"407c6527-5afd-4a16-96fa-266f10f2606f","actor_username":"test@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-10-31 02:00:44.154741+00', ''),
	('00000000-0000-0000-0000-000000000000', '0071e1dc-dd12-493e-bd91-6d27592dff2e', '{"action":"logout","actor_id":"407c6527-5afd-4a16-96fa-266f10f2606f","actor_username":"test@example.com","actor_via_sso":false,"log_type":"account"}', '2025-10-31 02:00:54.242198+00', ''),
	('00000000-0000-0000-0000-000000000000', '8cd2776b-fff1-4157-b91f-51a66be7d282', '{"action":"user_signedup","actor_id":"44527cf5-363a-4f99-b17a-dbe28221f5d6","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-10-31 02:01:44.203506+00', ''),
	('00000000-0000-0000-0000-000000000000', 'bd14e6d9-b813-479d-b2de-11f611fd9493', '{"action":"login","actor_id":"44527cf5-363a-4f99-b17a-dbe28221f5d6","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-10-31 02:01:44.207028+00', ''),
	('00000000-0000-0000-0000-000000000000', 'f402426c-c99c-4460-b39b-d0cc1f6b8ad4', '{"action":"logout","actor_id":"44527cf5-363a-4f99-b17a-dbe28221f5d6","actor_username":"reviewer@example.com","actor_via_sso":false,"log_type":"account"}', '2025-10-31 02:01:48.043933+00', ''),
	('00000000-0000-0000-0000-000000000000', '0b833063-1d96-4f0f-9bae-934e6c98a1f1', '{"action":"user_signedup","actor_id":"00464045-9627-489e-a9c8-b8f5c9529d73","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-10-31 02:01:59.675821+00', ''),
	('00000000-0000-0000-0000-000000000000', '6e7e20dc-2137-4ebc-8599-825fcdb450b9', '{"action":"login","actor_id":"00464045-9627-489e-a9c8-b8f5c9529d73","actor_username":"company_owner@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-10-31 02:01:59.678865+00', ''),
	('00000000-0000-0000-0000-000000000000', '130283e0-328d-47ed-b664-aec897667bb0', '{"action":"user_signedup","actor_id":"d60c7575-e928-4899-a536-0729e96fd34a","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"team","traits":{"provider":"email"}}', '2025-10-31 02:02:19.471387+00', ''),
	('00000000-0000-0000-0000-000000000000', '720a1b75-7d8a-45a7-a73a-6ef16bf8d339', '{"action":"login","actor_id":"d60c7575-e928-4899-a536-0729e96fd34a","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-10-31 02:02:19.47522+00', ''),
	('00000000-0000-0000-0000-000000000000', '4a5d074f-f263-4242-b565-edfc159e7f19', '{"action":"logout","actor_id":"d60c7575-e928-4899-a536-0729e96fd34a","actor_username":"company_manger@example.com","actor_via_sso":false,"log_type":"account"}', '2025-10-31 02:02:24.71274+00', ''),
	('00000000-0000-0000-0000-000000000000', 'e6853118-7f24-4fe1-a1f1-4e6fdfbc2005', '{"action":"login","actor_id":"a05db6f3-12d2-4b22-a9de-0fd636cbdb22","actor_username":"dev@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}', '2025-11-02 12:22:41.375248+00', '');


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."flow_state" ("id", "user_id", "auth_code", "code_challenge_method", "code_challenge", "provider_type", "provider_access_token", "provider_refresh_token", "created_at", "updated_at", "authentication_method", "auth_code_issued_at") VALUES
	('83fca866-f835-49e4-96db-30a8def62dea', NULL, '5747d50e-9f26-422f-9f3d-583afcfa04eb', 's256', '0zR_i92XeiRl-LEshKAtHN5NaAS_A2AaMaUx_GGXfLA', 'google', '', '', '2025-09-27 16:11:16.88168+00', '2025-09-27 16:11:16.88168+00', 'oauth', NULL),
	('cd850b4e-669a-4301-9a89-d8bc19718220', 'dffb5b3c-0c95-4def-b0d9-6769e7ec3653', '1fb5a46a-2fc0-4eb1-a089-3f86c28d2b83', 's256', 'd7s_6RJ7IyHJMIJ43ksJp6ADPvZs13_SiljSXq1pacA', 'google', 'ya29.a0AQQ_BDRRiZsycQawzOkjdHbAdHUmcUF5vHUgS2NWFkWsM1mBLiLnK_dvdKc1BJgqVP6QETap4uLsZ2Cr1-nVa7f4D83BGUvzERHsZSP22U-3CS3xW97faqd1zlOWZPuxExqqcfvw6bUrFE8P6mwsDsdYa9PmcvILmM5uwLlVB3_i3nbRo5EUWvbsbcN5BXd14JUq5v4aCgYKAWwSARQSFQHGX2Mi9_UNMCvTRbEZCC5NH0KYxA0206', '1//0eSdmr39XFKZaCgYIARAAGA4SNwF-L9IrhsbzO0sim6ZFxEXoE7jgoZjBu74GOIsyfoHx6eHmVKZHBUWeRqyv94-ISRjZxqcOx68', '2025-09-26 02:03:44.476491+00', '2025-09-26 02:04:14.996469+00', 'oauth', '2025-09-26 02:04:14.996414+00'),
	('a5e184c1-cd48-46b1-8174-c314224d93dd', NULL, '6ba59b13-cb3d-41af-90e5-9681195a77e6', 's256', 'Y74oRkPKDZ7pDK0QglFN1VeuyUmNkzWZqKhX46KwWRg', 'google', '', '', '2025-09-28 08:21:23.339057+00', '2025-09-28 08:21:23.339057+00', 'oauth', NULL),
	('a1cdca4a-653e-4ed5-b2a9-3423d45e6451', 'dffb5b3c-0c95-4def-b0d9-6769e7ec3653', 'd722f0a6-74b9-4351-be3d-65b7487417fb', 's256', '3cPwGrurMavNs9gkTs8fdpz1K16ZJyfodJqIgjqwTCE', 'google', 'ya29.a0AQQ_BDSwA5MXaTcbxFelCvWtdJlRmnmlz_sZERWJMoksH1Vu64fteFNgfnFShMCl3d7zmtLDoIDNfyRv5pyir9NWPuEQ-IiUxlLaQFu3qyxSVYjWbvMg0LRxYgkXVVrCSi4Sj2z3RCI48J14T5eCdra2UpB1akZa5CpEEMTwcW0k8FWCTT5fkiilvaDQekSvYaTU1ikaCgYKATsSARQSFQHGX2MiMd314yw2qjJUoUzHdlw8LA0206', '1//0e7Qv8r7t0A-xCgYIARAAGA4SNwF-L9Ir8F41mV80VwXpiLI-87lrKfdFUB77fz3wOaiyT8VLYjAjxI31iJGXqd1phgPuRjKF4bE', '2025-09-26 02:05:37.614404+00', '2025-09-26 02:06:29.047912+00', 'oauth', '2025-09-26 02:06:29.047842+00'),
	('609376ea-5755-43a3-92e5-7bf786f97dea', NULL, '5d88d627-fd29-48e1-9225-27ff4c4e7030', 's256', 'hPlu2xzniJn7MZX2hkDyKKc77FqWaCwUARu7s7IDs8U', 'google', '', '', '2025-09-28 08:32:45.985122+00', '2025-09-28 08:32:45.985122+00', 'oauth', NULL),
	('540d821e-c517-4a34-bbcd-114004f9b733', NULL, 'fae9c23c-6ffc-4af9-a3ed-0a1b70094556', 's256', 'RnEwAL4QINc35cY8iY3YpCAcR7Y7bjF6uU0o3UtWUWg', 'google', '', '', '2025-09-28 08:52:06.450681+00', '2025-09-28 08:52:06.450681+00', 'oauth', NULL),
	('a27e6ace-960f-4cad-af28-367636ff2a98', NULL, '81fd40bb-b19e-4f92-a172-94d4b8baf2cd', 's256', 'uWS2CY21b5WG4Qs82CIkdsZgd8PCfRkzNzEPSzUGqeI', 'google', '', '', '2025-09-26 04:21:30.399317+00', '2025-09-26 04:21:30.399317+00', 'oauth', NULL),
	('79849857-59dd-411b-888e-cdcd5f918d8d', NULL, '147345ea-86f3-464d-b146-d66846661301', 's256', 'vUVXx68k5xd92crfLSkf5Oh55BgltShHcy2YzejwYMU', 'google', '', '', '2025-09-26 04:22:49.637575+00', '2025-09-26 04:22:49.637575+00', 'oauth', NULL),
	('a111f19a-d093-450d-863a-27caba62beaf', NULL, '3a7893fe-0589-4913-8fc6-bf2b527ee9d9', 's256', 'nNaNuXbmliQxpEx1XcnueDOtANVBPtcutkI93A2ULL4', 'google', '', '', '2025-09-27 00:29:47.565273+00', '2025-09-27 00:29:47.565273+00', 'oauth', NULL),
	('6a321bb0-2853-4923-a2b7-6c3298163476', NULL, '4911b334-eb00-4aa6-9a2b-2bef52b8e66b', 's256', 'SNdpfqqleT0XVUbtStmcs0MPOVjf_7xCpfLH5jNiyDU', 'google', '', '', '2025-09-27 00:30:03.860638+00', '2025-09-27 00:30:03.860638+00', 'oauth', NULL),
	('6430b3f1-2a76-4daf-bd09-b41b23f50243', NULL, '6f0f4466-47e0-4a79-bdb4-bd768bb9f60e', 's256', 'nN5Y8D6Z1gfTtckkLwpHzXOvFOk-P5H1edsIRZgfO0A', 'google', '', '', '2025-09-27 00:53:25.398083+00', '2025-09-27 00:53:25.398083+00', 'oauth', NULL),
	('81e88ea1-b646-45d6-a15d-73105d67d96a', '57061130-ac8c-4189-804a-5cd11f493608', 'ff4f31d1-d087-4a8f-8f23-975b49a24b18', 's256', 'hebQ8eNiMIdg7-wrpmciIr47_E7YaGHY1LZT1tWKv50', 'google', 'ya29.a0AQQ_BDQl6Ok9Xgut1wvkhIpKD8nNKbwErQePJPXkmzregQvw-PVFNRaof1Gj-MBQs2x0cA_2_eMZafUJ6MYLh6aQ2yBusQHACrPYq7_bSB9KA7U_rY3LGNlu8ATILgrlGXVtIxkyVQ9rvKNaMb5fIMfEhVUhtrBExmx4XBvkqc1FmfROnySK5m6uWJ1w6A2SLcJdW5oaCgYKAasSARQSFQHGX2MijuGmfedP9ePXhiDidS7Wfw0206', '1//0ew7z1ZfMxypmCgYIARAAGA4SNwF-L9Ir2ft9WmCTRFaD2Pg7ukY3yhqRVBnUxj2yeWLC2rHxOJpdHsv4Ib0xamTz_6pIYELtEhg', '2025-09-27 00:53:51.109756+00', '2025-09-27 00:53:56.590114+00', 'oauth', '2025-09-27 00:53:56.589511+00'),
	('41f6f863-5a3c-4580-9eaf-2be65f805d2f', 'dffb5b3c-0c95-4def-b0d9-6769e7ec3653', '2741020d-dde7-4b5b-9ee7-753716ba2eed', 's256', 'ZK6W58JPGJ5fvVZ1SsK25upZMbeS0DZ5QfMqhYJaSf4', 'google', 'ya29.a0AQQ_BDTB7ev96RWyGljXJPFqInZXZLe2UsoEvIyZfe6q1u7n6nwAya10yrkdv9FmO58M5GXmQoFGic8uIjs5TvMou1yrm1SwyCRGNF3Sqc-dEHtggbUJp4efhIVGvLnZUwfgB7tAkxO194VLY50GE8xcEN-SwOI_5w7jiD8O6X8rsCD9IA4QBsKG33Ui8UMjo17NyLAaCgYKAYMSARQSFQHGX2MijgcQ5cWXKbjKoFQhIQjOKg0206', '1//0eutDDWOMJa5-CgYIARAAGA4SNwF-L9Ir-HWt6JoI-jyNKm3EfArclnn7sxb2Q0VP4TFd1L1QFhNLlr_dF1qHNp1E9x6E_GqCX1A', '2025-09-26 04:34:32.029634+00', '2025-09-26 04:35:01.462111+00', 'oauth', '2025-09-26 04:35:01.462052+00'),
	('527b0df1-14ff-4bf1-afb7-09c10852f68f', '57061130-ac8c-4189-804a-5cd11f493608', '8c6c9a44-5306-44bf-9570-213c3b433d31', 's256', 'GsSJRpo3CXvIMmG4__v9CShZsYjWzjW64jfIY1Np894', 'google', 'ya29.a0AQQ_BDTSeI84-ZdKvvxJubKqXD-2hcGrzEYi0XFuBcIXBM3s6rqTHouuIOZBHsPB_Q0AgpfrFdmwG7R_T6n2_lsWP-rCsHx7DMbFO54Wqup4AMYPf45sgOqz3IQFrpjuWc-mrltZU6zbItZT6p_yqB0nsDAxMkk40w8gDbMSmzT1Cit3gfz2ysiPBdbf64LIrH8M5d4aCgYKAb4SARQSFQHGX2Miv6A_cN3gue8AQi2QkUsMSg0206', '1//0eSKRADK9CU-VCgYIARAAGA4SNwF-L9IrynJ8HMEDQmSeigP62-Fbg5XfQUC7y2a02CRRKnj2H5EYJ1dyMt2bxVIETKUSGJU468U', '2025-09-27 01:03:00.633917+00', '2025-09-27 01:03:06.537613+00', 'oauth', '2025-09-27 01:03:06.537554+00'),
	('9c9d55dd-84d8-42c2-b942-a4eed495fba0', NULL, '35783d4b-5719-4e7a-88d3-2715ae5406ee', 's256', 'll2PK2X8haiA1AFxFLbTjOtF1-EkFKTzSbPDl5_ZN2Y', 'google', '', '', '2025-09-27 01:06:49.040823+00', '2025-09-27 01:06:49.040823+00', 'oauth', NULL),
	('42ea83f9-357e-41bd-9ae8-0a3b341d9e6a', NULL, '1bb8feef-8a6f-446e-95af-1d0322411b92', 's256', 'I-AhFUa4Yb4xzWJDGnl4FkZo36AzB3xtoue3pkgQHaI', 'google', '', '', '2025-09-27 01:10:38.14948+00', '2025-09-27 01:10:38.14948+00', 'oauth', NULL),
	('36d9c95e-1654-491b-812b-9f0b74f8161e', NULL, '63f439ea-8950-46af-8fde-d83d42a3f5d2', 's256', 'A8O_Yo_UX8gtvD2m0_IubPjaFDQuUxD9VLR7TXl0Oys', 'google', '', '', '2025-09-27 01:41:46.542551+00', '2025-09-27 01:41:46.542551+00', 'oauth', NULL),
	('f11d8d2d-6d54-4b66-8963-6d501b4425dc', '57061130-ac8c-4189-804a-5cd11f493608', '5c345820-7433-4692-bfbe-7e6c3f6b3fa4', 's256', 'TZ1OsLhAcJME3Pjv-Ji3s4Eg7uZX3WWN5JdvOHhLpVg', 'google', 'ya29.a0AQQ_BDTglorO8CpWxfQMSS01yveksndN-OigjOHinJbWjHH58ypJloqnbBVwu-VsixKDmucWDVQwSOrbiR8kyS_0uL2D6JUzyY12cmrR_HH5EYDoF49Kv_tBeYY9hT9mozZMyshR-O6spO-fcW_FhCaf1yT0_-rpS9YKRhIJNsc_R626jEzyYFNmE5NnYFOppZzNWu0aCgYKARQSARQSFQHGX2Mi7tyM2nguo_fTqFJqu0IrGw0206', '1//0eWvDmgs59m96CgYIARAAGA4SNwF-L9IrzRpigqaDexShYGOH1yBBxJfjv57xgKST0J7qwhV-jmSmOJ1kQyv20WL3_aWasMbwtrg', '2025-09-26 06:23:51.339322+00', '2025-09-26 06:24:15.189973+00', 'oauth', '2025-09-26 06:24:15.189302+00'),
	('c5a1d674-0345-4439-9b4b-b476432c9858', NULL, '9616cac2-efe0-490d-b2cc-d04931ac653c', 's256', 'UtQOmeel7uBOGWI-DYoLxVpakBtyV0W3J3CJ5IdtOA8', 'google', '', '', '2025-09-26 23:57:55.976007+00', '2025-09-26 23:57:55.976007+00', 'oauth', NULL),
	('947c2201-d260-43d2-9fa0-231e045d8169', NULL, 'c621d041-04ac-4834-aec4-444bce289382', 's256', '12PwtuVFVOieQaGolZyA3IHjzmv0TiRqRJtAN6oH1RM', 'google', '', '', '2025-09-27 14:12:17.734724+00', '2025-09-27 14:12:17.734724+00', 'oauth', NULL),
	('66a7f9b6-a9b2-4b92-8284-fe7ebb4177c3', NULL, 'f55b7fe4-d07a-4022-a6bb-ad3d33c62bc6', 's256', 'jpfiiTTJFD4J3UMt11aKi64CWpkXdTZKr2cd4oLnff0', 'google', '', '', '2025-09-27 14:14:39.766898+00', '2025-09-27 14:14:39.766898+00', 'oauth', NULL),
	('36cc0fef-5aaa-4875-aaf7-f1f8eada854e', NULL, '9db2990d-2f82-45c3-8bf1-6e44e4890f99', 's256', 'Eh9_8vRqmMUkueojr2KXZ_YL4Fc9ecPNffJW5wOvbmU', 'google', '', '', '2025-09-27 14:19:24.854327+00', '2025-09-27 14:19:24.854327+00', 'oauth', NULL),
	('722d5401-ef5a-46c4-91ff-13bdb48b7465', '57061130-ac8c-4189-804a-5cd11f493608', '28f2c5e3-6ecd-4f1a-8755-969f8d1732aa', 's256', 'RDJpxuNVO8tTI-BZoJ_APLIhHkXgHDRcm-x_vpKqqA4', 'google', 'ya29.a0AQQ_BDRlOCPyt2Dqlt7mLZTa_qTkq-9pbfi7vm9DZDzVCPivn18DIdmwFOVSi8QxsPCls8a22TVS9_7-Ei-DMlCV4kjnnjQ5esh1FgL8o9SIVrZiZ0dGpko7EzRC8M2UAQpbrW84wROdi96K6iY8yPAHxPQ-ZpDIhbOvNwtfYilQpDhx19wLgQSCWcfUlRyxoLpgVPQaCgYKAaUSARQSFQHGX2Mi34HAhBq-yThpzICBbsXE3A0206', '1//0erEo1A--YyRpCgYIARAAGA4SNwF-L9Iroj6xLdKF-zULZVWQbh9RNlXMlt66YMm8Pbe4KOJYMXkTVNtut5mOMSnbL5K9iaGGajs', '2025-09-27 14:22:30.51424+00', '2025-09-27 14:22:35.876643+00', 'oauth', '2025-09-27 14:22:35.876598+00'),
	('62a768dd-65c6-49ea-b1da-324a23058ec6', NULL, '4db336fe-4b16-4c97-9072-32b8b7bf4f2f', 's256', 'Z_h7KAQ79CrLDtSV1RFnh2PqWLk83i0czqwJjlW3GFw', 'google', '', '', '2025-09-27 14:48:50.4416+00', '2025-09-27 14:48:50.4416+00', 'oauth', NULL),
	('645fea26-4dd5-41a6-946a-a1e49975505f', NULL, '4c3e4b6b-388b-497c-864c-f5e58451ee72', 's256', 'C33zi_ClubatT4lykOvrE7OmxMyRtFdeoUaa4j0e4Ks', 'google', '', '', '2025-09-27 15:06:27.981999+00', '2025-09-27 15:06:27.981999+00', 'oauth', NULL),
	('b5902423-a33f-48b6-a531-c45d28a7fdb1', NULL, '175dba9b-b53f-41e8-9768-99042500c780', 's256', 'CoN9oLWCvieCoT66iCLvVFjsE9imIAJIfzzczsF0uNQ', 'google', '', '', '2025-09-27 15:34:29.104756+00', '2025-09-27 15:34:29.104756+00', 'oauth', NULL);


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."users" ("instance_id", "id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "invited_at", "confirmation_token", "confirmation_sent_at", "recovery_token", "recovery_sent_at", "email_change_token_new", "email_change", "email_change_sent_at", "last_sign_in_at", "raw_app_meta_data", "raw_user_meta_data", "is_super_admin", "created_at", "updated_at", "phone", "phone_confirmed_at", "phone_change", "phone_change_token", "phone_change_sent_at", "email_change_token_current", "email_change_confirm_status", "banned_until", "reauthentication_token", "reauthentication_sent_at", "is_sso_user", "deleted_at", "is_anonymous") VALUES
	('00000000-0000-0000-0000-000000000000', 'd60c7575-e928-4899-a536-0729e96fd34a', 'authenticated', 'authenticated', 'company_manger@example.com', '$2a$10$/0Jd.tFxRkyfd2aXSDpSPOowUhVa3K1hKrYfRSUz0jLzGol/Z1WNO', '2025-10-31 02:02:19.471844+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-10-31 02:02:19.47567+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "d60c7575-e928-4899-a536-0729e96fd34a", "email": "company_manger@example.com", "display_name": "company_manger", "email_verified": true, "phone_verified": false}', NULL, '2025-10-31 02:02:19.468886+00', '2025-10-31 02:02:19.476568+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '44527cf5-363a-4f99-b17a-dbe28221f5d6', 'authenticated', 'authenticated', 'reviewer@example.com', '$2a$10$RjlBKUXuqN/EvW/SPCyBK.QqZkjfxiL1lXHyvFhbdx/qrcO2HK0Sq', '2025-10-31 02:01:44.203867+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-10-31 02:01:44.207417+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "44527cf5-363a-4f99-b17a-dbe28221f5d6", "email": "reviewer@example.com", "display_name": "reviewer", "email_verified": true, "phone_verified": false}', NULL, '2025-10-31 02:01:44.200791+00', '2025-10-31 02:01:44.208286+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '407c6527-5afd-4a16-96fa-266f10f2606f', 'authenticated', 'authenticated', 'test@example.com', '$2a$10$X7oViFtcjAUt.wITQEaoVOyDucOAV.zGaeCa7phr4Mpa2RM8yEu9.', '2025-10-31 02:00:44.152003+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-10-31 02:00:44.15504+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "407c6527-5afd-4a16-96fa-266f10f2606f", "email": "test@example.com", "display_name": "test", "email_verified": true, "phone_verified": false}', NULL, '2025-10-31 02:00:44.14947+00', '2025-10-31 02:00:44.155812+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', '00464045-9627-489e-a9c8-b8f5c9529d73', 'authenticated', 'authenticated', 'company_owner@example.com', '$2a$10$KV8mnxaOmD2FESqjGZAG8uwe1fMhcp1Gc9w8vmI0eaAKLPavyeDbi', '2025-10-31 02:01:59.676105+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-10-31 02:01:59.679217+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "00464045-9627-489e-a9c8-b8f5c9529d73", "email": "company_owner@example.com", "display_name": "company_owner", "email_verified": true, "phone_verified": false}', NULL, '2025-10-31 02:01:59.673276+00', '2025-10-31 02:01:59.68003+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false),
	('00000000-0000-0000-0000-000000000000', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', 'authenticated', 'authenticated', 'dev@example.com', '$2a$10$koLPWg.2X7VI1t6cCm5Tj.cxaW0c4xtPO74/CqkhXufnDgvFyqpuS', '2025-10-31 02:00:09.303513+00', NULL, '', NULL, '', NULL, '', '', NULL, '2025-11-02 12:22:41.376676+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "a05db6f3-12d2-4b22-a9de-0fd636cbdb22", "email": "dev@example.com", "display_name": "dev", "email_verified": true, "phone_verified": false}', NULL, '2025-10-31 02:00:09.299936+00', '2025-11-02 12:22:41.388729+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('a05db6f3-12d2-4b22-a9de-0fd636cbdb22', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', '{"sub": "a05db6f3-12d2-4b22-a9de-0fd636cbdb22", "email": "dev@example.com", "display_name": "dev", "email_verified": false, "phone_verified": false}', 'email', '2025-10-31 02:00:09.301795+00', '2025-10-31 02:00:09.30182+00', '2025-10-31 02:00:09.30182+00', '34b2c86a-e60c-4943-a3e8-eddb8bc73066'),
	('407c6527-5afd-4a16-96fa-266f10f2606f', '407c6527-5afd-4a16-96fa-266f10f2606f', '{"sub": "407c6527-5afd-4a16-96fa-266f10f2606f", "email": "test@example.com", "display_name": "test", "email_verified": false, "phone_verified": false}', 'email', '2025-10-31 02:00:44.150687+00', '2025-10-31 02:00:44.150704+00', '2025-10-31 02:00:44.150704+00', 'dc119e4a-64d1-4171-8709-3fa4c0bb4210'),
	('44527cf5-363a-4f99-b17a-dbe28221f5d6', '44527cf5-363a-4f99-b17a-dbe28221f5d6', '{"sub": "44527cf5-363a-4f99-b17a-dbe28221f5d6", "email": "reviewer@example.com", "display_name": "reviewer", "email_verified": false, "phone_verified": false}', 'email', '2025-10-31 02:01:44.202225+00', '2025-10-31 02:01:44.202243+00', '2025-10-31 02:01:44.202243+00', 'f6d79c07-601e-4354-9379-880209211770'),
	('00464045-9627-489e-a9c8-b8f5c9529d73', '00464045-9627-489e-a9c8-b8f5c9529d73', '{"sub": "00464045-9627-489e-a9c8-b8f5c9529d73", "email": "company_owner@example.com", "display_name": "company_owner", "email_verified": false, "phone_verified": false}', 'email', '2025-10-31 02:01:59.674789+00', '2025-10-31 02:01:59.674811+00', '2025-10-31 02:01:59.674811+00', '0c7b487f-a3fb-44aa-88c6-43fb2f66c40a'),
	('d60c7575-e928-4899-a536-0729e96fd34a', 'd60c7575-e928-4899-a536-0729e96fd34a', '{"sub": "d60c7575-e928-4899-a536-0729e96fd34a", "email": "company_manger@example.com", "display_name": "company_manger", "email_verified": false, "phone_verified": false}', 'email', '2025-10-31 02:02:19.470289+00', '2025-10-31 02:02:19.470308+00', '2025-10-31 02:02:19.470308+00', 'c3490653-1660-426b-8d96-7be811b60477');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag") VALUES
	('387ae7d9-c957-462a-9aeb-328b81cd9b76', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', '2025-11-02 12:22:41.379744+00', '2025-11-02 12:22:41.379744+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36', '172.18.0.1', NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('387ae7d9-c957-462a-9aeb-328b81cd9b76', '2025-11-02 12:22:41.390879+00', '2025-11-02 12:22:41.390879+00', 'password', '4d76b66a-b60f-4403-83bd-6d0f0af44130');


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
	('00000000-0000-0000-0000-000000000000', 70, '2gyy6stvnhwf', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', false, '2025-11-02 12:22:41.38564+00', '2025-11-02 12:22:41.38564+00', NULL, '387ae7d9-c957-462a-9aeb-328b81cd9b76');


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

INSERT INTO "public"."users" ("id", "created_at", "updated_at", "display_name", "user_type") VALUES
	('44527cf5-363a-4f99-b17a-dbe28221f5d6', '2025-10-31 02:01:44.244418+00', '2025-10-31 02:01:44.246559+00', 'reviewer', 'user'),
	('00464045-9627-489e-a9c8-b8f5c9529d73', '2025-10-31 02:01:59.697153+00', '2025-10-31 02:01:59.697153+00', 'company_owner', 'user'),
	('d60c7575-e928-4899-a536-0729e96fd34a', '2025-10-31 02:02:19.499361+00', '2025-10-31 02:02:19.501242+00', 'company_manger', 'user'),
	('407c6527-5afd-4a16-96fa-266f10f2606f', '2025-10-31 02:00:44.185451+00', '2025-11-02 11:30:53.131248+00', 'test123', 'user'),
	('a05db6f3-12d2-4b22-a9de-0fd636cbdb22', '2025-10-31 02:00:09.336657+00', '2025-11-02 12:22:41.459816+00', 'dev', 'user');


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."companies" ("id", "business_name", "business_number", "contact_email", "contact_phone", "address", "representative_name", "business_type", "registration_file_url", "user_id", "created_at", "updated_at") VALUES
	('9b930f18-e691-4b8a-a00a-912e687e82de', '포인터스', '8677000726', NULL, NULL, '충청남도 천안시 서북구 직산읍 부송상덕길 28', '김동익', '도매 및 소매업', 'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/business-registration/2025/11/02/a05db6f3-12d2-4b22-a9de-0fd636cbdb22_1762086183216.png', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', '2025-11-02 12:23:00.428404+00', '2025-11-02 12:23:00.428404+00');


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: campaign_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: company_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."company_users" ("id", "company_id", "user_id", "company_role", "created_at", "status") VALUES
	('ac0d41d8-c757-45d4-9d3c-16d271c66331', '9b930f18-e691-4b8a-a00a-912e687e82de', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', 'owner', '2025-11-02 12:23:00.428404+00', 'active');


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
	('3f114006-aeb6-483f-9443-9e37d0e00dd9', 'reviewer', 'a05db6f3-12d2-4b22-a9de-0fd636cbdb22', 0, '2025-10-31 02:00:09.336657+00', '2025-10-31 02:00:09.336657+00'),
	('78e02ce6-d9a5-47d4-ba7f-3394819b4f31', 'reviewer', '407c6527-5afd-4a16-96fa-266f10f2606f', 0, '2025-10-31 02:00:44.185451+00', '2025-10-31 02:00:44.185451+00'),
	('97b26a76-c396-47ce-aa42-2820e9007aab', 'reviewer', '44527cf5-363a-4f99-b17a-dbe28221f5d6', 0, '2025-10-31 02:01:44.244418+00', '2025-10-31 02:01:44.244418+00'),
	('f9bb9a3a-64c0-45f9-9b9f-596e60b51f1c', 'reviewer', '00464045-9627-489e-a9c8-b8f5c9529d73', 0, '2025-10-31 02:01:59.697153+00', '2025-10-31 02:01:59.697153+00'),
	('f2fac920-90c2-479b-89b5-6d26571bb94f', 'reviewer', 'd60c7575-e928-4899-a536-0729e96fd34a', 0, '2025-10-31 02:02:19.499361+00', '2025-10-31 02:02:19.499361+00');


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

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 70, true);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict 1RvMhVJKmNIlDjbeZqIci1NNNwocXPpwcDPn0nVtFE6gQ55rhvHlq8hmjZKmB31

RESET ALL;
