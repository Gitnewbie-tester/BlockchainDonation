import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/charity.dart';
import '../models/donation.dart';
import '../models/dashboard_stats.dart';
import '../services/api_service.dart';
import '../services/blockchain_service.dart';
import '../services/wallet_service.dart';

enum Screen {
  login,
  register,
  dashboard,
  charityDetail,
  donate,
  receipt,
  profile,
  updateInfo,
  donationHistory,
}

class AppState extends ChangeNotifier {
  AppState({ApiService? apiService})
      : _apiService = apiService ?? ApiService() {
    Future.microtask(loadCampaigns);
  }

  final ApiService _apiService;
  final BlockchainService _blockchainService = BlockchainService();
  final WalletConnector _walletService = walletConnector;
  Screen _currentScreen = Screen.login;
  bool _isLoggedIn = false;
  String _walletAddress = '';
  String _walletBalance = '0.0000'; // Actual ETH balance from blockchain
  String? _selectedCategory;
  Charity? _selectedCharity;
  Donation? _lastDonation;
  DashboardStats _dashboardStats = const DashboardStats();

  User _user = User(
    fullName: 'Alex Thompson',
    email: 'alex.thompson@email.com',
    joinDate: 'Jan 2024',
  );

  final List<Charity> _charities = [];
  bool _isCampaignsLoading = false;
  String? _campaignsError;

  // Getters
  Screen get currentScreen => _currentScreen;
  bool get isLoggedIn => _isLoggedIn;
  String get walletAddress => _walletAddress;
  String get walletBalance => _walletBalance; // Actual blockchain balance
  String? get selectedCategory => _selectedCategory;
  Charity? get selectedCharity => _selectedCharity;
  Donation? get lastDonation => _lastDonation;
  User get user => _user;
  List<Charity> get charities => List.unmodifiable(_charities);
  DashboardStats get dashboardStats => _dashboardStats;
  bool get isCampaignsLoading => _isCampaignsLoading;
  String? get campaignsError => _campaignsError;

  List<String> get categories {
    final unique = _charities
        .map((c) => c.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return unique;
  }

  List<Charity> get filteredCharities {
    final Iterable<Charity> iterable = _selectedCategory == null
        ? _charities
        : _charities.where((c) => c.category == _selectedCategory);
    return List.unmodifiable(iterable);
  }

  Future<void> loadCampaigns({bool forceRefresh = false}) async {
    if (_isCampaignsLoading) return;
    if (_charities.isNotEmpty && !forceRefresh) return;

    _isCampaignsLoading = true;
    _campaignsError = null;
    notifyListeners();

    try {
      final rawCampaigns = await _apiService.fetchCampaigns();
      final parsed =
          rawCampaigns.map((json) => Charity.fromJson(json)).toList();

      _charities
        ..clear()
        ..addAll(parsed);

      if (_selectedCategory != null &&
          !_charities.any((c) => c.category == _selectedCategory)) {
        _selectedCategory = null;
      }

      if (_selectedCharity != null) {
        _selectedCharity = _findCharityById(_selectedCharity!.id);
        if (_selectedCharity == null &&
            (_currentScreen == Screen.charityDetail ||
                _currentScreen == Screen.donate)) {
          _currentScreen = Screen.dashboard;
        }
      }
    } catch (error) {
      _campaignsError = error.toString();
    } finally {
      _isCampaignsLoading = false;
      notifyListeners();
    }
  }

  Charity? _findCharityById(String id) {
    try {
      return _charities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Actions
  Future<void> login(String email, String password) async {
    final response = await _apiService.login(email: email, password: password);
    _hydrateAuthState(response);
  }

  Future<void> register(String fullName, String email, String password) async {
    if (_walletAddress.isEmpty) {
      throw Exception('Connect your wallet with MetaMask before registering.');
    }

    final response = await _apiService.registerUser(
      address: _walletAddress,
      name: fullName,
      email: email,
      password: password,
    );

    _hydrateAuthState(response);
  }

  void logout() {
    _isLoggedIn = false;
    _walletAddress = '';
    _selectedCharity = null;
    _lastDonation = null;
    _selectedCategory = null;
    _dashboardStats = const DashboardStats();
    _currentScreen = Screen.login;
    notifyListeners();
  }

  void connectWallet(String address) {
    _walletAddress = address;
    notifyListeners();
    // Load dashboard stats and wallet balance when wallet is connected
    unawaited(_refreshDashboardStats());
    unawaited(_refreshWalletBalance());
  }

  Future<void> _refreshWalletBalance() async {
    if (_walletAddress.isEmpty) return;
    try {
      final balance = await _blockchainService.getBalance(_walletAddress);
      _walletBalance = balance;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching wallet balance: $e');
      }
    }
  }

  void disconnectWallet() {
    _walletAddress = '';
    _walletBalance = '0.0000';
    notifyListeners();
  }

  void navigateTo(Screen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void selectCategory(String? category) {
    if (category != null && !_charities.any((c) => c.category == category)) {
      return;
    }
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void selectCharity(String charityId) {
    final charity = _findCharityById(charityId);
    if (charity == null) return;
    _selectedCharity = charity;
    _currentScreen = Screen.charityDetail;
    notifyListeners();
  }

  void donateToCharity(String charityId) {
    final charity = _findCharityById(charityId);
    if (charity == null) return;
    _selectedCharity = charity;
    _currentScreen =
        _walletAddress.isNotEmpty ? Screen.donate : Screen.charityDetail;
    notifyListeners();
  }

  Future<void> submitDonation(String amount, String message) async {
    final charity = _selectedCharity;
    if (charity == null) {
      throw Exception('No charity selected');
    }
    
    if (kDebugMode) {
      print('Submitting donation for charity: ${charity.title} (ID: "${charity.id}")');
    }

    final ethAmount = double.tryParse(amount) ?? 0;
    if (ethAmount <= 0) {
      throw Exception('Invalid donation amount');
    }

    if (_walletAddress.isEmpty) {
      throw Exception('Connect your wallet before donating.');
    }
    
    final campaignId = charity.id.trim();
    if (campaignId.isEmpty) {
      throw Exception('Selected campaign has no ID');
    }

    // Validate beneficiary address
    final beneficiaryAddress = charity.beneficiaryAddress.trim();
    if (beneficiaryAddress.isEmpty) {
      throw Exception('Campaign has no beneficiary address');
    }
    
    if (!beneficiaryAddress.startsWith('0x') || beneficiaryAddress.length != 42) {
      throw Exception('Invalid beneficiary address format: $beneficiaryAddress');
    }

    const double weiPerEth = 1000000000000000000;
    final weiAmount = (ethAmount * weiPerEth).round();
    final weiHex = '0x${weiAmount.toRadixString(16)}';

    String txHash;
    try {
      // Send real blockchain transaction through WalletConnect
      if (kDebugMode) {
        print('Sending transaction: $ethAmount ETH');
        print('From: $_walletAddress');
        print('To: $beneficiaryAddress');
        print('Value: $weiHex ($weiAmount wei)');
      }
      
      txHash = await _walletService.sendTransaction(
        from: _walletAddress,
        to: beneficiaryAddress,
        value: weiHex,
      );
      
      if (kDebugMode) {
        print('Transaction sent! Hash: $txHash');
      }
    } catch (e) {
      throw Exception('Transaction failed: $e');
    }

    // Generate receipt metadata
    final cid = 'receipt-${DateTime.now().millisecondsSinceEpoch}';
    final gatewayUrl = 'https://ipfs.io/ipfs/$cid';
    const int sizeBytes = 512;

    // Record donation in database
    await _apiService.recordDonation(
      txHash: txHash,
      donorAddress: _walletAddress,
      campaignId: campaignId,
      amountWei: weiAmount,
      cid: cid,
      sizeBytes: sizeBytes,
      gatewayUrl: gatewayUrl,
    );

    await _refreshDashboardStats();
    await _refreshWalletBalance();
    await loadCampaigns(forceRefresh: true);

    _lastDonation = Donation(
      amount: amount,
      charity: charity.title,
      message: message.isEmpty ? null : message,
      transactionHash: txHash,
      timestamp: DateTime.now().toString(),
      gasUsed: '21,000',
      blockNumber: 'Pending',
    );

    _currentScreen = Screen.receipt;
    notifyListeners();
  }

  void updateUser(User updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  void backToDashboard() {
    _selectedCharity = null;
    _lastDonation = null;
    _currentScreen = Screen.dashboard;
    notifyListeners();
  }

  void _hydrateAuthState(Map<String, dynamic> response) {
    final payload = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final userJson = payload['user'] is Map<String, dynamic>
        ? payload['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    final statsJson = payload['stats'] is Map<String, dynamic>
        ? payload['stats'] as Map<String, dynamic>
        : <String, dynamic>{};

    _user = userJson.isNotEmpty
        ? User.fromBackend(userJson)
        : _user.copyWith(email: payload['email']?.toString());
    _dashboardStats = DashboardStats.fromJson(statsJson);
    _isLoggedIn = true;
    _currentScreen = Screen.dashboard;
    notifyListeners();
    unawaited(loadCampaigns(forceRefresh: true));
  }

  Future<void> _refreshDashboardStats() async {
    if (_walletAddress.isEmpty) return;
    try {
      final response = await _apiService.fetchDashboardStats(_walletAddress);
      final payload = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      _dashboardStats = DashboardStats.fromJson(payload);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching dashboard stats: $e');
      }
    }
  }
}
