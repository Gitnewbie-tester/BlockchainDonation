class DashboardStats {
  final String totalDonatedEth;
  final int charitiesSupported;
  final int impactScore;
  final int totalDonations;
  final String tokenBalance;

  const DashboardStats({
    this.totalDonatedEth = '0.000',
    this.charitiesSupported = 0,
    this.impactScore = 0,
    this.totalDonations = 0,
    this.tokenBalance = '0.00',
  });

  DashboardStats copyWith({
    String? totalDonatedEth,
    int? charitiesSupported,
    int? impactScore,
    int? totalDonations,
    String? tokenBalance,
  }) {
    return DashboardStats(
      totalDonatedEth: totalDonatedEth ?? this.totalDonatedEth,
      charitiesSupported: charitiesSupported ?? this.charitiesSupported,
      impactScore: impactScore ?? this.impactScore,
      totalDonations: totalDonations ?? this.totalDonations,
      tokenBalance: tokenBalance ?? this.tokenBalance,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalDonatedEth: (json['totalDonatedEth'] ?? json['total_donated_eth'] ?? '0.000').toString(),
      charitiesSupported: _toInt(json['charitiesSupported'] ?? json['charities_supported']),
      impactScore: _toInt(json['impactScore'] ?? json['impact_score']),
      totalDonations: _toInt(json['totalDonations'] ?? json['total_donations']),
      tokenBalance: (json['tokenBalance'] ?? json['token_balance'] ?? '0.00').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
