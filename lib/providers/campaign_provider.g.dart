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

@ProviderFor(campaigns)
const campaignsProvider = CampaignsFamily._();

final class CampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<List<Campaign>>>,
          ApiResponse<List<Campaign>>,
          FutureOr<ApiResponse<List<Campaign>>>
        >
    with
        $FutureModifier<ApiResponse<List<Campaign>>>,
        $FutureProvider<ApiResponse<List<Campaign>>> {
  const CampaignsProvider._({
    required CampaignsFamily super.from,
    required ({
      int page,
      int limit,
      String? category,
      String? type,
      String sortBy,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'campaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$campaignsHash();

  @override
  String toString() {
    return r'campaignsProvider'
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
    final argument =
        this.argument
            as ({
              int page,
              int limit,
              String? category,
              String? type,
              String sortBy,
            });
    return campaigns(
      ref,
      page: argument.page,
      limit: argument.limit,
      category: argument.category,
      type: argument.type,
      sortBy: argument.sortBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CampaignsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$campaignsHash() => r'e7921e46f68061540f25bc58e23bdba3a21e0a56';

final class CampaignsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ApiResponse<List<Campaign>>>,
          ({int page, int limit, String? category, String? type, String sortBy})
        > {
  const CampaignsFamily._()
    : super(
        retry: null,
        name: r'campaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CampaignsProvider call({
    required int page,
    int limit = 10,
    String? category,
    String? type,
    String sortBy = 'latest',
  }) => CampaignsProvider._(
    argument: (
      page: page,
      limit: limit,
      category: category,
      type: type,
      sortBy: sortBy,
    ),
    from: this,
  );

  @override
  String toString() => r'campaignsProvider';
}

@ProviderFor(campaignDetail)
const campaignDetailProvider = CampaignDetailFamily._();

final class CampaignDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<Campaign>>,
          ApiResponse<Campaign>,
          FutureOr<ApiResponse<Campaign>>
        >
    with
        $FutureModifier<ApiResponse<Campaign>>,
        $FutureProvider<ApiResponse<Campaign>> {
  const CampaignDetailProvider._({
    required CampaignDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'campaignDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$campaignDetailHash();

  @override
  String toString() {
    return r'campaignDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ApiResponse<Campaign>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<Campaign>> create(Ref ref) {
    final argument = this.argument as String;
    return campaignDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CampaignDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$campaignDetailHash() => r'3e7903cfdfb4a52f1aef9c74b9674c70991f100f';

final class CampaignDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ApiResponse<Campaign>>, String> {
  const CampaignDetailFamily._()
    : super(
        retry: null,
        name: r'campaignDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CampaignDetailProvider call(String campaignId) =>
      CampaignDetailProvider._(argument: campaignId, from: this);

  @override
  String toString() => r'campaignDetailProvider';
}

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

String _$popularCampaignsHash() => r'43899473fce278b6fb3aa473df9ec4b5a7f11e2c';

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

  PopularCampaignsProvider call({required int limit}) =>
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

String _$newCampaignsHash() => r'11a5674f8822e6fd4a4c65e3fbaea364d66bee35';

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

  NewCampaignsProvider call({required int limit}) =>
      NewCampaignsProvider._(argument: limit, from: this);

  @override
  String toString() => r'newCampaignsProvider';
}

@ProviderFor(searchCampaigns)
const searchCampaignsProvider = SearchCampaignsFamily._();

final class SearchCampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<List<Campaign>>>,
          ApiResponse<List<Campaign>>,
          FutureOr<ApiResponse<List<Campaign>>>
        >
    with
        $FutureModifier<ApiResponse<List<Campaign>>>,
        $FutureProvider<ApiResponse<List<Campaign>>> {
  const SearchCampaignsProvider._({
    required SearchCampaignsFamily super.from,
    required ({String query, String? category, int page, int limit})
    super.argument,
  }) : super(
         retry: null,
         name: r'searchCampaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchCampaignsHash();

  @override
  String toString() {
    return r'searchCampaignsProvider'
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
    final argument =
        this.argument
            as ({String query, String? category, int page, int limit});
    return searchCampaigns(
      ref,
      query: argument.query,
      category: argument.category,
      page: argument.page,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchCampaignsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchCampaignsHash() => r'982a6cdff229d37d2c66d828a921bcdaa068f942';

final class SearchCampaignsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ApiResponse<List<Campaign>>>,
          ({String query, String? category, int page, int limit})
        > {
  const SearchCampaignsFamily._()
    : super(
        retry: null,
        name: r'searchCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SearchCampaignsProvider call({
    required String query,
    String? category,
    int page = 1,
    int limit = 10,
  }) => SearchCampaignsProvider._(
    argument: (query: query, category: category, page: page, limit: limit),
    from: this,
  );

  @override
  String toString() => r'searchCampaignsProvider';
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
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$campaignNotifierHash();

  @$internal
  @override
  CampaignNotifier create() => CampaignNotifier();
}

String _$campaignNotifierHash() => r'9a1b024118e2aeb9d82f8d4a29f9f3b95bab6f79';

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

@ProviderFor(SearchNotifier)
const searchProvider = SearchNotifierProvider._();

final class SearchNotifierProvider
    extends $AsyncNotifierProvider<SearchNotifier, List<Campaign>> {
  const SearchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchNotifierHash();

  @$internal
  @override
  SearchNotifier create() => SearchNotifier();
}

String _$searchNotifierHash() => r'102cef11af35532d0f6436f048bea16d6d0bd447';

abstract class _$SearchNotifier extends $AsyncNotifier<List<Campaign>> {
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
