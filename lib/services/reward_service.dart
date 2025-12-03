import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/impact_stats.dart';

class RewardService {
  // Use computer's IP address for real Android device
  static const String baseUrl = 'http://192.168.100.66:3000/api';

  /// Generate or get referral code for user by email
  static Future<String> generateReferralCodeByEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/generate-referral'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['referralCode'];
      } else {
        throw Exception('Failed to generate referral code: ${response.body}');
      }
    } catch (e) {
      print('Error generating referral code: $e');
      rethrow;
    }
  }

  /// Generate or get referral code for user (legacy - by wallet)
  static Future<String> generateReferralCode(String userAddress) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/generate-referral'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userAddress': userAddress}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['referralCode'];
      } else {
        throw Exception('Failed to generate referral code: ${response.body}');
      }
    } catch (e) {
      print('Error generating referral code: $e');
      rethrow;
    }
  }

  /// Get user's impact statistics by email
  static Future<ImpactStats> getImpactStatsByEmail(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/impact-stats?email=$email'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ImpactStats.fromJson(data['data']);
      } else {
        throw Exception('Failed to fetch impact stats: ${response.body}');
      }
    } catch (e) {
      print('Error fetching impact stats: $e');
      rethrow;
    }
  }

  /// Get user's impact statistics (legacy - by wallet address)
  static Future<ImpactStats> getImpactStats(String userAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/impact-stats?address=$userAddress'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ImpactStats.fromJson(data['data']);
      } else {
        throw Exception('Failed to fetch impact stats: ${response.body}');
      }
    } catch (e) {
      print('Error fetching impact stats: $e');
      rethrow;
    }
  }

  /// Claim a referral code
  static Future<Map<String, dynamic>> claimReferral(
    String userAddress,
    String referralCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/referral/claim'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userAddress': userAddress,
          'referralCode': referralCode,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['details'] ?? 'Failed to claim referral');
      }
    } catch (e) {
      print('Error claiming referral: $e');
      rethrow;
    }
  }

  /// Validate a referral code
  static Future<bool> validateReferralCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/referral/validate/$code'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error validating referral code: $e');
      return false;
    }
  }

  /// Get reward history for user
  static Future<List<RewardHistory>> getRewardHistory(
      String userAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/reward-history?address=$userAddress'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> historyJson = data['data'];
        return historyJson.map((json) => RewardHistory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch reward history: ${response.body}');
      }
    } catch (e) {
      print('Error fetching reward history: $e');
      rethrow;
    }
  }

  /// Get list of users who used your referral code
  static Future<List<ReferralDetail>> getReferralList(
      String userAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/referrals?address=$userAddress'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> referralsJson = data['data'];
        return referralsJson
            .map((json) => ReferralDetail.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch referrals: ${response.body}');
      }
    } catch (e) {
      print('Error fetching referrals: $e');
      rethrow;
    }
  }

  static Future<List<ReferralDetail>> getReferralListByEmail(
      String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/referrals?email=${Uri.encodeComponent(email)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> referralsJson = data['data'];
        return referralsJson
            .map((json) => ReferralDetail.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch referrals: ${response.body}');
      }
    } catch (e) {
      print('Error fetching referrals by email: $e');
      rethrow;
    }
  }

  /// Calculate impact score locally (for preview)
  static double calculateImpactScore(double totalDonatedEth, int referralCount) {
    final donationPoints = totalDonatedEth * 10;
    final referralPoints = referralCount * 5;
    return donationPoints + referralPoints;
  }

  /// Check if user qualifies for bonus reward
  static bool checkBonusEligibility(double impactScore, double donationEth) {
    return impactScore > 100 && donationEth > 0.5;
  }
}
