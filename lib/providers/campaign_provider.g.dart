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

String _$campaignsHash() => r'd412c5e2f07dc5bf12d77d18520fa9c24753adb2';

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

String _$searchCampaignsHash() => r'85fec12a36ddcc2e332e1ad05559364b5f37d3f1';

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
          AsyncValue<ApiResponse<Map<String, dynamic>>>,
          ApiResponse<Map<String, dynamic>>,
          FutureOr<ApiResponse<Map<String, dynamic>>>
        >
    with
        $FutureModifier<ApiResponse<Map<String, dynamic>>>,
        $FutureProvider<ApiResponse<Map<String, dynamic>>> {
  const UserCampaignsProvider._({
    required UserCampaignsFamily super.from,
    required ({int page, int limit, String? status}) super.argument,
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
  $FutureProviderElement<ApiResponse<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as ({int page, int limit, String? status});
    return userCampaigns(
      ref,
      page: argument.page,
      limit: argument.limit,
      status: argument.status,
    );
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

String _$userCampaignsHash() => r'5741e94f5e2cf9a2301ec317c94e30d587b393b2';

final class UserCampaignsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ApiResponse<Map<String, dynamic>>>,
          ({int page, int limit, String? status})
        > {
  const UserCampaignsFamily._()
    : super(
        retry: null,
        name: r'userCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserCampaignsProvider call({
    required int page,
    int limit = 10,
    String? status,
  }) => UserCampaignsProvider._(
    argument: (page: page, limit: limit, status: status),
    from: this,
  );

  @override
  String toString() => r'userCampaignsProvider';
}

@ProviderFor(userParticipatedCampaigns)
const userParticipatedCampaignsProvider = UserParticipatedCampaignsFamily._();

final class UserParticipatedCampaignsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ApiResponse<Map<String, dynamic>>>,
          ApiResponse<Map<String, dynamic>>,
          FutureOr<ApiResponse<Map<String, dynamic>>>
        >
    with
        $FutureModifier<ApiResponse<Map<String, dynamic>>>,
        $FutureProvider<ApiResponse<Map<String, dynamic>>> {
  const UserParticipatedCampaignsProvider._({
    required UserParticipatedCampaignsFamily super.from,
    required ({int page, int limit, String? status}) super.argument,
  }) : super(
         retry: null,
         name: r'userParticipatedCampaignsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userParticipatedCampaignsHash();

  @override
  String toString() {
    return r'userParticipatedCampaignsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ApiResponse<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ApiResponse<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as ({int page, int limit, String? status});
    return userParticipatedCampaigns(
      ref,
      page: argument.page,
      limit: argument.limit,
      status: argument.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserParticipatedCampaignsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userParticipatedCampaignsHash() =>
    r'd49e42da3049c2e7c6308a33489eeae4d8246e39';

final class UserParticipatedCampaignsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ApiResponse<Map<String, dynamic>>>,
          ({int page, int limit, String? status})
        > {
  const UserParticipatedCampaignsFamily._()
    : super(
        retry: null,
        name: r'userParticipatedCampaignsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserParticipatedCampaignsProvider call({
    required int page,
    int limit = 10,
    String? status,
  }) => UserParticipatedCampaignsProvider._(
    argument: (page: page, limit: limit, status: status),
    from: this,
  );

  @override
  String toString() => r'userParticipatedCampaignsProvider';
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

String _$campaignNotifierHash() => r'825d54fa01fb072b3c85b10f1eeae3af147ae923';

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

String _$searchNotifierHash() => r'17e62a7d6ac3cff3a11099ba8b510f52d704847f';

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
