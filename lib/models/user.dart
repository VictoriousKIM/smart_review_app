import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// users 테이블 모델 (Supabase 스키마 기반)
/// 
/// DB 스키마:
/// - id: uuid (PK)
/// - created_at: timestamp
/// - updated_at: timestamp (nullable)
/// - display_name: text (nullable)
/// - user_type: text (default: 'user')
/// - status: text (default: 'active')
/// 
/// 참고: email은 auth.users에서 가져옴
/// companyId, companyRole은 company_users 테이블에서 JOIN 필요
/// snsConnections는 sns_connections 테이블에서 JOIN 필요
/// level, reviewCount는 DB에 없음 (계산 필드 또는 별도 테이블 필요)
class User {
  final String uid;
  final String email; // auth.users에서 가져옴
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? level; // DB에 없음 - nullable로 변경
  final int? reviewCount; // DB에 없음 - nullable로 변경
  final UserType userType;
  final String? companyId; // company_users 테이블에서 JOIN 필요
  final CompanyRole? companyRole; // company_users 테이블에서 JOIN 필요
  final SNSConnections? snsConnections; // sns_connections 테이블에서 JOIN 필요
  final String? status;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.level,
    this.reviewCount,
    this.userType = UserType.user,
    this.companyId,
    this.companyRole,
    this.snsConnections,
    this.status,
  });

  // company_users 테이블을 통해 회사 정보 확인
  Future<bool> get isAdvertiserVerified async {
    // 이 메서드는 비동기이므로 실제 사용 시에는 서비스에서 처리해야 함
    return companyId != null;
  }

  factory User.fromSupabaseUser(supabase.User user) {
    final metadata = user.userMetadata ?? {};
    return User(
      uid: user.id,
      email: user.email ?? '',
      displayName: metadata['display_name'] ?? metadata['name'],
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
      userType: UserType.values.firstWhere(
        (e) => e.name == metadata['user_type']?.toLowerCase(),
        orElse: () => UserType.user,
      ),
      companyId: metadata['company_id'],
      companyRole: metadata['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == metadata['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      // 아래 필드들은 DB에 없으므로 null
      level: null,
      reviewCount: null,
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
      level: profileData['level'],
      reviewCount: profileData['review_count'],
      userType: UserType.values.firstWhere(
        (e) => e.name == (profileData['user_type'] as String?)?.toLowerCase(),
        orElse: () => UserType.user,
      ),
      companyId: profileData['company_id'],
      companyRole: profileData['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == profileData['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      snsConnections: profileData['sns_connections'] != null
          ? (profileData['sns_connections'] is List
              ? SNSConnections.fromJson(profileData['sns_connections'] as List)
              : profileData['sns_connections'] is Map
                  ? SNSConnections.fromList([profileData['sns_connections'] as Map<String, dynamic>])
                  : null)
          : null,
      status: profileData['status'],
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['displayName'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
      level: json['level'],
      reviewCount: json['review_count'] ?? json['reviewCount'],
      userType: UserType.values.firstWhere(
        (e) => e.name == ((json['user_type'] ?? json['userType']) as String?)?.toLowerCase(),
        orElse: () => UserType.user,
      ),
      companyId: json['company_id'],
      companyRole: json['company_role'] != null
          ? CompanyRole.values.firstWhere(
              (e) => e.name == json['company_role'],
              orElse: () => CompanyRole.manager,
            )
          : null,
      snsConnections: json['sns_connections'] != null
          ? (json['sns_connections'] is List
              ? SNSConnections.fromJson(json['sns_connections'] as List)
              : SNSConnections.fromList([json['sns_connections'] as Map<String, dynamic>]))
          : null,
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'level': level,
      'review_count': reviewCount,
      'user_type': userType.name.toLowerCase(),
      'company_id': companyId,
      'company_role': companyRole?.name,
      'sns_connections': snsConnections?.toJson(),
      'status': status,
    };
  }

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? level,
    int? reviewCount,
    UserType? userType,
    String? companyId,
    CompanyRole? companyRole,
    SNSConnections? snsConnections,
    String? status,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      level: level ?? this.level,
      reviewCount: reviewCount ?? this.reviewCount,
      userType: userType ?? this.userType,
      companyId: companyId ?? this.companyId,
      companyRole: companyRole ?? this.companyRole,
      snsConnections: snsConnections ?? this.snsConnections,
      status: status ?? this.status,
    );
  }
}

enum UserType {
  user, // 일반 사용자 (리뷰어 또는 광고주, company_users로 구분)
  admin, // 시스템 관리자 (전역 권한)
}

enum CompanyRole {
  owner, // 회사 소유자 (광고주)
  manager, // 회사 관리자 (광고주)
  reviewer, // 리뷰어 (회사에 속한 리뷰어)
}

/// sns_connections 테이블의 리스트를 플랫폼별로 그룹화한 모델
/// 
/// 주의: 이 모델은 sns_connections 테이블의 여러 레코드를 플랫폼별로 그룹화한 것입니다.
/// 실제 DB에는 각 플랫폼별로 별도의 레코드가 존재합니다.
class SNSConnections {
  final List<SNSConnection> connections;

  SNSConnections({
    required this.connections,
  });

  // 플랫폼별로 필터링된 getter들
  SNSConnection? get google => _getByPlatform('google');
  SNSConnection? get instagram => _getByPlatform('instagram');
  SNSConnection? get youtube => _getByPlatform('youtube');
  SNSConnection? get naver => _getByPlatform('naver');
  SNSConnection? get blog => _getByPlatform('blog');

  SNSConnection? _getByPlatform(String platform) {
    try {
      return connections.firstWhere(
        (conn) => conn.platform.toLowerCase() == platform.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  factory SNSConnections.fromJson(List<dynamic> json) {
    return SNSConnections(
      connections: json
          .map((item) => SNSConnection.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  factory SNSConnections.fromList(List<Map<String, dynamic>> json) {
    return SNSConnections(
      connections: json.map((item) => SNSConnection.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connections': connections.map((conn) => conn.toJson()).toList(),
    };
  }
}

/// sns_connections 테이블 모델 (Supabase 스키마 기반)
/// 
/// DB 스키마:
/// - id: uuid
/// - user_id: uuid
/// - platform: text (예: 'coupang', 'smartstore', 'blog', 'instagram' 등)
/// - platform_account_id: text
/// - platform_account_name: text
/// - phone: text
/// - address: text (nullable, 스토어 플랫폼만 필수)
/// - return_address: text (nullable)
/// - created_at: timestamp
/// - updated_at: timestamp
class SNSConnection {
  final String id;
  final String userId;
  final String platform;
  final String platformAccountId;
  final String platformAccountName;
  final String phone;
  final String? address;
  final String? returnAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  SNSConnection({
    required this.id,
    required this.userId,
    required this.platform,
    required this.platformAccountId,
    required this.platformAccountName,
    required this.phone,
    this.address,
    this.returnAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SNSConnection.fromJson(Map<String, dynamic> json) {
    return SNSConnection(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      platform: json['platform'] ?? '',
      platformAccountId: json['platform_account_id'] ?? '',
      platformAccountName: json['platform_account_name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      returnAddress: json['return_address'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'platform': platform,
      'platform_account_id': platformAccountId,
      'platform_account_name': platformAccountName,
      'phone': phone,
      'address': address,
      'return_address': returnAddress,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 하위 호환성을 위한 getter들
  String get url => ''; // DB에 없음
  String get username => platformAccountName;
  bool get connected => true; // DB에 없음, 항상 true로 가정
}
