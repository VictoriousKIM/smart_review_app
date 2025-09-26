import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int points;
  final int level;
  final int reviewCount;
  final UserType userType;
  final SNSConnections? snsConnections;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
    this.points = 0,
    this.level = 1,
    this.reviewCount = 0,
    this.userType = UserType.reviewer,
    this.snsConnections,
  });

  factory User.fromSupabaseUser(supabase.User user) {
    final metadata = user.userMetadata ?? {};
    return User(
      uid: user.id,
      email: user.email ?? '',
      displayName: metadata['display_name'] ?? metadata['name'],
      photoURL: metadata['photo_url'] ?? metadata['avatar_url'],
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
      userType: UserType.values.firstWhere(
        (e) => e.name == metadata['user_type'],
        orElse: () => UserType.reviewer,
      ),
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
      photoURL:
          profileData['photo_url'] ?? supabaseUser.userMetadata?['avatar_url'],
      createdAt: DateTime.parse(profileData['created_at']),
      updatedAt: DateTime.parse(profileData['updated_at']),
      points: profileData['points'] ?? 0,
      level: profileData['level'] ?? 1,
      reviewCount: profileData['review_count'] ?? 0,
      userType: UserType.values.firstWhere(
        (e) => e.name == profileData['user_type'],
        orElse: () => UserType.reviewer,
      ),
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
      photoURL: json['photo_url'] ?? json['photoURL'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
      points: json['points'] ?? 0,
      level: json['level'] ?? 1,
      reviewCount: json['review_count'] ?? json['reviewCount'] ?? 0,
      userType: UserType.values.firstWhere(
        (e) => e.name == (json['user_type'] ?? json['userType']),
        orElse: () => UserType.reviewer,
      ),
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
      'photo_url': photoURL,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'points': points,
      'level': level,
      'review_count': reviewCount,
      'user_type': userType.name,
      'sns_connections': snsConnections?.toJson(),
    };
  }

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? points,
    int? level,
    int? reviewCount,
    UserType? userType,
    SNSConnections? snsConnections,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      points: points ?? this.points,
      level: level ?? this.level,
      reviewCount: reviewCount ?? this.reviewCount,
      userType: userType ?? this.userType,
      snsConnections: snsConnections ?? this.snsConnections,
    );
  }
}

enum UserType { advertiser, reviewer }

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
