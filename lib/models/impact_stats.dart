class ImpactStats {
  final double impactScore;
  final double totalDonated;
  final int referralCount;
  final double rewardBalance;
  final String? referralCode;
  final String? referredBy;

  ImpactStats({
    required this.impactScore,
    required this.totalDonated,
    required this.referralCount,
    required this.rewardBalance,
    this.referralCode,
    this.referredBy,
  });

  factory ImpactStats.fromJson(Map<String, dynamic> json) {
    return ImpactStats(
      impactScore: _parseDouble(json['impactScore']),
      totalDonated: _parseDouble(json['totalDonated']),
      referralCount: _parseInt(json['referralCount']),
      rewardBalance: _parseDouble(json['rewardBalance']),
      referralCode: json['referralCode'],
      referredBy: json['referredBy'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'impactScore': impactScore,
      'totalDonated': totalDonated,
      'referralCount': referralCount,
      'rewardBalance': rewardBalance,
      'referralCode': referralCode,
      'referredBy': referredBy,
    };
  }

  @override
  String toString() {
    return 'ImpactStats(score: $impactScore, donated: $totalDonated ETH, '
        'referrals: $referralCount, rewards: $rewardBalance CIC)';
  }
}

class RewardHistory {
  final int id;
  final String userAddress;
  final double tokenAmount;
  final String reason;
  final String? txHash;
  final DateTime createdAt;

  RewardHistory({
    required this.id,
    required this.userAddress,
    required this.tokenAmount,
    required this.reason,
    this.txHash,
    required this.createdAt,
  });

  factory RewardHistory.fromJson(Map<String, dynamic> json) {
    return RewardHistory(
      id: json['id'],
      userAddress: json['user_address'],
      tokenAmount: _parseDouble(json['token_amount']),
      reason: json['reason'] ?? '',
      txHash: json['tx_hash'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class ReferralDetail {
  final String refereeAddress;
  final String refereeEmail;
  final String refereeName;
  final double totalDonated;
  final DateTime referredAt;
  final int donationCount;

  ReferralDetail({
    required this.refereeAddress,
    required this.refereeEmail,
    required this.refereeName,
    required this.totalDonated,
    required this.referredAt,
    required this.donationCount,
  });

  factory ReferralDetail.fromJson(Map<String, dynamic> json) {
    return ReferralDetail(
      refereeAddress: json['referee_address'] ?? '',
      refereeEmail: json['referee_email'] ?? '',
      refereeName: json['referee_name'] ?? 'Unknown',
      totalDonated: _parseDouble(json['total_donated_eth']),
      referredAt: DateTime.parse(json['referred_at']),
      donationCount: _parseInt(json['donation_count']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  String get displayName {
    if (refereeName.isNotEmpty && refereeName != 'Unknown') {
      return refereeName;
    }
    return '${refereeAddress.substring(0, 6)}...${refereeAddress.substring(refereeAddress.length - 4)}';
  }
}
