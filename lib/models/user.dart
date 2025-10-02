import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class User {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int points;
  final int level;
  final int reviewCount;
  final UserType userType;
  final bool isAdvertiserVerified;
  final String? companyId;
  final CompanyRole? companyRole;
  final SNSConnections? snsConnections;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.points = 0,
    this.level = 1,
    this.reviewCount = 0,
    this.userType = UserType.user,
    this.isAdvertiserVerified = false,
    this.companyId,
    this.companyRole,
    this.snsConnections,
  });

  factory User.fromSupabaseUser(supabase.User user) {
    final metadata = user.userMetadata ?? {};
    return User(
      uid: user.id,
      email: user.email ?? '',
      displayName: metadata['display_name'] ?? metadata['name'],
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
      userType: UserType.values.firstWhere(
        (e) => e.name == metadata['user_type'],
        orElse: () => UserType.user,
      ),
      isAdvertiserVerified: metadata['is_advertiser_verified'] ?? false,
      companyId: metadata['company_id'],
      companyRole: metadata['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == metadata['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      // 아래 필드들은 Supabase User 객체에 없으므로 기본값 또는 별도 로직 필요
      points: 0,
      level: 1,
      reviewCount: 0,
      snsConnections: null,
    );
  }

  // 데이터베이스에서 가져온 프로필 정보로 User 객체 생성
  factory User.fromDatabaseProfile(
    Map<String, dynamic> profileData,
    supabase.User supabaseUser,
  ) {
    return User(
      uid: supabaseUser.id,
      email: supabaseUser.email ?? '',
      displayName: profileData['display_name'],
      createdAt: DateTime.parse(profileData['created_at']),
      updatedAt: DateTime.parse(profileData['updated_at']),
      points: profileData['points'] ?? 0,
      level: profileData['level'] ?? 1,
      reviewCount: profileData['review_count'] ?? 0,
      userType: UserType.values.firstWhere(
        (e) => e.name == profileData['user_type'],
        orElse: () => UserType.user,
      ),
      isAdvertiserVerified: profileData['is_advertiser_verified'] ?? false,
      companyId: profileData['company_id'],
      companyRole: profileData['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == profileData['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      snsConnections: profileData['sns_connections'] != null
          ? SNSConnections.fromJson(profileData['sns_connections'])
          : null,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['displayName'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
      points: json['points'] ?? 0,
      level: json['level'] ?? 1,
      reviewCount: json['review_count'] ?? json['reviewCount'] ?? 0,
      userType: UserType.values.firstWhere(
        (e) => e.name == (json['user_type'] ?? json['userType']),
        orElse: () => UserType.user,
      ),
      isAdvertiserVerified: json['is_advertiser_verified'] ?? false,
      companyId: json['company_id'],
      companyRole: json['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == json['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      snsConnections: json['sns_connections'] != null
          ? SNSConnections.fromJson(json['sns_connections'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'points': points,
      'level': level,
      'review_count': reviewCount,
      'user_type': userType.name,
      'is_advertiser_verified': isAdvertiserVerified,
      'company_id': companyId,
      'company_role': companyRole?.name,
      'sns_connections': snsConnections?.toJson(),
    };
  }

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? points,
    int? level,
    int? reviewCount,
    UserType? userType,
    bool? isAdvertiserVerified,
    String? companyId,
    CompanyRole? companyRole,
    SNSConnections? snsConnections,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      points: points ?? this.points,
      level: level ?? this.level,
      reviewCount: reviewCount ?? this.reviewCount,
      userType: userType ?? this.userType,
      isAdvertiserVerified: isAdvertiserVerified ?? this.isAdvertiserVerified,
      companyId: companyId ?? this.companyId,
      companyRole: companyRole ?? this.companyRole,
      snsConnections: snsConnections ?? this.snsConnections,
    );
  }
}

enum UserType {
  user, // 일반 사용자 (리뷰어)
  admin, // 관리자
}

enum CompanyRole {
  owner, // 회사 소유자
  manager, // 회사 관리자
}

class SNSConnections {
  final SNSConnection? google;
  final SNSConnection? instagram;
  final SNSConnection? youtube;
  final SNSConnection? naver;
  final SNSConnection? blog;

  SNSConnections({
    this.google,
    this.instagram,
    this.youtube,
    this.naver,
    this.blog,
  });

  factory SNSConnections.fromJson(Map<String, dynamic> json) {
    return SNSConnections(
      google: json['google'] != null
          ? SNSConnection.fromJson(json['google'])
          : null,
      instagram: json['instagram'] != null
          ? SNSConnection.fromJson(json['instagram'])
          : null,
      youtube: json['youtube'] != null
          ? SNSConnection.fromJson(json['youtube'])
          : null,
      naver: json['naver'] != null
          ? SNSConnection.fromJson(json['naver'])
          : null,
      blog: json['blog'] != null ? SNSConnection.fromJson(json['blog']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'google': google?.toJson(),
      'instagram': instagram?.toJson(),
      'youtube': youtube?.toJson(),
      'naver': naver?.toJson(),
      'blog': blog?.toJson(),
    };
  }
}

class SNSConnection {
  final String url;
  final String username;
  final bool connected;
  final DateTime createdAt;
  final DateTime updatedAt;

  SNSConnection({
    required this.url,
    required this.username,
    required this.connected,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SNSConnection.fromJson(Map<String, dynamic> json) {
    return SNSConnection(
      url: json['url'] ?? '',
      username: json['username'] ?? '',
      connected: json['connected'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
      'connected': connected,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
