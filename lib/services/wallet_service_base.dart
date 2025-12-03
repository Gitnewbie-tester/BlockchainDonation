abstract class WalletConnector {
  bool get isMetaMaskAvailable;
  Future<String> connectMetaMask();

  bool get isWalletConnectAvailable;
  
  /// Connect directly to MetaMask without intermediate screen
  Future<String> connectDirectly();
  
  Future<void> disconnect();
  
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String value,
    String? data,
  });
}

class WalletException implements Exception {
  WalletException(this.message);

  final String message;

  @override
  String toString() => 'WalletException: $message';
}
