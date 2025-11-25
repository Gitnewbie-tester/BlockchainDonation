import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';

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

    // Always disconnect any stale sessions first
    if (service.isConnected) {
      print('WalletConnect: disconnecting previous session');
      await service.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
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
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
  }) async {
    final service = _modalService;
    if (service == null || !service.isConnected) {
      throw WalletException('Wallet not connected');
    }

    try {
      final session = service.session;
      if (session == null) {
        throw WalletException('No active session');
      }

      print('Requesting transaction approval from wallet...');
      print('From: $from');
      print('To: $to');
      print('Value: $value wei');

      // This will open MetaMask and show approval dialog
      // The await will block until user approves or rejects
      final result = await service.web3App!.request(
        topic: session.topic,
        chainId: 'eip155:11155111', // Sepolia testnet
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': from,
              'to': to,
              'value': value, // Value in Wei as hex string
              'gas': '0x5208', // 21000 in hex
            }
          ],
        ),
      );

      print('Transaction approved! Hash: $result');
      
      // The result should be the transaction hash
      final txHash = result.toString();
      if (!txHash.startsWith('0x')) {
        throw WalletException('Invalid transaction hash received: $txHash');
      }

      return txHash;
    } on JsonRpcError catch (e) {
      print('Transaction rejected by user or failed: ${e.message}');
      throw WalletException('Transaction rejected: ${e.message}');
    } catch (e) {
      print('Transaction error: $e');
      throw WalletException('Transaction failed: $e');
    }
  }

  Future<String> _waitForWalletAddress(
      WalletConnectModalService service) async {
    const pollingInterval = Duration(milliseconds: 200);
    const timeout = Duration(seconds: 120);
    final stopwatch = Stopwatch()..start();

    bool hasObservedActivity = service.isOpen || service.isConnected;
    SessionData? lastSession;
    bool modalWasOpen = service.isOpen;
    int checksAfterClose = 0;

    print('WalletConnect: starting address polling...');

    while (stopwatch.elapsed < timeout) {
      // Check all available properties
      final session = service.session;
      final addr = service.address;
      final connected = service.isConnected;
      final modalOpen = service.isOpen;

      // Track if modal just closed
      if (modalWasOpen && !modalOpen) {
        print('WalletConnect: modal closed, giving extra time for session to establish...');
        checksAfterClose = 0;
      }
      modalWasOpen = modalOpen;

      // Log detailed state every second
      if (stopwatch.elapsedMilliseconds % 1000 < 200) {
        print(
          'WalletConnect: [${stopwatch.elapsed.inSeconds}s] '
          'isOpen=$modalOpen connected=$connected '
          'hasSession=${session != null} address=${addr ?? "null"}',
        );
      }

      // Method 1: Direct service.address (most reliable if available)
      if (addr != null && addr.isNotEmpty) {
        print('WalletConnect: ✓ got address from service.address: $addr');
        return addr;
      }

      // Method 2: Extract from session namespaces
      if (session != null && session != lastSession) {
        lastSession = session;
        print('WalletConnect: new session detected: topic=${session.topic}');
        print('WalletConnect: parsing session namespaces...');

        final namespaces = session.namespaces;
        print('WalletConnect: available namespaces: ${namespaces.keys.join(", ")}');

        if (namespaces.containsKey('eip155')) {
          final accounts = namespaces['eip155']?.accounts;
          print('WalletConnect: eip155 accounts: $accounts');

          if (accounts != null && accounts.isNotEmpty) {
            final account = accounts.first;
            print('WalletConnect: parsing account: $account');
            final parts = account.split(':');
            if (parts.length >= 3) {
              final address = parts[2];
              print('WalletConnect: ✓ extracted address from session: $address');
              return address;
            }
          }
        }
      }

      // Track activity
      if (modalOpen || connected) {
        hasObservedActivity = true;
      }

      // Count checks after modal closes
      if (!modalOpen && hasObservedActivity) {
        checksAfterClose++;
        
        // Give it more time after modal closes (up to 10 seconds)
        if (checksAfterClose > 50) { // 50 * 200ms = 10 seconds
          if (!connected && session == null) {
            throw WalletException('Wallet selection was closed before connecting.');
          }
        }
      }

      await Future.delayed(pollingInterval);
    }

    print('WalletConnect: timeout after ${stopwatch.elapsed.inSeconds}s');
    throw WalletException(
        'Wallet connection timed out after ${stopwatch.elapsed.inSeconds} seconds.');
  }
}

WalletConnector createWalletConnector() => _MobileWalletConnector();
