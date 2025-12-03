import 'package:flutter/material.dart';

import '../services/wallet_service.dart';
import 'app_state.dart';

Future<void> ensureWalletConnection(BuildContext context, AppState state) async {
  print('🔐 ensureWalletConnection called');
  print('   Current wallet address: ${state.walletAddress}');
  print('   Is empty: ${state.walletAddress.isEmpty}');
  
  if (state.walletAddress.isNotEmpty) {
    print('   Wallet already connected, navigating to profile');
    state.navigateTo(Screen.profile);
    return;
  }
  
  print('   Wallet not connected, showing connection modal...');

  // Mobile only - use WalletConnect
  if (walletConnector.isWalletConnectAvailable) {
    await _connectViaWalletConnect(context, state);
    return;
  }

  // Error state - WalletConnect not configured
  print('❌ WalletConnect not configured. Please set WC_PROJECT_ID.');
}

Future<void> _connectViaWalletConnect(BuildContext context, AppState state) async {
  print('📱 _connectViaWalletConnect: Starting DIRECT MetaMask launch');
  print('   Current wallet address in state: ${state.walletAddress}');
  
  if (!context.mounted) {
    print('   ⚠️ Context not mounted before connection attempt');
    return;
  }
  
  try {
    print('   Launching MetaMask directly without intermediate screen...');
    final address = await walletConnector.connectDirectly();
    print('   ✅ Received address from MetaMask: $address');
    
    if (!context.mounted) {
      print('   ⚠️ Context not mounted after connection, but wallet is connected');
      // Still connect the wallet even if context is not mounted
      state.connectWallet(address);
      return;
    }
    
    print('   Calling state.connectWallet with address: $address');
    // Connect wallet immediately (UI updates happen fast)
    state.connectWallet(address);
    print('   ✅ Wallet connected successfully');
  } catch (error, stackTrace) {
    print('   ❌ WalletConnect error: $error');
    print('   Stack trace: $stackTrace');
    // Error is handled by state management
  }
}
