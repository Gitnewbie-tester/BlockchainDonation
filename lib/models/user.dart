class User {
  final String fullName;
  final String email;
  final String joinDate;
  final int? age;
  final String? phone;

  User({
    required this.fullName,
    required this.email,
    required this.joinDate,
    this.age,
    this.phone,
  });

  User copyWith({
    String? fullName,
    String? email,
    String? joinDate,
    int? age,
    String? phone,
  }) {
    return User(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      joinDate: joinDate ?? this.joinDate,
      age: age ?? this.age,
      phone: phone ?? this.phone,
    );
  }

  factory User.fromBackend(Map<String, dynamic> json) {
    final createdAt = json['created_at']?.toString();
    return User(
      fullName: (json['name'] ?? 'CharityChain Donor').toString(),
      email: (json['email'] ?? 'unknown@example.com').toString(),
      joinDate: _formatJoinDate(createdAt),
      phone: json['phone']?.toString(),
    );
  }

  static String _formatJoinDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return '2024';
    }
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) {
      return '2024';
    }
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = monthNames[parsed.month - 1];
    return '$month ${parsed.year}';
  }
}
