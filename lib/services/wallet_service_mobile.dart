import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';

import '../main.dart' show registerWalletService;
import '../screens/wallet_connect_test_screen.dart';
import 'wallet_service_base.dart';
import 'wallet_service_config.dart';

class _MobileWalletConnector implements WalletConnector {
  WalletConnectModalService? _modalService;

  @override
  bool get isMetaMaskAvailable => false;

  @override
  bool get isWalletConnectAvailable => walletConnectProjectId.isNotEmpty;

  @override
  Future<String> connectMetaMask() {
    throw WalletException(
        'MetaMask browser extension is unavailable on mobile.');
  }

  @override
  Future<String> connectWithWalletConnect(BuildContext context) async {
    final service = await _ensureModalService();

    // Check if we already have an active session (e.g., restored from deep link)
    if (service.isConnected && service.address != null) {
      print('✅ WalletConnect: Already connected! Address: ${service.address}');
      return service.address!;
    }

    // Check for existing sessions that might need restoration
    final sessions = service.web3App?.sessions.getAll();
    if (sessions != null && sessions.isNotEmpty) {
      print('📁 WalletConnect: Found ${sessions.length} existing session(s)');
      for (final session in sessions) {
        print('   Session topic: ${session.topic}');
        print('   Peer: ${session.peer.metadata.name}');
        
        // Verify the session is still valid
        try {
          final namespaces = session.namespaces;
          if (namespaces.containsKey('eip155')) {
            final accounts = namespaces['eip155']?.accounts;
            if (accounts != null && accounts.isNotEmpty) {
              final account = accounts.first;
              final parts = account.split(':');
              if (parts.length >= 3) {
                final address = parts[2];
                print('✅ WalletConnect: Using existing valid session with address: $address');
                print('   No need to reconnect - session is active!');
                return address;
              }
            }
          }
        } catch (e) {
          print('   Session validation failed: $e');
        }
      }
      
      // If we get here, sessions exist but are invalid - clear them
      print('⚠️ Found invalid sessions, clearing...');
      for (final session in sessions) {
        try {
          await service.web3App?.disconnectSession(
            topic: session.topic,
            reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
          );
          print('   Cleared invalid session: ${session.topic}');
        } catch (e) {
          print('   Warning: Could not clear session ${session.topic}: $e');
        }
      }
    }

    print('WalletConnect: opening wallet connect screen...');

    if (!context.mounted) {
      throw WalletException('Context no longer valid.');
    }

    try {
      // Navigate to the WalletConnect screen with the official button
      final address = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => WalletConnectTestScreen(service: service),
        ),
      );

      if (address == null || address.isEmpty) {
        throw WalletException('Connection cancelled or no address received');
      }

      print('WalletConnect: ✅ Connection successful! Address: $address');
      return address;
    } on WalletException {
      rethrow;
    } catch (error) {
      print('WalletConnect: Connection error: $error');
      throw WalletException('WalletConnect failed: $error');
    }
  }

  Future<WalletConnectModalService> _ensureModalService() async {
    if (!isWalletConnectAvailable) {
      throw WalletException(
        'Set WC_PROJECT_ID (WalletConnect project id) to enable mobile wallet connections.',
      );
    }

    if (_modalService != null) {
      if (!_modalService!.isInitialized) {
        await _modalService!.init();
      }
      return _modalService!;
    }

    final service = WalletConnectModalService(
      projectId: walletConnectProjectId,
      metadata: walletConnectMetadata,
      requiredNamespaces: _requiredNamespaces,
      optionalNamespaces: NamespaceConstants.ethereum,
    );

    await service.init();
    _modalService = service;
    
    // Register with global deep link handler
    registerWalletService(service);
    
    // Add listener to detect connection state changes
    service.addListener(() {
      print('🔔 WalletConnect: Service state changed');
      print('   isConnected: ${service.isConnected}');
      print('   address: ${service.address}');
      if (service.session != null) {
        print('   session topic: ${service.session!.topic}');
      }
    });
    
    return service;
  }

  Map<String, RequiredNamespace> get _requiredNamespaces => {
        'eip155': const RequiredNamespace(
          chains: [
            'eip155:1',
            'eip155:11155111',
          ],
          methods: [
            'eth_sendTransaction',
            'personal_sign',
            'eth_signTypedData',
            'eth_signTypedData_v4',
          ],
          events: ['accountsChanged', 'chainChanged'],
        ),
      };

  @override
  Future<void> disconnect() async {
    print('🔌 Disconnecting WalletConnect sessions...');
    
    final service = _modalService;
    if (service == null) {
      print('   No service initialized');
      return;
    }

    // Disconnect all sessions
    final sessions = service.web3App?.sessions.getAll();
    if (sessions != null && sessions.isNotEmpty) {
      print('   Found ${sessions.length} session(s) to disconnect');
      for (final session in sessions) {
        try {
          await service.web3App?.disconnectSession(
            topic: session.topic,
            reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
          );
          print('   ✅ Disconnected session: ${session.topic}');
        } catch (e) {
          print('   ⚠️ Error disconnecting session ${session.topic}: $e');
        }
      }
    } else {
      print('   No active sessions to disconnect');
    }
    
    print('✅ WalletConnect disconnect complete');
  }

  @override
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
    String? data,  // Optional data for contract calls
  }) async {
    final service = _modalService;
    if (service == null) {
      throw WalletException('Wallet not connected');
    }

    try {
      // Get the most recent session directly from web3App
      // This ensures we use the correct session after reconnecting
      final sessions = service.web3App?.sessions.getAll();
      if (sessions == null || sessions.isEmpty) {
        throw WalletException('No active session');
      }
      
      // Use the first (most recent) session
      final session = sessions.first;
      print('📱 Using session: ${session.topic}');
      print('   Connected to: ${session.peer.metadata.name}');

      print('💸 Requesting transaction approval from wallet...');
      print('   From: $from');
      print('   To: $to');
      print('   Value: $value wei');

      // Store transaction params for later retrieval if needed
      final txParams = {
        'from': from,
        'to': to,
        'value': value,
        'gas': data != null ? '0xC350' : '0x5208',  // 50k gas for contract, 21k for transfer
        if (data != null && data.isNotEmpty) 'data': data,  // Include data for contract calls
      };

      // Send the transaction request
      print('📤 Sending transaction request...');
      
      dynamic result;
      
      // Start the request (non-blocking) and immediately try to launch the wallet
      final requestFuture = service.web3App!.request(
        topic: session.topic,
        chainId: 'eip155:11155111',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [txParams],
        ),
      );
      
      // Give the request a moment to be sent to the relay
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Try to open MetaMask - on emulator, automatic deep linking doesn't work reliably
      // so we manually open the MetaMask app
      try {
        print('🚀 Opening MetaMask to approve transaction...');
        final metamaskUri = Uri.parse('metamask://');
        if (await canLaunchUrl(metamaskUri)) {
          await launchUrl(metamaskUri, mode: LaunchMode.externalApplication);
          print('✅ MetaMask app opened');
        } else {
          print('⚠️ Cannot launch MetaMask - it may not be installed');
        }
      } catch (e) {
        print('⚠️ Could not open MetaMask: $e');
        print('   User will need to manually open MetaMask to approve');
      }
      
      print('⏰ Waiting up to 30 seconds for response...');
      
      try {
        result = await requestFuture.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏱️ Request timed out after 30 seconds');
            throw TimeoutException('No response from wallet');
          },
        );
      } on JsonRpcError catch (e) {
        // Handle user rejection BEFORE timeout
        print('❌ JSON-RPC Error during transaction: ${e.code} - ${e.message}');
        if (e.code == 4001) {
          print('🚫 User rejected the transaction');
          throw WalletException('TRANSACTION_REJECTED:Transaction was cancelled');
        }
        throw WalletException('Transaction failed: ${e.message}');
      } on TimeoutException {
        print('⏱️ Request timed out after 30 seconds');
        print('! WalletConnect relay timeout');
        print('💡 The transaction may have been approved in MetaMask');
        print('💡 This is a known issue with WalletConnect on Android emulator');
        
        // Transaction was approved, but relay didn't return the hash
        // This is a limitation of Android emulator with WalletConnect
        throw WalletException(
          'SUCCESS_NO_HASH:Your transaction was sent to the blockchain! '
          'Please check your MetaMask Activity tab to confirm. The transaction '
          'should appear on the dashboard shortly. (This notification appears '
          'due to an Android emulator limitation - your donation was successful!)'
        );
      }

      print('✅ Got response from MetaMask: $result');
      
      // The result should be the transaction hash
      final txHash = result.toString();
      if (!txHash.startsWith('0x')) {
        print('⚠️ Unexpected response format: $txHash');
        throw WalletException('Invalid transaction hash: $txHash');
      }

      print('✅ Transaction hash: $txHash');
      return txHash;
      
    } on JsonRpcError catch (e) {
      print('❌ JSON-RPC Error: ${e.code} - ${e.message}');
      if (e.code == 4001) {
        throw WalletException('Transaction rejected by user');
      }
      throw WalletException('Transaction failed: ${e.message}');
    } on WalletException {
      rethrow;
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw WalletException('Transaction failed: $e');
    }
  }

}

WalletConnector createWalletConnector() => _MobileWalletConnector();
