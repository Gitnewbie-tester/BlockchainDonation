# Quick Integration Guide: IPFS + Smart Contract

## Overview

You have most pieces already working. Here's what needs to be added/modified:

## Step 1: Deploy the Smart Contract (15 min) ✨ DO THIS FIRST

### Using Remix (Easiest):

1. **Go to:** https://remix.ethereum.org/
2. **Create new file:** `DonationRegistry.sol`
3. **Copy the contract** from: `contracts/DonationRegistry.sol`
4. **Compile:**
   - Click "Solidity Compiler" tab
   - Select version `0.8.19`
   - Click "Compile"
5. **Deploy:**
   - Click "Deploy & Run" tab
   - Select "Injected Provider - MetaMask"
   - Switch MetaMask to **Sepolia Test Network**
   - Click **Deploy**
   - Approve in MetaMask
6. **SAVE THE ADDRESS!** You'll get something like:
   ```
   0x1234567890abcdef1234567890abcdef12345678
   ```

### Get Sepolia Test ETH:
- https://sepoliafaucet.com/
- https://sepolia-faucet.pk910.de/

---

## Step 2: Configure IPFS (10 min)

### Sign up for Pinata (Free):

1. Go to: https://www.pinata.cloud/
2. Sign up (free account)
3. Get your API keys:
   - Dashboard → API Keys → New Key
   - Copy the **API Key** and **API Secret**

### Update `ipfs_service.dart`:

Open `lib/services/ipfs_service.dart` and replace:

```dart
static const String PINATA_API_KEY = 'YOUR_PINATA_API_KEY';
static const String PINATA_SECRET = 'YOUR_PINATA_SECRET';
```

With your actual keys:

```dart
static const String PINATA_API_KEY = 'abc123...';
static const String PINATA_SECRET = 'xyz789...';
```

---

## Step 3: Update Dependencies (5 min)

Open `pubspec.yaml` and ensure you have:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... your existing dependencies ...
  http: ^1.1.0  # For IPFS uploads (already have this)
  web3dart: ^2.7.3  # For smart contract (already have this)
```

Run:
```powershell
flutter pub get
```

---

## Step 4: Create Simplified Contract Caller (30 min)

Since you're already using WalletConnect, we'll integrate the contract call through WalletConnect instead of directly with web3dart.

Create a new file: `lib/services/contract_service.dart`

```dart
import 'wallet_service_mobile.dart';

class ContractService {
  final WalletServiceMobile _walletService;
  
  // IMPORTANT: Paste your deployed contract address here!
  static const String CONTRACT_ADDRESS = '0xYOUR_CONTRACT_ADDRESS_HERE';
  
  ContractService(this._walletService);

  /// Call the donate() function on the smart contract via WalletConnect
  Future<String> donate({
    required String fromAddress,
    required String campaignId,
    required String beneficiaryAddress,
    required String receiptCid,
    required double amountEth,
  }) async {
    // Convert ETH to Wei (hex string)
    final weiAmount = BigInt.from(amountEth * 1e18);
    final weiHex = '0x${weiAmount.toRadixString(16)}';

    // Encode function call: donate(campaignId, beneficiary, receiptCid)
    final data = _encodeDonateCall(campaignId, beneficiaryAddress, receiptCid);

    // Send transaction via WalletConnect
    final txHash = await _walletService.sendTransaction(
      from: fromAddress,
      to: CONTRACT_ADDRESS,
      value: weiHex,
      data: data,  // This makes it a contract call instead of direct transfer
    );

    return txHash;
  }

  /// Encode the donate function call
  String _encodeDonateCall(
    String campaignId,
    String beneficiaryAddress,
    String receiptCid,
  ) {
    // Function selector for donate(string,address,string)
    // This is keccak256("donate(string,address,string)") = 0x...
    const functionSelector = '0x8d3c5b1f';  // You'll need to calculate this

    // For now, we'll use a simpler approach:
    // Just send ETH to the contract and call donate manually
    // OR use the web3dart package to encode properly

    // TODO: Proper ABI encoding
    // For simplicity, we can deploy a modified contract that accepts
    // the data in the transaction's input field

    return '0x';  // Empty data = direct transfer (we'll fix this)
  }
}
```

**IMPORTANT NOTE:** The encoding above is simplified. For production, you need proper ABI encoding. Let me provide a better solution...

---

## Step 5: Simpler Approach - Use Modified App State (RECOMMENDED)

Instead of complex ABI encoding, let's modify your existing `app_state.dart` to:
1. Upload to IPFS first
2. Call the contract
3. Save to database

### Find this code in `lib/utils/app_state.dart` (around line 230):

```dart
// CURRENT CODE (around lines 230-280):
final weiAmount = BigInt.from(amount * 1e18);
final weiHex = '0x${weiAmount.toRadixString(16)}';

txHash = await _walletService.sendTransaction(
  from: _walletAddress,
  to: beneficiaryAddress,  // DIRECT TRANSFER
  value: weiHex,
);

final cid = 'receipt-${DateTime.now().millisecondsSinceEpoch}';  // FAKE CID
```

### Replace with:

```dart
// NEW CODE:
import '../services/ipfs_service.dart';

final ipfsService = IpfsService();

// 1. Upload receipt to IPFS FIRST
print('📤 Uploading receipt to IPFS...');
final ipfsResult = await ipfsService.uploadReceipt(
  txHash: 'pending',  // Will be updated
  donorAddress: _walletAddress,
  campaignId: campaignId,
  campaignName: campaignName,
  amountEth: amount,
  beneficiaryAddress: beneficiaryAddress,
);

print('✅ Receipt uploaded! CID: ${ipfsResult.cid}');

// 2. Call smart contract via WalletConnect
final weiAmount = BigInt.from(amount * 1e18);
final weiHex = '0x${weiAmount.toRadixString(16)}';

// Encode contract call data
final contractAddress = '0xYOUR_CONTRACT_ADDRESS_HERE';
final data = _encodeDonateFunction(campaignId, beneficiaryAddress, ipfsResult.cid);

print('📝 Calling smart contract...');
txHash = await _walletService.sendTransaction(
  from: _walletAddress,
  to: contractAddress,  // SEND TO CONTRACT, NOT BENEFICIARY
  value: weiHex,
  data: data,  // INCLUDE FUNCTION CALL DATA
);

print('✅ Transaction submitted! Hash: $txHash');

// 3. Use real CID (not fake)
final cid = ipfsResult.cid;  // REAL IPFS CID
```

### Add this helper function at the bottom of the AppState class:

```dart
/// Encode the donate(string, address, string) function call
String _encodeDonateFunction(String campaignId, String beneficiary, String receiptCid) {
  // For proper encoding, we need to use web3dart or do manual ABI encoding
  // This is a simplified version - see full implementation below
  
  // Function selector for donate(string,address,string)
  // keccak256("donate(string,address,string)") first 4 bytes
  const selector = '0x8d3c5b1f';  // You need to calculate this correctly
  
  // TODO: Proper ABI encoding of parameters
  // For now, return empty to test basic flow
  return '0x';
}
```

---

## Step 6: Proper ABI Encoding (CRITICAL)

The step above won't work without proper encoding. Here's the correct way:

### Option A: Use a Helper Contract (EASIEST) ⭐

Deploy a modified contract that uses `msg.data` to pass parameters, or...

### Option B: Use web3dart for encoding (PROPER WAY)

Add this to your `app_state.dart`:

```dart
import 'package:web3dart/web3dart.dart';

// At the top of your file, define the contract ABI
final contractAbi = ContractAbi.fromJson('''
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
''', 'DonationRegistry');

// Then in your function:
String _encodeDonateFunction(String campaignId, String beneficiary, String receiptCid) {
  final contract = DeployedContract(
    contractAbi,
    EthereumAddress.fromHex('0xYOUR_CONTRACT_ADDRESS'),
  );
  
  final function = contract.function('donate');
  
  final encodedData = function.encodeCall([
    campaignId,
    EthereumAddress.fromHex(beneficiary),
    receiptCid,
  ]);
  
  return bytesToHex(encodedData, include0x: true);
}
```

---

## Step 7: Update Backend Endpoint (5 min)

Your backend is already set up! Just make sure the `/api/donate` endpoint is working.

The backend already accepts:
- `tx_hash`
- `donor_address`
- `campaign_id`
- `amount_wei`
- `cid` (now will be real IPFS CID!)
- `size_bytes`
- `gateway_url`

---

## Step 8: Create Donation History Screen (45 min)

Create `lib/screens/donation_history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class DonationHistoryScreen extends StatefulWidget {
  final String walletAddress;

  const DonationHistoryScreen({
    Key? key,
    required this.walletAddress,
  }) : super(key: key);

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<Map<String, dynamic>> _donations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/api/donations/${widget.walletAddress}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _donations = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading donations: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donation History'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _donations.isEmpty
              ? const Center(child: Text('No donations yet'))
              : ListView.builder(
                  itemCount: _donations.length,
                  itemBuilder: (context, index) {
                    final donation = _donations[index];
                    return _buildDonationCard(donation);
                  },
                ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> donation) {
    final amountWei = BigInt.parse(donation['amount_wei']);
    final amountEth = amountWei / BigInt.from(10).pow(18);

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(donation['campaign_name'] ?? 'Unknown Campaign'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: $amountEth ETH'),
            Text('Date: ${donation['created_at']}'),
            Text('TX: ${donation['tx_hash'].substring(0, 10)}...'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.receipt),
              onPressed: () => _openIpfs(donation['gateway_url']),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openEtherscan(donation['tx_hash']),
            ),
          ],
        ),
      ),
    );
  }

  void _openIpfs(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openEtherscan(String txHash) async {
    final url = 'https://sepolia.etherscan.io/tx/$txHash';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
```

### Add backend endpoint in `server.js`:

```javascript
app.get('/api/donations/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const result = await pool.query(`
      SELECT 
        d.tx_hash,
        d.amount_wei,
        d.created_at,
        c.name as campaign_name,
        c.beneficiary_address,
        r.cid,
        r.gateway_url
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      JOIN receipts r ON d.cid = r.cid
      WHERE LOWER(d.donor_address) = LOWER($1)
      ORDER BY d.created_at DESC
    `, [address]);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching donations:', error);
    res.status(500).json({ error: 'Failed to fetch donations' });
  }
});
```

---

## Testing Checklist

Before you test, ensure:

- ✅ Smart contract deployed to Sepolia
- ✅ Contract address updated in code
- ✅ Pinata API keys configured
- ✅ MetaMask on Sepolia network
- ✅ Have Sepolia test ETH

### Test Flow:

1. **Make a donation (0.001 ETH)**
2. **Check IPFS upload** - Should see real CID in logs
3. **Approve transaction in MetaMask**
4. **Wait for confirmation**
5. **Check Etherscan:**
   - Go to: `https://sepolia.etherscan.io/tx/YOUR_TX_HASH`
   - Click "Logs" tab
   - Should see `DonationReceived` event
6. **View receipt on IPFS:**
   - Click the gateway URL
   - Should see JSON receipt
7. **Check donation history:**
   - Navigate to history screen
   - Should see your donation

---

## Summary

**Files to modify:**
1. ✅ `contracts/DonationRegistry.sol` - Already created
2. ✅ `lib/services/ipfs_service.dart` - Already created (add API keys)
3. ✅ `lib/utils/app_state.dart` - Update donation flow
4. ✅ `lib/screens/donation_history_screen.dart` - Create new
5. ✅ `backend/server.js` - Add GET /api/donations/:address

**External setup:**
1. Deploy contract on Remix
2. Get Pinata API keys
3. Get Infura/Alchemy RPC URL (optional, using public for now)

**Key changes:**
- Upload to IPFS **before** contract call
- Send transaction to **contract address** (not beneficiary)
- Include encoded function data in transaction
- Use **real CID** from IPFS
- Backend already handles saving to database

Need help with any specific step? Let me know!
