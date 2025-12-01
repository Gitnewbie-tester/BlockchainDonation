import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

class BlockchainService {
  // Use a public RPC endpoint (you can change this to your preferred network)
  // Using Ankr's public endpoint which is more reliable than Alchemy demo
  static const String _rpcUrl = 'https://rpc.ankr.com/eth_sepolia'; // Sepolia testnet
  // For mainnet: 'https://rpc.ankr.com/eth'
  
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

  /// Get pending transactions from mempool for a specific address
  /// This queries the blockchain node for pending transactions
  Future<String?> getPendingTransactionHash(String fromAddress) async {
    try {
      print('🔍 Checking pending transactions for: $fromAddress');
      
      // Query pending transactions using eth_pendingTransactions
      // Note: Not all RPC providers support this method
      final response = await http.post(
        Uri.parse(_rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_getBlockByNumber',
          'params': ['pending', true],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null && data['result']['transactions'] != null) {
          final transactions = data['result']['transactions'] as List;
          
          // Find the most recent transaction from this address
          for (var tx in transactions.reversed) {
            if (tx['from'] != null && 
                tx['from'].toString().toLowerCase() == fromAddress.toLowerCase()) {
              final hash = tx['hash'] as String;
              print('✅ Found pending transaction: $hash');
              return hash;
            }
          }
        }
      }
      
      print('ℹ️ No pending transactions found');
      return null;
    } catch (e) {
      print('❌ Error getting pending transaction: $e');
      return null;
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

  /// Gets transaction details including gas used and block number
  /// Returns a map with transaction information or null if not found
  Future<Map<String, dynamic>?> getTransactionDetails(String txHash) async {
    try {
      // Validate hash format
      if (txHash.isEmpty || !txHash.startsWith('0x') || txHash.length != 66) {
        print('⚠️ Invalid transaction hash format: $txHash');
        return null;
      }
      
      print('🔍 Fetching receipt for: $txHash');
      final receipt = await _client.getTransactionReceipt(txHash);
      
      if (receipt != null) {
        // Format gas used with commas
        final gasUsedStr = receipt.gasUsed?.toInt().toString() ?? '0';
        final gasUsedFormatted = _formatWithCommas(gasUsedStr);
        
        print('✅ Receipt found! Block: ${receipt.blockNumber.blockNum}, Gas: $gasUsedFormatted');
        
        return {
          'gasUsed': gasUsedFormatted,
          'blockNumber': receipt.blockNumber.blockNum.toString(),
          'status': receipt.status ?? false,
        };
      }
      
      // Transaction not yet mined
      print('⏳ Transaction not yet mined: $txHash');
      return null;
    } catch (e) {
      print('❌ Error fetching transaction details: $e');
      return null;
    }
  }

  /// Helper to format numbers with commas
  String _formatWithCommas(String number) {
    final parts = number.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    
    if (parts.length > 1) {
      buffer.write('.');
      buffer.write(parts[1]);
    }
    
    return buffer.toString();
  }

  /// Gets the most recent transaction from an address using Etherscan API
  /// This helps recover transaction hashes when WalletConnect relay fails
  Future<String?> getMostRecentTransaction(String address) async {
    try {
      // Use Etherscan API to get recent transactions
      // Note: This requires an API key for production use
      // For now, we'll use the free tier endpoint
      final url = Uri.parse(
        'https://api-sepolia.etherscan.io/api?module=account&action=txlist&address=$address&startblock=0&endblock=99999999&page=1&offset=1&sort=desc'
      );
      
      print('🔍 Querying Etherscan for recent transactions from $address');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['result'] is List && (data['result'] as List).isNotEmpty) {
          final txHash = data['result'][0]['hash'];
          print('✅ Found recent transaction: $txHash');
          return txHash;
        }
      }
      
      print('⚠️ No recent transactions found');
      return null;
    } catch (e) {
      print('Error getting recent transaction: $e');
      return null;
    }
  }

  void dispose() {
    _client.dispose();
  }
}
