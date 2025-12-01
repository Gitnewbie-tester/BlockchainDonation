import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? _resolveBaseUrl();

  final String baseUrl;

  static String _resolveBaseUrl() {
    const defaultPort = 3000;
    final bool isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final host = isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$host:$defaultPort';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> payload) async {
    final response = await http
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      throw ApiException(
          'Request to $path failed (${response.statusCode}) ${response.body}');
    }

    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response =
        await http.get(_uri(path)).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      throw ApiException(
          'Request to $path failed (${response.statusCode}) ${response.body}');
    }

    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> registerUser({
    required String address,
    required String name,
    required String email,
    required String password,
    String? phone,
  }) {
    return _postJson('/api/auth/register', {
      'address': address,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _postJson('/api/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> fetchDashboardStats(String address) {
    return _getJson('/api/dashboard/$address');
  }

  Future<List<Map<String, dynamic>>> fetchCampaigns() async {
    final response = await _getJson('/api/campaigns');
    final data = response['data'];

    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    if (data is Map<String, dynamic>) {
      return [Map<String, dynamic>.from(data)];
    }

    return <Map<String, dynamic>>[];
  }

  Future<void> recordDonation({
    required String txHash,
    required String donorAddress,
    required String campaignId,
    required int amountWei,
    required String cid,
    required int sizeBytes,
    required String gatewayUrl,
  }) async {
    await _postJson('/api/donate', {
      'tx_hash': txHash,
      'donor_address': donorAddress,
      'campaign_id': campaignId,
      'amount_wei': amountWei,
      'cid': cid,
      'size_bytes': sizeBytes,
      'gateway_url': gatewayUrl,
    });
  }

  Future<void> updateUserInfo({
    required String address,
    required String name,
    required String email,
    String? phone,
  }) async {
    await _postJson('/api/user/update', {
      'address': address,
      'name': name,
      'email': email,
      'phone': phone,
    });
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
