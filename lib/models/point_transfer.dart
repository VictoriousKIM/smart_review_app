/// 포인트 이동 거래 모델 (point_transfers 테이블)
class PointTransfer {
  final String id;
  final String fromWalletId;
  final String toWalletId;
  final int amount;
  final String? description;
  final String? createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 관련 지갑 정보 (조회 시 포함)
  final WalletInfo? fromWallet;
  final WalletInfo? toWallet;

  PointTransfer({
    required this.id,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    this.description,
    this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.fromWallet,
    this.toWallet,
  });

  factory PointTransfer.fromJson(Map<String, dynamic> json) {
    return PointTransfer(
      id: json['id'] as String,
      fromWalletId: json['from_wallet_id'] as String,
      toWalletId: json['to_wallet_id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      fromWallet: json['from_wallet'] != null
          ? WalletInfo.fromJson(json['from_wallet'] as Map<String, dynamic>)
          : null,
      toWallet: json['to_wallet'] != null
          ? WalletInfo.fromJson(json['to_wallet'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'description': description,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'from_wallet': fromWallet?.toJson(),
      'to_wallet': toWallet?.toJson(),
    };
  }
}

/// 지갑 정보 (포인트 이동 조회 시 포함)
class WalletInfo {
  final String id;
  final String? userId;
  final String? companyId;
  final int currentPoints;

  WalletInfo({
    required this.id,
    this.userId,
    this.companyId,
    required this.currentPoints,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      companyId: json['company_id'] as String?,
      currentPoints: json['current_points'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'current_points': currentPoints,
    };
  }
}

