import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

part 'auth_provider.g.dart';

// AuthService Provider
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

// 현재 사용자 Provider
@riverpod
Future<app_user.User?> currentUser(Ref ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.currentUser;
}

// 로그인 상태 Provider
@Riverpod(keepAlive: true)
bool isLoggedIn(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, _) => false,
  );
}

// 사용자 타입 Provider
@Riverpod(keepAlive: true)
app_user.UserType? userType(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (user) => user?.userType,
    loading: () => null,
    error: (_, _) => null,
  );
}

// 인증 상태 관리 Notifier
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  late final AuthService _authService;

  @override
  Stream<app_user.User?> build() {
    _authService = ref.watch(authServiceProvider);
    return _authService.authStateChanges;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithGoogle();
      // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signInWithKakao() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithKakao();
      // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithEmail(email, password);
      // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUpWithEmail(email, password, displayName);
      // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _authService.updateUserProfile(updates);
      final currentUser = await _authService.currentUser;
      if (currentUser != null) {
        state = AsyncValue.data(
          await _authService.getUserProfile(currentUser.uid),
        );
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
