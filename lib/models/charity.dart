class Charity {
  static const _fallbackImage =
      'https://images.unsplash.com/photo-1455849318743-b2233052fcff?auto=format&fit=crop&w=1200&q=80';

  final String id;
  final String title;
  final String description;
  final String image;
  final double raised;
  final double goal;
  final int backers;
  final String category;
  final bool verified;
  final String ownerAddress;
  final String beneficiaryAddress;

  Charity({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.raised,
    required this.goal,
    required this.backers,
    required this.category,
    required this.verified,
    required this.ownerAddress,
    required this.beneficiaryAddress,
  });

  factory Charity.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final dynamic rawTitle =
        json['title'] ?? json['name'] ?? 'Untitled Campaign';
    final dynamic rawImage =
        json['imageUrl'] ?? json['image'] ?? _fallbackImage;
    final title = rawTitle?.toString() ?? 'Untitled Campaign';
    final imageUrl = rawImage?.toString() ?? _fallbackImage;

    return Charity(
      id: json['id']?.toString() ?? '',
      title: title,
      description: (json['description'] ?? '') as String,
      image: imageUrl.isEmpty ? _fallbackImage : imageUrl,
      raised: parseDouble(json['raisedEth'] ?? json['raised']),
      goal: parseDouble(json['goalEth'] ?? json['goal']),
      backers: parseInt(json['backers'] ?? json['supporters']),
      category: (json['category'] ?? 'General') as String,
      verified: json['verified'] == true,
      ownerAddress: (json['ownerAddress'] ?? '') as String,
      beneficiaryAddress: (json['beneficiaryAddress'] ?? '') as String,
    );
  }

  double get progress {
    if (goal <= 0) return 0;
    final ratio = (raised / goal) * 100;
    return ratio.clamp(0, 100).toDouble();
  }
}
