// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  const AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'21d842d4dceafa3d239c0196a0f2b890d37c0b71';

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends
        $FunctionalProvider<
          AsyncValue<app_user.User?>,
          app_user.User?,
          Stream<app_user.User?>
        >
    with $FutureModifier<app_user.User?>, $StreamProvider<app_user.User?> {
  const CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $StreamProviderElement<app_user.User?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<app_user.User?> create(Ref ref) {
    return currentUser(ref);
  }
}

String _$currentUserHash() => r'a415615e8937881062916eca7bd9f04f7f3ca0fb';

@ProviderFor(isLoggedIn)
const isLoggedInProvider = IsLoggedInProvider._();

final class IsLoggedInProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsLoggedInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isLoggedInProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isLoggedInHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isLoggedIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isLoggedInHash() => r'ac56433d3e69133cf4a55dcec563ef0403ba2147';

@ProviderFor(userType)
const userTypeProvider = UserTypeProvider._();

final class UserTypeProvider
    extends
        $FunctionalProvider<
          app_user.UserType?,
          app_user.UserType?,
          app_user.UserType?
        >
    with $Provider<app_user.UserType?> {
  const UserTypeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userTypeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userTypeHash();

  @$internal
  @override
  $ProviderElement<app_user.UserType?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  app_user.UserType? create(Ref ref) {
    return userType(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(app_user.UserType? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<app_user.UserType?>(value),
    );
  }
}

String _$userTypeHash() => r'99d2f87d4e0a53f9a3499b3233ee2c89db063701';

@ProviderFor(AuthNotifier)
const authProvider = AuthNotifierProvider._();

final class AuthNotifierProvider
    extends $StreamNotifierProvider<AuthNotifier, app_user.User?> {
  const AuthNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authNotifierHash();

  @$internal
  @override
  AuthNotifier create() => AuthNotifier();
}

String _$authNotifierHash() => r'e0660a0ffa2d4ce29e3cdd5463c1a4b797ddcd9e';

abstract class _$AuthNotifier extends $StreamNotifier<app_user.User?> {
  Stream<app_user.User?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<app_user.User?>, app_user.User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<app_user.User?>, app_user.User?>,
              AsyncValue<app_user.User?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
