import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/charity.dart';
import '../models/donation.dart';
import '../models/dashboard_stats.dart';
import '../services/api_service.dart';
import '../services/blockchain_service.dart';
import '../services/wallet_service.dart';
import '../services/ipfs_service.dart';
import './contract_encoder.dart';

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
  final IpfsService _ipfsService = IpfsService();
  
  // Smart contract deployed on Sepolia testnet
  // View on Etherscan: https://sepolia.etherscan.io/address/0xd9145CCE52D386f254917e481eB44e9943F39138
  static const String CONTRACT_ADDRESS = '0xd9145CCE52D386f254917e481eB44e9943F39138';
  Screen _currentScreen = Screen.login;
  bool _isLoggedIn = false;
  String _walletAddress = '';
  String _walletBalance = '0.0000'; // Actual ETH balance from blockchain
  String? _selectedCategory;
  String _searchQuery = '';
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
  String get searchQuery => _searchQuery;
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
    Iterable<Charity> iterable = _charities;
    
    // Filter by category
    if (_selectedCategory != null) {
      iterable = iterable.where((c) => c.category == _selectedCategory);
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      iterable = iterable.where((c) =>
          c.title.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query));
    }
    
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
      print('✅ Balance fetched: $balance ETH');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error fetching wallet balance: $e');
      }
      // Don't retry, just set to 0 to avoid blocking
      _walletBalance = '0.0000';
      notifyListeners();
    }
  }

  Future<void> disconnectWallet() async {
    print('🔌 Disconnecting wallet...');
    
    // Disconnect from WalletConnect if connected
    try {
      await _walletService.disconnect();
      print('✅ WalletConnect session disconnected');
    } catch (e) {
      print('⚠️ Error disconnecting WalletConnect: $e');
    }
    
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

  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
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
    
    // Check wallet balance before allowing donation
    final currentBalance = double.tryParse(_walletBalance) ?? 0;
    if (currentBalance < ethAmount) {
      throw Exception(
        'Insufficient balance\n\n'
        'Your balance: $currentBalance ETH\n'
        'Required: $ethAmount ETH\n\n'
        'Please add more ETH to your wallet or reduce the donation amount.'
      );
    }
    
    // Add small buffer for gas fees (estimate ~0.002 ETH)
    const double estimatedGas = 0.002;
    if (currentBalance < (ethAmount + estimatedGas)) {
      throw Exception(
        'Insufficient balance for gas fees\n\n'
        'Your balance: $currentBalance ETH\n'
        'Donation: $ethAmount ETH\n'
        'Estimated gas: ~$estimatedGas ETH\n\n'
        'You need at least ${(ethAmount + estimatedGas).toStringAsFixed(4)} ETH total.'
      );
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

    // Initialize variables that will be used across try-catch blocks
    String txHash = '';
    String cid = 'receipt-pending';
    String gatewayUrl = '';
    int sizeBytes = 0;
    
    try {
      // STEP 1: Upload receipt to IPFS
      if (kDebugMode) {
        print('📤 Step 1: Uploading receipt to IPFS...');
      }
      
      final ipfsResult = await _ipfsService.uploadReceipt(
        txHash: 'pending',  // Will be updated later
        donorAddress: _walletAddress,
        campaignId: campaignId,
        campaignName: charity.title,
        amountEth: ethAmount,
        beneficiaryAddress: beneficiaryAddress,
      );
      
      cid = ipfsResult.cid;
      gatewayUrl = ipfsResult.gatewayUrl;
      sizeBytes = ipfsResult.sizeBytes;
      
      if (kDebugMode) {
        print('✅ Receipt uploaded! CID: $cid');
      }
      
      // STEP 2: Check if contract is deployed
      if (CONTRACT_ADDRESS == 'DEPLOY_CONTRACT_FIRST') {
        throw Exception(
          'Smart contract not deployed yet!\n\n'
          '1. Open Remix: https://remix.ethereum.org/\n'
          '2. Create DonationRegistry.sol\n'
          '3. Deploy to Sepolia\n'
          '4. Update CONTRACT_ADDRESS in app_state.dart'
        );
      }
      
      // STEP 3: Encode contract function call
      if (kDebugMode) {
        print('🔧 Step 2: Encoding contract call...');
      }
      
      final encodedData = ContractEncoder.encodeDonateFunction(
        campaignId: campaignId,
        beneficiaryAddress: beneficiaryAddress,
        receiptCid: cid,
        contractAddress: CONTRACT_ADDRESS,
      );
      
      // STEP 4: Send transaction to smart contract
      if (kDebugMode) {
        print('📝 Step 3: Calling smart contract...');
        print('Sending transaction: $ethAmount ETH');
        print('From: $_walletAddress');
        print('To: $CONTRACT_ADDRESS (contract)');
        print('Beneficiary: $beneficiaryAddress');
        print('Value: $weiHex ($weiAmount wei)');
        print('Data: $encodedData');
      }
      
      txHash = await _walletService.sendTransaction(
        from: _walletAddress,
        to: CONTRACT_ADDRESS,  // Send to contract, not beneficiary!
        value: weiHex,
        data: encodedData,  // Include function call data
      );
      
      if (kDebugMode) {
        print('✅ Transaction sent! Hash: $txHash');
      }
    } catch (e) {
      final errorMsg = e.toString();
      
      // Check if this is the relay timeout (but transaction succeeded) - CHECK THIS FIRST!
      if (errorMsg.contains('SUCCESS_NO_HASH:')) {
        if (kDebugMode) {
          print('🔍 Relay timeout - transaction succeeded but relay did not return hash');
          print('📡 Attempting to fetch transaction hash from blockchain...');
        }
        
        // Try to get the pending transaction hash from the blockchain
        // The transaction was just broadcast, so it should be in pending state
        String? fetchedHash;
        
        // Try multiple times with delays (transaction needs time to propagate)
        for (int attempt = 1; attempt <= 3; attempt++) {
          if (kDebugMode) {
            print('🔎 Attempt $attempt/3: Checking for pending transaction...');
          }
          
          await Future.delayed(Duration(seconds: 2 * attempt)); // 2s, 4s, 6s
          
          try {
            fetchedHash = await _blockchainService.getPendingTransactionHash(_walletAddress);
            
            if (fetchedHash != null && fetchedHash.isNotEmpty) {
              if (kDebugMode) {
                print('✅ Successfully retrieved transaction hash: $fetchedHash');
              }
              break;
            }
          } catch (fetchError) {
            if (kDebugMode) {
              print('⚠️ Attempt $attempt failed: $fetchError');
            }
          }
        }
        
        if (fetchedHash == null || fetchedHash.isEmpty) {
          if (kDebugMode) {
            print('⚠️ Could not retrieve transaction hash after 3 attempts');
            print('📋 Creating receipt with placeholder - user can check MetaMask');
          }
          // Fallback to special hash if we couldn't find it
          txHash = 'RELAY_TIMEOUT_CHECK_METAMASK';
        } else {
          txHash = fetchedHash;
        }
      } else {
        // Check if user cancelled the transaction
        if (errorMsg.contains('TRANSACTION_REJECTED') || 
            errorMsg.contains('Transaction was cancelled') ||
            errorMsg.contains('Transaction rejected by user') ||
            errorMsg.contains('User rejected')) {
          if (kDebugMode) {
            print('🚫 User cancelled the transaction');
          }
          throw Exception('Transaction was cancelled by user');
        }
        
        // Other errors
        throw Exception('Transaction failed: $e');
      }
    }

    // cid, gatewayUrl, and sizeBytes are already set from IPFS upload above
    
    // Record donation in database only if we have a real transaction hash
    if (txHash != 'RELAY_TIMEOUT_CHECK_METAMASK') {
      try {
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
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to record donation in database: $e');
          print('   The transaction was successful on blockchain, but database recording failed');
        }
        // Don't throw - we still want to show the receipt even if database fails
      }
    } else {
      if (kDebugMode) {
        print('ℹ️ Skipping database recording - no real transaction hash available');
        print('   User can verify transaction in MetaMask Activity tab');
      }
    }

    // Create initial donation with pending status
    _lastDonation = Donation(
      amount: amount,
      charity: charity.title,
      message: message.isEmpty ? null : message,
      transactionHash: txHash,
      timestamp: DateTime.now().toString(),
      gasUsed: 'Pending...',
      blockNumber: 'Pending...',
    );

    _currentScreen = Screen.receipt;
    notifyListeners();

    // Fetch real transaction details in the background
    // Skip if we have the special timeout hash or empty hash
    if (txHash != 'RELAY_TIMEOUT_CHECK_METAMASK' && 
        txHash.isNotEmpty && 
        txHash.startsWith('0x')) {
      if (kDebugMode) {
        print('🔍 Starting background fetch for transaction details: $txHash');
      }
      _fetchTransactionDetails(txHash, amount, charity.title, message);
    } else {
      if (kDebugMode) {
        print('⚠️ Skipping transaction details fetch - invalid hash: $txHash');
      }
    }
  }

  /// Fetches real transaction details from blockchain
  Future<void> _fetchTransactionDetails(
    String txHash,
    String amount,
    String charityTitle,
    String message,
  ) async {
    try {
      if (kDebugMode) {
        print('Fetching transaction details for: $txHash');
      }

      // Poll for transaction details (wait up to 2 minutes)
      for (int i = 0; i < 24; i++) {
        await Future.delayed(const Duration(seconds: 5));
        
        final details = await _blockchainService.getTransactionDetails(txHash);
        
        if (details != null) {
          if (kDebugMode) {
            print('Transaction confirmed!');
            print('Gas used: ${details['gasUsed']}');
            print('Block number: ${details['blockNumber']}');
          }

          // Update the donation with real details
          _lastDonation = Donation(
            amount: amount,
            charity: charityTitle,
            message: message.isEmpty ? null : message,
            transactionHash: txHash,
            timestamp: DateTime.now().toString(),
            gasUsed: details['gasUsed'] ?? '21,000',
            blockNumber: details['blockNumber'] ?? 'Unknown',
          );
          
          notifyListeners();
          return;
        }
      }

      // Timeout after 2 minutes - update to show timeout message
      if (kDebugMode) {
        print('Transaction fetch timed out after 2 minutes');
        print('Updating receipt to show unavailable status');
      }
      
      _lastDonation = Donation(
        amount: amount,
        charity: charityTitle,
        message: message.isEmpty ? null : message,
        transactionHash: txHash,
        timestamp: DateTime.now().toString(),
        gasUsed: 'Unavailable',
        blockNumber: 'Unavailable',
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching transaction details: $e');
      }
      // Update with unavailable status on error
      _lastDonation = Donation(
        amount: amount,
        charity: charityTitle,
        message: message.isEmpty ? null : message,
        transactionHash: txHash,
        timestamp: DateTime.now().toString(),
        gasUsed: 'Unavailable',
        blockNumber: 'Unavailable',
      );
      notifyListeners();
    }
  }

  Future<void> submitDonationWithHash(String amount, String message, String txHash) async {
    final charity = _selectedCharity;
    if (charity == null) {
      throw Exception('No charity selected');
    }
    
    if (kDebugMode) {
      print('Recording donation with manual transaction hash: $txHash');
    }

    final ethAmount = double.tryParse(amount) ?? 0;
    if (ethAmount <= 0) {
      throw Exception('Invalid donation amount');
    }

    if (_walletAddress.isEmpty) {
      throw Exception('Wallet not connected');
    }
    
    final campaignId = charity.id.trim();
    if (campaignId.isEmpty) {
      throw Exception('Selected campaign has no ID');
    }

    // Validate transaction hash format
    if (!txHash.startsWith('0x') || txHash.length != 66) {
      throw Exception('Invalid transaction hash format');
    }

    const double weiPerEth = 1000000000000000000;
    final weiAmount = (ethAmount * weiPerEth).round();

    // Generate receipt metadata
    final cid = 'receipt-${DateTime.now().millisecondsSinceEpoch}';
    final gatewayUrl = 'https://ipfs.io/ipfs/$cid';
    const int sizeBytes = 512;

    // Record donation in database
    try {
      await _apiService.recordDonation(
        txHash: txHash,
        donorAddress: _walletAddress,
        campaignId: campaignId,
        amountWei: weiAmount,
        cid: cid,
        sizeBytes: sizeBytes,
        gatewayUrl: gatewayUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error recording donation: $e');
      }
      throw Exception('Failed to record donation: $e');
    }

    await _refreshDashboardStats();
    await _refreshWalletBalance();
    await loadCampaigns(forceRefresh: true);

    // Create initial donation with pending status
    _lastDonation = Donation(
      amount: amount,
      charity: charity.title,
      message: message.isEmpty ? null : message,
      transactionHash: txHash,
      timestamp: DateTime.now().toString(),
      gasUsed: 'Pending...',
      blockNumber: 'Pending...',
    );

    _currentScreen = Screen.receipt;
    notifyListeners();

    // Fetch real transaction details in the background
    _fetchTransactionDetails(txHash, amount, charity.title, message);
  }

  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    notifyListeners();
    
    // Update user in database
    try {
      await _apiService.updateUserInfo(
        address: _walletAddress,
        name: updatedUser.fullName,
        email: updatedUser.email,
        phone: updatedUser.phone,
      );
      print('✅ User information updated in database');
    } catch (e) {
      print('⚠️ Failed to update user in database: $e');
      // Still keep local update even if API fails
    }
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
