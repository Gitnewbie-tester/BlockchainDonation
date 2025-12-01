import 'package:web3dart/web3dart.dart';

/// Helper utilities for encoding smart contract function calls
class ContractEncoder {
  /// Encodes a call to the donate(string, address, string) function
  /// 
  /// This generates the proper ABI-encoded data that can be sent
  /// via WalletConnect as the 'data' parameter in a transaction.
  /// 
  /// Parameters:
  /// - campaignId: UUID string from PostgreSQL (e.g., "3996903c-6af4-488c-86b0-1f93c5cec81f")
  /// - beneficiaryAddress: Ethereum address (e.g., "0x1234...")
  /// - receiptCid: IPFS CID (e.g., "QmX7Yh9k2...")
  /// - contractAddress: Address of deployed DonationRegistry contract
  /// 
  /// Returns: Hex-encoded function call data (e.g., "0x8d3c5b1f000...")
  static String encodeDonateFunction({
    required String campaignId,
    required String beneficiaryAddress,
    required String receiptCid,
    required String contractAddress,
  }) {
    // Define the contract ABI for the donate function
    final contractAbi = ContractAbi.fromJson(
      '''
      [
        {
          "inputs": [
            {"internalType": "string", "name": "campaignId", "type": "string"},
            {"internalType": "address", "name": "beneficiary", "type": "address"},
            {"internalType": "string", "name": "receiptCid", "type": "string"}
          ],
          "name": "donate",
          "outputs": [],
          "stateMutability": "payable",
          "type": "function"
        }
      ]
      ''',
      'DonationRegistry',
    );

    // Create a deployed contract reference
    final contract = DeployedContract(
      contractAbi,
      EthereumAddress.fromHex(contractAddress),
    );

    // Get the donate function
    final donateFunction = contract.function('donate');

    // Encode the function call with parameters
    final encodedData = donateFunction.encodeCall([
      campaignId,
      EthereumAddress.fromHex(beneficiaryAddress),
      receiptCid,
    ]);

    // Convert to hex string with 0x prefix
    return '0x${encodedData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Validates an Ethereum address format
  static bool isValidAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Formats Wei to ETH with specified decimal places
  static String weiToEth(BigInt wei, {int decimals = 2}) {
    final eth = wei / BigInt.from(10).pow(18);
    final ethDouble = eth.toDouble();
    return ethDouble.toStringAsFixed(decimals);
  }

  /// Converts ETH to Wei
  static BigInt ethToWei(double eth) {
    return BigInt.from(eth * 1e18);
  }

  /// Converts Wei BigInt to hex string with 0x prefix
  static String weiToHex(BigInt wei) {
    return '0x${wei.toRadixString(16)}';
  }
}
