import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

class BlockchainService {
  // Use a public RPC endpoint (you can change this to your preferred network)
  static const String _rpcUrl = 'https://eth-sepolia.g.alchemy.com/v2/demo'; // Sepolia testnet
  // For mainnet: 'https://eth-mainnet.g.alchemy.com/v2/demo'
  
  late final Web3Client _client;
  
  BlockchainService() {
    _client = Web3Client(_rpcUrl, http.Client());
  }

  /// Fetches the ETH balance for a given address
  /// Returns the balance as a string in ETH (not Wei)
  Future<String> getBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _client.getBalance(ethAddress);
      
      // Convert Wei to ETH (1 ETH = 10^18 Wei)
      final ethBalance = balance.getValueInUnit(EtherUnit.ether);
      
      // Format to 4 decimal places
      return ethBalance.toStringAsFixed(4);
    } catch (e) {
      print('Error fetching balance: $e');
      return '0.0000';
    }
  }

  /// Fetches balances for multiple tokens (ERC-20)
  /// This is a simplified version - you'd need to add ERC-20 contract calls
  Future<Map<String, String>> getTokenBalances(String address) async {
    // For now, just return ETH balance
    final ethBalance = await getBalance(address);
    return {
      'ETH': ethBalance,
    };
  }

  /// Sends ETH to a recipient address
  /// Returns the transaction hash
  /// Note: This requires a private key or WalletConnect signing
  Future<String> sendTransaction({
    required String fromAddress,
    required String toAddress,
    required BigInt amountWei,
    required Function(Transaction) signTransaction,
  }) async {
    try {
      final from = EthereumAddress.fromHex(fromAddress);
      final to = EthereumAddress.fromHex(toAddress);
      
      // Get current gas price
      final gasPrice = await _client.getGasPrice();
      
      // Get nonce for the sender
      final nonce = await _client.getTransactionCount(from);
      
      // Create transaction
      final transaction = Transaction(
        to: to,
        from: from,
        gasPrice: gasPrice,
        maxGas: 21000, // Standard gas limit for ETH transfer
        value: EtherAmount.fromBigInt(EtherUnit.wei, amountWei),
        nonce: nonce,
      );
      
      // Sign transaction using WalletConnect or other signing method
      final signedTx = await signTransaction(transaction);
      
      // Send the signed transaction
      final txHash = await _client.sendTransaction(
        signedTx.from!,
        signedTx,
        chainId: 11155111, // Sepolia testnet chain ID
      );
      
      return txHash;
    } catch (e) {
      print('Error sending transaction: $e');
      rethrow;
    }
  }

  /// Waits for a transaction to be confirmed
  Future<TransactionReceipt?> waitForTransaction(String txHash) async {
    try {
      // Poll for transaction receipt (max 2 minutes)
      for (int i = 0; i < 24; i++) {
        await Future.delayed(const Duration(seconds: 5));
        
        try {
          final receipt = await _client.getTransactionReceipt(txHash);
          if (receipt != null) {
            return receipt;
          }
        } catch (e) {
          // Transaction not yet mined, continue polling
        }
      }
      
      return null; // Timeout
    } catch (e) {
      print('Error waiting for transaction: $e');
      return null;
    }
  }

  void dispose() {
    _client.dispose();
  }
}
