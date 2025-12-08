/// 세션 정보를 담는 모델
class SessionInfo {
  final String userId;
  final String? email;
  final String? provider;
  final Map<String, dynamic>? userMetadata;
  final DateTime? expiresAt;

  SessionInfo({
    required this.userId,
    this.email,
    this.provider,
    this.userMetadata,
    this.expiresAt,
  });

  /// 세션이 만료되었는지 확인
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 세션 정보를 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'provider': provider,
      'userMetadata': userMetadata,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  /// Map에서 SessionInfo 생성
  factory SessionInfo.fromMap(Map<String, dynamic> map) {
    return SessionInfo(
      userId: map['userId'] as String,
      email: map['email'] as String?,
      provider: map['provider'] as String?,
      userMetadata: map['userMetadata'] as Map<String, dynamic>?,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
    );
  }
}

