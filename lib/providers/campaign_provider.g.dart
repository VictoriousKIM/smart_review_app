// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(campaignService)
const campaignServiceProvider = CampaignServiceProvider._();

final class CampaignServiceProvider
    extends
        $FunctionalProvider<CampaignService, CampaignService, CampaignService>
    with $Provider<CampaignService> {
  const CampaignServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'campaignServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$campaignServiceHash();

  @$internal
  @override
  $ProviderElement<CampaignService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CampaignService create(Ref ref) {
    return campaignService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CampaignService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CampaignService>(value),
    );
  }
}

String _$campaignServiceHash() => r'9ee780caaa31706c34f02e5aa5372b99919c0a4f';

@ProviderFor(popularCampaigns)
const popularCampaignsProvider = PopularCampaignsFamily._();

final class PopularCampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<List<Campaign>>>,
          ApiResponse<List<Campaign>>,
          FutureOr<ApiResponse<List<Campaign>>>
        >
    with
        $FutureModifier<ApiResponse<List<Campaign>>>,
        $FutureProvider<ApiResponse<List<Campaign>>> {
  const PopularCampaignsProvider._({
    required PopularCampaignsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'popularCampaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$popularCampaignsHash();

  @override
  String toString() {
    return r'popularCampaignsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ApiResponse<List<Campaign>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<List<Campaign>>> create(Ref ref) {
    final argument = this.argument as int;
    return popularCampaigns(ref, limit: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PopularCampaignsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$popularCampaignsHash() => r'69d74228d65058992d0907cf2e1555fab7bd1436';

final class PopularCampaignsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ApiResponse<List<Campaign>>>, int> {
  const PopularCampaignsFamily._()
    : super(
        retry: null,
        name: r'popularCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PopularCampaignsProvider call({int limit = 5}) =>
      PopularCampaignsProvider._(argument: limit, from: this);

  @override
  String toString() => r'popularCampaignsProvider';
}

@ProviderFor(newCampaigns)
const newCampaignsProvider = NewCampaignsFamily._();

final class NewCampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<List<Campaign>>>,
          ApiResponse<List<Campaign>>,
          FutureOr<ApiResponse<List<Campaign>>>
        >
    with
        $FutureModifier<ApiResponse<List<Campaign>>>,
        $FutureProvider<ApiResponse<List<Campaign>>> {
  const NewCampaignsProvider._({
    required NewCampaignsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'newCampaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$newCampaignsHash();

  @override
  String toString() {
    return r'newCampaignsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ApiResponse<List<Campaign>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<List<Campaign>>> create(Ref ref) {
    final argument = this.argument as int;
    return newCampaigns(ref, limit: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NewCampaignsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$newCampaignsHash() => r'4ebc4c77e51a555492ebab67859d5faadd967ee5';

final class NewCampaignsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ApiResponse<List<Campaign>>>, int> {
  const NewCampaignsFamily._()
    : super(
        retry: null,
        name: r'newCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NewCampaignsProvider call({int limit = 5}) =>
      NewCampaignsProvider._(argument: limit, from: this);

  @override
  String toString() => r'newCampaignsProvider';
}

@ProviderFor(userCampaigns)
const userCampaignsProvider = UserCampaignsFamily._();

final class UserCampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<List<Campaign>>>,
          ApiResponse<List<Campaign>>,
          FutureOr<ApiResponse<List<Campaign>>>
        >
    with
        $FutureModifier<ApiResponse<List<Campaign>>>,
        $FutureProvider<ApiResponse<List<Campaign>>> {
  const UserCampaignsProvider._({
    required UserCampaignsFamily super.from,
    required ({int page, int limit}) super.argument,
  }) : super(
         retry: null,
         name: r'userCampaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userCampaignsHash();

  @override
  String toString() {
    return r'userCampaignsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ApiResponse<List<Campaign>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<List<Campaign>>> create(Ref ref) {
    final argument = this.argument as ({int page, int limit});
    return userCampaigns(ref, page: argument.page, limit: argument.limit);
  }

  @override
  bool operator ==(Object other) {
    return other is UserCampaignsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userCampaignsHash() => r'7a3efd2a7da54572587b7335b55712712a9a3d7c';

final class UserCampaignsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ApiResponse<List<Campaign>>>,
          ({int page, int limit})
        > {
  const UserCampaignsFamily._()
    : super(
        retry: null,
        name: r'userCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserCampaignsProvider call({required int page, int limit = 10}) =>
      UserCampaignsProvider._(argument: (page: page, limit: limit), from: this);

  @override
  String toString() => r'userCampaignsProvider';
}

@ProviderFor(CampaignNotifier)
const campaignProvider = CampaignNotifierProvider._();

final class CampaignNotifierProvider
    extends $AsyncNotifierProvider<CampaignNotifier, List<Campaign>> {
  const CampaignNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'campaignProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$campaignNotifierHash();

  @$internal
  @override
  CampaignNotifier create() => CampaignNotifier();
}

String _$campaignNotifierHash() => r'394353d1328f81a4e0a595fd33949a9acedc7b5b';

abstract class _$CampaignNotifier extends $AsyncNotifier<List<Campaign>> {
  FutureOr<List<Campaign>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Campaign>>, List<Campaign>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Campaign>>, List<Campaign>>,
              AsyncValue<List<Campaign>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
