import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

/// Result of uploading a receipt to IPFS
class IpfsUploadResult {
  final String cid; // IPFS Content ID (e.g., "QmX7Yh9k2...")
  final int sizeBytes;
  final String gatewayUrl; // Full URL to view receipt
  final DateTime timestamp;

  IpfsUploadResult({
    required this.cid,
    required this.sizeBytes,
    required this.gatewayUrl,
    required this.timestamp,
  });
}

/// Service for uploading donation receipts to IPFS via Pinata
class IpfsService {
  // Get free API keys from https://www.pinata.cloud/
  static const String PINATA_API_KEY = '76450d150885059a7bbc';
  static const String PINATA_SECRET = '0e47322e3995a8f1b4523c408cb24271730d1920dc130bda2c46ceb1365ca7ba';
  static const String PINATA_GATEWAY = 'https://gateway.pinata.cloud';

  /// Uploads a donation receipt to IPFS and returns the CID
  Future<IpfsUploadResult> uploadReceipt({
    required String txHash,
    required String donorAddress,
    required String campaignId,
    required String campaignName,
    required double amountEth,
    required String beneficiaryAddress,
  }) async {
    try {
      // Create receipt JSON
      final receipt = {
        'type': 'donation_receipt',
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'transaction': {
          'hash': txHash,
          'network': 'sepolia',
          'chainId': 11155111,
        },
        'donor': {
          'address': donorAddress,
        },
        'campaign': {
          'id': campaignId,
          'name': campaignName,
          'beneficiary': beneficiaryAddress,
        },
        'donation': {
          'amount_eth': amountEth,
          'amount_wei': (amountEth * 1e18).toStringAsFixed(0),
          'currency': 'ETH',
        },
        'verification': {
          'etherscan_url':
              'https://sepolia.etherscan.io/tx/$txHash',
          'note':
              'This receipt is stored permanently on IPFS and can be verified on the Ethereum Sepolia blockchain.',
        },
      };

      // Convert to JSON bytes
      final jsonString = jsonEncode(receipt);
      final jsonBytes = utf8.encode(jsonString);

      // Upload to Pinata
      final cid = await _uploadToPinata(
        jsonBytes,
        'receipt_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      // Return result
      return IpfsUploadResult(
        cid: cid,
        sizeBytes: jsonBytes.length,
        gatewayUrl: '$PINATA_GATEWAY/ipfs/$cid',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to upload receipt to IPFS: $e');
    }
  }

  /// Internal method to upload bytes to Pinata
  Future<String> _uploadToPinata(Uint8List data, String filename) async {
    try {
      // Pinata API endpoint
      final uri = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'pinata_api_key': PINATA_API_KEY,
        'pinata_secret_api_key': PINATA_SECRET,
      });

      // Add file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          data,
          filename: filename,
        ),
      );

      // Add metadata
      request.fields['pinataMetadata'] = jsonEncode({
        'name': filename,
        'keyvalues': {
          'type': 'donation_receipt',
          'app': 'charity_chain',
        },
      });

      // Add options
      request.fields['pinataOptions'] = jsonEncode({
        'cidVersion': 1,
      });

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['IpfsHash']; // This is the CID
      } else {
        throw Exception(
            'Pinata API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload to Pinata: $e');
    }
  }

  /// Retrieve a receipt from IPFS by CID
  Future<Map<String, dynamic>> getReceipt(String cid) async {
    try {
      final url = '$PINATA_GATEWAY/ipfs/$cid';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch receipt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to retrieve receipt from IPFS: $e');
    }
  }

  /// Check if IPFS service is configured correctly
  bool isConfigured() {
    return PINATA_API_KEY != 'YOUR_PINATA_API_KEY' &&
        PINATA_SECRET != 'YOUR_PINATA_SECRET';
  }

  /// Get the gateway URL for a CID
  String getGatewayUrl(String cid) {
    return '$PINATA_GATEWAY/ipfs/$cid';
  }
}
