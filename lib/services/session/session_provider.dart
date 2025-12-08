import 'session_info.dart';

/// 세션 제공자 인터페이스
/// 다양한 세션 타입(Supabase, Custom JWT 등)을 통일된 방식으로 처리하기 위한 추상화
abstract class SessionProvider {
  /// 현재 활성 세션을 가져옵니다
  /// 세션이 없으면 null을 반환합니다
  Future<SessionInfo?> getSession();

  /// 세션이 존재하는지 확인합니다 (비동기)
  Future<bool> hasSession();

  /// 세션이 존재하는지 확인합니다 (동기)
  /// 가능한 경우에만 사용 (SharedPreferences 등)
  bool hasSessionSync();

  /// 세션을 삭제합니다
  Future<void> clearSession();

  /// 세션 제공자 이름 (디버깅용)
  String get providerName;
}

