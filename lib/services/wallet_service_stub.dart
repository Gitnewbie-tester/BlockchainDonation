import 'package:flutter/widgets.dart';

import 'wallet_service_base.dart';

class _UnsupportedWalletConnector implements WalletConnector {
  @override
  bool get isMetaMaskAvailable => false;

  @override
  Future<String> connectMetaMask() {
    throw WalletException('MetaMask is not supported on this platform.');
  }

  @override
  bool get isWalletConnectAvailable => false;

  @override
  Future<String> connectWithWalletConnect(BuildContext context) {
    throw WalletException('No wallet support on this platform.');
  }

  @override
  Future<void> disconnect() async {
    throw WalletException('No wallet support on this platform.');
  }

  @override
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
    String? data,
  }) {
    throw WalletException('No wallet support on this platform.');
  }
}

WalletConnector createWalletConnector() => _UnsupportedWalletConnector();
