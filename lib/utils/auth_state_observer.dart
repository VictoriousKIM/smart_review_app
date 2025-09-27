import 'dart:async'; // StreamSubscription을 위해 import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase를 직접 사용

/// Supabase 인증 이벤트를 직접 구독하여 URL을 정리하는 위젯
///
/// 이 위젯은 Riverpod 상태 대신 Supabase의 onAuthStateChange 스트림을 직접 구독합니다.
/// `signedIn` 또는 `initialSession` 이벤트가 발생한 직후,
/// 즉 Supabase가 URL의 쿼리 파라미터를 사용해 세션을 설정한 바로 그 시점에
/// URL 정리 로직을 실행하여 경합 문제를 근본적으로 해결합니다.
class AuthStateObserver extends StatefulWidget {
  final Widget child;

  const AuthStateObserver({super.key, required this.child});

  @override
  State<AuthStateObserver> createState() => _AuthStateObserverState();
}

class _AuthStateObserverState extends State<AuthStateObserver> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // 위젯이 생성될 때 Supabase 인증 스트림 구독 시작
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;

        // 로그인 이벤트 또는 앱 재시작 시 세션 복구 이벤트가 발생했을 때
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.initialSession) {
          // 현재 라우트 정보를 가져와서 URL 정리 로직 실행
          // 여기서 context를 직접 사용하는 대신, GoRouter의 상태를 참조하여 처리
          // build context가 아직 준비되지 않았을 수 있으므로 약간의 지연을 줌
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _cleanUrlIfNecessary(context);
            }
          });
        }
      },
      onError: (error) {
        debugPrint('AuthStateObserver onAuthStateChange error: $error');
      },
    );
  }

  @override
  void dispose() {
    // 위젯이 파괴될 때 스트림 구독을 반드시 취소하여 메모리 누수 방지
    _authSubscription?.cancel();
    super.dispose();
  }

  void _cleanUrlIfNecessary(BuildContext context) {
    try {
      // GoRouter가 활성화되어 있고, 위젯이 여전히 트리에 있는지 확인
      if (!context.mounted) return;

      final GoRouter router = GoRouter.of(context);
      // 현재 라우팅 정보를 가져오는 더 안정적인 방법
      final String location = router.routeInformationProvider.value.uri
          .toString();
      final Uri uri = Uri.parse(location);

      final hasAuthParams =
          uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('error') ||
          uri.queryParameters.containsKey('access_token') || // 다른 OAuth 제공자도 고려
          uri.queryParameters.containsKey('refresh_token');

      if (hasAuthParams) {
        // addPostFrameCallback을 사용하여 현재 빌드/레이아웃 주기가 끝난 후 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 현재 경로(# 뒤의 부분)는 유지한 채 쿼리 파라미터만 제거하여 URL 교체
            // 예를 들어 /?code=...#/home -> /#/home 으로 변경
            final cleanPath = uri.path;
            context.replace(cleanPath);
            debugPrint('URL cleaned: from "$location" to "$cleanPath"');
          }
        });
      }
    } catch (e) {
      debugPrint('Error while cleaning URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 자식 위젯은 그대로 렌더링
    return widget.child;
  }
}
