import 'package:flutter/widgets.dart';

abstract class WalletConnector {
  bool get isMetaMaskAvailable;
  Future<String> connectMetaMask();

  bool get isWalletConnectAvailable;
  Future<String> connectWithWalletConnect(BuildContext context);
  
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
  });
}

class WalletException implements Exception {
  WalletException(this.message);

  final String message;

  @override
  String toString() => 'WalletException: $message';
}
