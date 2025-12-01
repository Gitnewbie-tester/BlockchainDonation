import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_web3/flutter_web3.dart';
import 'dart:js' as js;

import 'wallet_service_base.dart';

class _WebWalletConnector implements WalletConnector {
  @override
  bool get isMetaMaskAvailable => ethereum != null;

  @override
  Future<String> connectMetaMask() async {
    if (!isMetaMaskAvailable) {
      throw WalletException('MetaMask extension is not detected in this browser.');
    }

    try {
      final accounts = await ethereum!.requestAccount();
      if (accounts.isEmpty) {
        throw WalletException('No MetaMask accounts were returned.');
      }
      return accounts.first;
    } catch (error) {
      throw WalletException('MetaMask connection failed: $error');
    }
  }

  @override
  bool get isWalletConnectAvailable => false;

  @override
  Future<String> connectWithWalletConnect(BuildContext context) {
    throw WalletException('WalletConnect is not available in the web build.');
  }

  @override
  Future<void> disconnect() async {
    // For MetaMask on web, there's no formal disconnect - the user manages connections
    // through the MetaMask extension itself. We just clear local state.
    print('🔌 Web wallet disconnect (no-op for MetaMask)');
  }

  @override
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
    String? data,
  }) async {
    if (!isMetaMaskAvailable) {
      throw WalletException('MetaMask is not installed');
    }

    // Validate addresses
    if (from.isEmpty || !from.startsWith('0x') || from.length != 42) {
      throw WalletException('Invalid from address: $from');
    }
    
    if (to.isEmpty || !to.startsWith('0x') || to.length != 42) {
      throw WalletException('Invalid to address: $to');
    }

    try {
      print('Sending transaction via MetaMask...');
      print('From: $from');
      print('To: $to');
      print('Value: $value');
      
      // Get ethereum object from window
      final jsEthereum = js.context['ethereum'];
      
      // Create the params object
      final paramsObject = js.JsObject.jsify({
        'method': 'eth_sendTransaction',
        'params': [
          {
            'from': from,
            'to': to,
            'value': value,
          }
        ],
      });
      
      // Call request and get the promise
      final promise = jsEthereum.callMethod('request', [paramsObject]);
      
      // Use then() callback to get the result
      final completer = Completer<String>();
      
      promise.callMethod('then', [
        js.allowInterop((result) {
          final txHash = result.toString();
          print('Transaction sent! Hash: $txHash');
          completer.complete(txHash);
        })
      ]);
      
      promise.callMethod('catch', [
        js.allowInterop((error) {
          print('Transaction promise error: $error');
          completer.completeError(error.toString());
        })
      ]);
      
      return await completer.future;
    } catch (e) {
      print('Transaction error: $e');
      if (e.toString().contains('User denied') || e.toString().contains('user rejected')) {
        throw WalletException('Transaction rejected by user');
      }
      throw WalletException('Transaction failed: $e');
    }
  }
}

WalletConnector createWalletConnector() => _WebWalletConnector();
