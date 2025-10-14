import 'dart:async'; // StreamSubscription을 위해 import
import 'package:flutter/material.dart';
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

    // URL 정리 기능을 임시로 비활성화
    // GoRouter 초기화 타이밍 문제로 인해 비활성화
    // 향후 필요시 URL 정리 로직을 다시 구현할 예정

    // _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
    //   (data) {
    //     final event = data.event;
  }

  @override
  void dispose() {
    // 위젯이 파괴될 때 스트림 구독을 반드시 취소하여 메모리 누수 방지
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 자식 위젯은 그대로 렌더링
    return widget.child;
  }
}
