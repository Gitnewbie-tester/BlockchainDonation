import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/charity.dart';
import '../models/donation.dart';
import '../models/dashboard_stats.dart';
import '../services/api_service.dart';
import '../services/blockchain_service.dart';
import '../services/wallet_service.dart';
import 'formatting_utils.dart';
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
  String _userEmail = ''; // User's email for API calls
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
  ApiService get apiService => _apiService;

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

  Future<void> register(String fullName, String email, String password, {String? referralCode}) async {
    // Allow registration without wallet - use recipient address as placeholder
    final walletToUse = _walletAddress.isEmpty ? '0x4A9D9e820651c21947906F1BAA7f7f210e682b12' : _walletAddress;

    final response = await _apiService.registerUser(
      address: walletToUse,
      name: fullName,
      email: email,
      password: password,
      referralCode: referralCode,
    );

    _hydrateAuthState(response);
    
    // If wallet was already connected during registration, keep it
    if (_walletAddress.isNotEmpty && _walletAddress != '0x4A9D9e820651c21947906F1BAA7f7f210e682b12') {
      print('✅ User registered with connected wallet: $_walletAddress');
    } else {
      print('✅ User registered without wallet - can connect later from profile');
    }
  }

  void logout() {
    print('🚪 Logging out user...');
    
    // Disconnect wallet if connected
    if (_walletAddress.isNotEmpty) {
      print('🔌 Disconnecting wallet on logout...');
      unawaited(disconnectWallet());
    }
    
    _isLoggedIn = false;
    _userEmail = '';
    _walletAddress = '';
    _walletBalance = '0.0000';
    _selectedCharity = null;
    _lastDonation = null;
    _selectedCategory = null;
    _dashboardStats = const DashboardStats();
    _currentScreen = Screen.login;
    notifyListeners();
    print('✅ Logout complete');
  }

  void connectWallet(String address) {
    print('🔗 connectWallet called with address: $address');
    print('   Previous wallet address: $_walletAddress');
    _walletAddress = address;
    print('   New wallet address stored: $_walletAddress');
    notifyListeners();
    print('   Listeners notified');
    // Defer heavy operations with longer delay to prevent UI freeze
    print('   Scheduling background refresh in 500ms...');
    Future.delayed(const Duration(milliseconds: 500), () {
      unawaited(_refreshWalletBalance());
      // Delay dashboard stats even more since it's heavier
      Future.delayed(const Duration(milliseconds: 500), () {
        unawaited(_refreshDashboardStats());
      });
    });
  }

  Future<void> _refreshWalletBalance() async {
    if (_walletAddress.isEmpty) return;
    try {
      final balance = await _blockchainService.getBalance(_walletAddress);
      if (_walletBalance != balance) {
        _walletBalance = balance;
        notifyListeners();
        print('✅ Balance fetched: $balance ETH');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error fetching wallet balance: $e');
      }
      // Don't retry, just set to 0 to avoid blocking
      if (_walletBalance != '0.0000') {
        _walletBalance = '0.0000';
        notifyListeners();
      }
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
    String cid = 'local-receipt-${DateTime.now().millisecondsSinceEpoch}';
    String gatewayUrl = '';
    int sizeBytes = 0;
    
    try {
      // STEP 1: Try to upload receipt to IPFS (optional - won't block donation if it fails)
      if (kDebugMode) {
        print('📤 Step 1: Attempting IPFS upload (will continue if fails)...');
      }
      
      try {
        final ipfsResult = await _ipfsService.uploadReceipt(
          txHash: 'pending',  // Will be updated later
          donorAddress: _walletAddress,
          campaignId: campaignId,
          campaignName: charity.title,
          amountEth: ethAmount,
          beneficiaryAddress: beneficiaryAddress,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ IPFS upload taking too long, proceeding without it...');
            throw TimeoutException('IPFS upload timeout');
          },
        );
        
        cid = ipfsResult.cid;
        gatewayUrl = ipfsResult.gatewayUrl;
        sizeBytes = ipfsResult.sizeBytes;
        
        if (kDebugMode) {
          print('✅ Receipt uploaded to IPFS! CID: $cid');
        }
      } catch (ipfsError) {
        // IPFS failed but we'll continue with local receipt
        print('⚠️ IPFS upload failed: $ipfsError');
        print('📝 Continuing with local receipt storage...');
        cid = 'local-receipt-${DateTime.now().millisecondsSinceEpoch}';
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
      final errorMsg = e.toString().toLowerCase();
      
      // Check for wallet session/connection errors
      if (errorMsg.contains('no active session') || 
          errorMsg.contains('session expired') ||
          errorMsg.contains('not connected') ||
          errorMsg.contains('connection closed') ||
          errorMsg.contains('session not found')) {
        if (kDebugMode) {
          print('❌ Wallet session error: $e');
        }
        throw Exception(
          'Wallet session expired\n\n'
          'Your wallet connection has timed out.\n\n'
          'Please:\n'
          '1. Go to Profile screen\n'
          '2. Disconnect wallet\n'
          '3. Reconnect wallet\n'
          '4. Try donating again'
        );
      }
      
      // Check if this is the relay timeout (but transaction succeeded) - CHECK THIS NEXT!
      if (errorMsg.contains('success_no_hash:')) {
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
        // Use user's email (database identifier) instead of wallet address
        // This ensures donations can be queried by email-based endpoints
        await _apiService.recordDonation(
          txHash: txHash,
          donorAddress: _userEmail,
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
      receiptCid: cid.isNotEmpty ? cid : null,
      gatewayUrl: gatewayUrl.isNotEmpty ? gatewayUrl : null,
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
      _fetchTransactionDetails(txHash, amount, charity.title, message, cid, gatewayUrl);
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
    String receiptCid,
    String receiptGatewayUrl,
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
            timestamp: formatMalaysiaTime(DateTime.now()),
            gasUsed: details['gasUsed'] ?? '21,000',
            blockNumber: details['blockNumber'] ?? 'Unknown',
            receiptCid: receiptCid.isNotEmpty ? receiptCid : null,
            gatewayUrl: receiptGatewayUrl.isNotEmpty ? receiptGatewayUrl : null,
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
        timestamp: formatMalaysiaTime(DateTime.now()),
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
        timestamp: formatMalaysiaTime(DateTime.now()),
        gasUsed: 'Unavailable',
        blockNumber: 'Unavailable',
        receiptCid: receiptCid.isNotEmpty ? receiptCid : null,
        gatewayUrl: receiptGatewayUrl.isNotEmpty ? receiptGatewayUrl : null,
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
    final cid = 'receipt-${getMalaysiaTime().millisecondsSinceEpoch}';
    final gatewayUrl = 'https://ipfs.io/ipfs/$cid';
    const int sizeBytes = 512;

    // Record donation in database
    try {
      // Use user's email (database identifier) instead of wallet address
      // This ensures donations can be queried by email-based endpoints
      await _apiService.recordDonation(
        txHash: txHash,
        donorAddress: _userEmail,
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
      timestamp: formatMalaysiaTime(DateTime.now()),
      gasUsed: 'Pending...',
      blockNumber: 'Pending...',
      receiptCid: cid,
      gatewayUrl: gatewayUrl,
    );

    _currentScreen = Screen.receipt;
    notifyListeners();

    // Fetch real transaction details in the background
    _fetchTransactionDetails(txHash, amount, charity.title, message, cid, gatewayUrl);
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
    
    // Store user email for API calls
    _userEmail = userJson['email']?.toString() ?? payload['email']?.toString() ?? '';
    print('✅ User email stored: $_userEmail');
    
    // Only set wallet address if it's a valid Ethereum address
    // Don't use placeholder addresses (recipient address, 0x0000...) or emails stored as addresses
    final userAddress = userJson['address']?.toString() ?? '';
    final RECIPIENT_PLACEHOLDER = '0x4A9D9e820651c21947906F1BAA7f7f210e682b12';
    final ZERO_PLACEHOLDER = '0x0000000000000000000000000000000000000000';
    
    if (userAddress.isNotEmpty && 
        userAddress != RECIPIENT_PLACEHOLDER &&
        userAddress != ZERO_PLACEHOLDER &&
        !userAddress.contains('@') &&
        userAddress.startsWith('0x') &&
        userAddress.length == 42) {
      // Valid Ethereum address - set it
      _walletAddress = userAddress;
      print('✅ Logged in with wallet address: $_walletAddress');
    } else {
      // No valid wallet address - leave empty so user can connect later
      _walletAddress = '';
      print('✅ Logged in without wallet - user can connect from profile');
    }
    
    _dashboardStats = DashboardStats.fromJson(statsJson);
    _isLoggedIn = true;
    _currentScreen = Screen.dashboard;
    notifyListeners();
    unawaited(loadCampaigns(forceRefresh: true));
    // Refresh dashboard stats to ensure latest data
    unawaited(_refreshDashboardStats());
  }

  Future<void> _refreshDashboardStats() async {
    if (_userEmail.isEmpty) return;
    try {
      final response = await _apiService.fetchDashboardStatsByEmail(_userEmail);
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
