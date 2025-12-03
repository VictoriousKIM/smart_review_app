import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'config/supabase_config.dart';
import 'config/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'services/campaign_realtime_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Supabase 초기화
  await SupabaseConfig.initialize();

  // 웹 환경에서 세션 복원 대기 (F5 새로고침 시 로그인 상태 유지)
  if (kIsWeb) {
    try {
      final supabase = SupabaseConfig.client;
      // localStorage에서 세션 복원 완료될 때까지 대기
      // Supabase는 initialize() 후 자동으로 세션을 복원하지만, 완료될 때까지 약간의 시간이 필요
      // onAuthStateChange 스트림의 첫 이벤트를 기다림 (타임아웃 1초)
      try {
        await supabase.auth.onAuthStateChange
            .timeout(
              const Duration(seconds: 1),
              onTimeout: (sink) {
                sink.close();
              },
            )
            .first;
      } catch (e) {
        // 타임아웃 시에도 계속 진행 (세션이 없을 수도 있음)
        debugPrint('세션 복원 대기 타임아웃 (무시 가능): $e');
      }
      // 세션 복원 확인 및 검증
      final session = supabase.auth.currentSession;
      if (session != null) {
        // 세션이 만료되었는지 확인하고, 만료된 경우 갱신 시도
        if (session.isExpired) {
          try {
            final refreshedSession = await supabase.auth.refreshSession();
            if (refreshedSession.session != null) {
              debugPrint('✅ 웹 세션 복원 및 갱신 완료: ${refreshedSession.session!.user.email ?? refreshedSession.session!.user.id}');
            } else {
              debugPrint('⚠️ 세션 갱신 실패: 세션이 null입니다');
            }
          } catch (e) {
            // "missing destination name scopes" 에러인 경우 손상된 세션으로 간주하고 삭제
            if (e.toString().toLowerCase().contains('missing destination name scopes')) {
              debugPrint('⚠️ 손상된 세션 감지. 자동 로그아웃 처리');
              try {
                await supabase.auth.signOut();
              } catch (_) {
                // 로그아웃 실패는 무시
              }
              debugPrint('ℹ️ 손상된 세션이 삭제되었습니다. 다시 로그인해주세요.');
            } else {
              debugPrint('⚠️ 세션 갱신 실패 (무시 가능): $e');
            }
          }
        } else {
          debugPrint('✅ 웹 세션 복원 완료: ${session.user.email ?? session.user.id}');
        }
      } else {
        debugPrint('ℹ️ 저장된 세션이 없습니다 (로그인 필요)');
      }
    } catch (e) {
      debugPrint('⚠️ 웹 세션 복원 중 에러 (무시 가능): $e');
    }
  }

  // Google Sign-In 초기화 (웹에서는 자동으로 초기화됨)
  // GoogleSignIn.instance는 웹에서 자동으로 초기화됩니다

  // 딥링크 처리 (모바일만)
  if (!kIsWeb) {
    _handleDeepLinks();
  }

  runApp(const ProviderScope(child: MyApp()));
}

// 딥링크 처리 함수
void _handleDeepLinks() {
  final appLinks = AppLinks();

  // 앱이 이미 실행 중일 때 딥링크 처리
  appLinks.uriLinkStream.listen(
    (uri) {
      _processDeepLink(uri);
    },
    onError: (err) {
      debugPrint('딥링크 처리 오류: $err');
    },
  );

  // 앱이 딥링크로 시작될 때 처리
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      _processDeepLink(uri);
    }
  });
}

// 딥링크 처리 로직
void _processDeepLink(Uri uri) async {
  debugPrint('🔗 딥링크 수신: $uri');

  // OAuth 콜백 딥링크 처리
  if (uri.scheme == 'com.smart-grow.smart-review' &&
      uri.host == 'login-callback') {
    final code = uri.queryParameters['code'];
    if (code != null) {
      debugPrint('✅ OAuth 코드 수신: $code');
      // Supabase가 자동으로 딥링크를 처리하도록 함
      // detectSessionInUri: true 설정으로 자동 처리됨
      // 하지만 Supabase가 localhost로 리다이렉트하므로, 여기서 직접 처리
      try {
        final supabase = SupabaseConfig.client;
        final response = await supabase.auth.exchangeCodeForSession(code);
        if (response.session != null) {
          debugPrint('✅ 세션 복원 성공');
        } else {
          debugPrint('⚠️ 세션 복원 실패: 세션이 null');
        }
      } catch (e) {
        debugPrint('❌ 세션 복원 오류: $e');
      }
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CampaignRealtimeManager.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱 레벨에서 생명주기 이벤트 처리 (중앙 관리)
    CampaignRealtimeManager.instance.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Review',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
