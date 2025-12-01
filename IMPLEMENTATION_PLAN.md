# Complete IPFS + Smart Contract Implementation Plan

## Overview

Your instructor is correct - you need to properly bridge **off-chain data (PostgreSQL)** with **on-chain data (Solidity)** using **IPFS for receipts**. This creates a verifiable audit trail.

## Current Problems

❌ Direct ETH transfers (no smart contract)  
❌ Fake IPFS CIDs (`receipt-${timestamp}`)  
❌ Receipts not persisted (only in memory)  
❌ No donation history  
❌ Cannot verify on Etherscan  
❌ No on-chain record of campaign IDs  

## Target Architecture

✅ Smart contract records donations  
✅ Real IPFS CIDs for receipts  
✅ Receipts stored permanently  
✅ Donation history viewable  
✅ Verifiable on Etherscan  
✅ Campaign UUIDs linked to transactions  

## Implementation Steps

### Step 1: Deploy Smart Contract (15 minutes)

**File:** `contracts/DonationRegistry.sol` (already created ✅)

**Action:**
1. Go to https://remix.ethereum.org/
2. Create file `DonationRegistry.sol` and paste the contract code
3. Compile with Solidity 0.8.19
4. Connect MetaMask to Sepolia network
5. Get free Sepolia ETH from https://sepoliafaucet.com/
6. Deploy the contract
7. **COPY THE CONTRACT ADDRESS** - you'll need this!
8. Verify on https://sepolia.etherscan.io/

**Expected Result:**
```
Contract Address: 0x1234567890abcdef... (Your unique address)
```

---

### Step 2: Add Required Flutter Packages (5 minutes)

**File:** `pubspec.yaml`

**Add these dependencies:**
```yaml
dependencies:
  # Existing packages...
  web3dart: ^2.7.3          # For smart contract interaction
  http: ^1.1.0              # For IPFS uploads
  path_provider: ^2.1.1     # For file operations
  pdf: ^3.10.7              # For generating PDF receipts
```

**Action:**
```powershell
flutter pub get
```

---

### Step 3: Create IPFS Service (30 minutes)

**File:** `lib/services/ipfs_service.dart` (NEW FILE)

This service will:
- Generate receipt JSON/PDF
- Upload to IPFS (using Pinata API)
- Return real IPFS CID

**Key Functions:**
```dart
class IpfsService {
  Future<IpfsUploadResult> uploadReceipt({
    required String txHash,
    required String donorAddress,
    required String campaignName,
    required double amountEth,
    required String beneficiaryAddress,
  });
}
```

**You'll need a free Pinata account:**
1. Sign up at https://www.pinata.cloud/ (free tier)
2. Get your API Key and Secret
3. Add to your app:
```dart
const String PINATA_API_KEY = 'your_api_key';
const String PINATA_SECRET = 'your_secret';
```

---

### Step 4: Create Blockchain Service (45 minutes)

**File:** `lib/services/blockchain_service.dart` (NEW FILE)

This service will:
- Connect to Sepolia via Infura/Alchemy RPC
- Load smart contract ABI
- Call `donate()` function with Web3
- Wait for transaction confirmation

**Key Functions:**
```dart
class BlockchainService {
  Future<String> submitDonation({
    required String campaignId,
    required String beneficiaryAddress,
    required String receiptCid,
    required double amountEth,
  });
}
```

**You'll need an RPC endpoint:**
- Use Infura: https://infura.io/ (free tier)
- Or Alchemy: https://www.alchemy.com/ (free tier)
- Get Sepolia RPC URL like: `https://sepolia.infura.io/v3/YOUR_PROJECT_ID`

---

### Step 5: Update Donation Flow (60 minutes)

**File:** `lib/utils/app_state.dart`

**Current code (lines 230-330):**
```dart
// WRONG: Direct transfer
txHash = await _walletService.sendTransaction(
  from: _walletAddress,
  to: beneficiaryAddress,
  value: weiHex,
);

// Fake CID
final cid = 'receipt-${DateTime.now().millisecondsSinceEpoch}';
```

**New code (replacement):**
```dart
// 1. Upload receipt to IPFS first
final ipfsResult = await _ipfsService.uploadReceipt(
  txHash: 'pending',  // Will update later
  donorAddress: _walletAddress,
  campaignName: campaignName,
  amountEth: amount,
  beneficiaryAddress: beneficiaryAddress,
);

// 2. Call smart contract donate() function
txHash = await _blockchainService.submitDonation(
  campaignId: campaignId,
  beneficiaryAddress: beneficiaryAddress,
  receiptCid: ipfsResult.cid,
  amountEth: amount,
);

// 3. Update receipt with real tx hash
await _ipfsService.updateReceiptTxHash(
  cid: ipfsResult.cid,
  txHash: txHash,
);

// 4. Save to PostgreSQL
final response = await http.post(
  Uri.parse('$baseUrl/api/donate'),
  body: jsonEncode({
    'tx_hash': txHash,
    'donor_address': _walletAddress,
    'campaign_id': campaignId,
    'amount_wei': weiAmount.toString(),
    'cid': ipfsResult.cid,
    'size_bytes': ipfsResult.sizeBytes,
    'gateway_url': ipfsResult.gatewayUrl,
  }),
);
```

---

### Step 6: Create Donation History Screen (45 minutes)

**File:** `lib/screens/donation_history_screen.dart` (NEW FILE)

**Features:**
- List all past donations
- Show campaign name, amount, date
- "View Receipt" button (opens IPFS gateway)
- "View on Etherscan" button (opens transaction)
- Pull to refresh

**Backend endpoint needed:**
```javascript
// In backend/server.js
app.get('/api/donations/:address', async (req, res) => {
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
});
```

---

### Step 7: Testing Checklist

**Before going live:**

1. ✅ Smart contract deployed and verified on Sepolia Etherscan
2. ✅ Can view contract on Etherscan: `https://sepolia.etherscan.io/address/YOUR_ADDRESS`
3. ✅ IPFS service uploads and returns real CIDs (test with Pinata)
4. ✅ Smart contract `donate()` function executes successfully
5. ✅ Transaction hash returned and saved to database
6. ✅ Event `DonationReceived` visible on Etherscan transaction logs
7. ✅ Receipt viewable via IPFS gateway: `https://gateway.pinata.cloud/ipfs/YOUR_CID`
8. ✅ Donation appears in history screen
9. ✅ Can verify entire flow: Etherscan → Event → IPFS → Database

---

## File Structure After Implementation

```
lib/
  services/
    ipfs_service.dart                    ← NEW
    blockchain_service.dart              ← NEW
    wallet_service_mobile.dart           ← EXISTING
  screens/
    donation_history_screen.dart         ← NEW
    receipt_screen.dart                  ← EXISTING (works as-is)
  utils/
    app_state.dart                       ← MODIFY (new donation flow)
contracts/
  DonationRegistry.sol                   ← ALREADY CREATED ✅
  README.md                              ← UPDATED ✅
backend/
  server.js                              ← ADD /api/donations/:address endpoint
```

---

## Expected User Flow After Implementation

```
1. User clicks "Donate 0.01 ETH" in app
   ↓
2. App generates receipt PDF with donation details
   ↓
3. Receipt uploaded to IPFS via Pinata
   ↓ (Returns: QmX7Yh9k2... ← REAL CID)
4. App calls smart contract: donate(campaignId, beneficiary, CID) + 0.01 ETH
   ↓ (MetaMask pops up)
5. User confirms transaction in MetaMask
   ↓
6. Smart contract:
   - Transfers 0.01 ETH to charity wallet
   - Emits DonationReceived event with all details
   ↓
7. Transaction hash returned: 0xabc123...
   ↓
8. App saves to PostgreSQL:
   - donations table: (tx_hash, donor, campaign_id, cid, amount_wei)
   - receipts table: (cid, size_bytes, gateway_url)
   ↓
9. Receipt screen shows:
   - Transaction Hash: 0xabc123... [View on Etherscan]
   - Block Number: 12345678
   - IPFS Receipt: QmX7Yh9k2... [View Receipt]
   ↓
10. User navigates to "Donation History"
    ↓
11. Sees all past donations with receipts
```

---

## Verification on Etherscan

After a donation, you can verify:

1. **Go to transaction on Etherscan:**
   ```
   https://sepolia.etherscan.io/tx/YOUR_TX_HASH
   ```

2. **Click "Logs" tab - you'll see:**
   ```
   DonationReceived (
     campaignIdHash: 0x7f8a... (hash of UUID)
     donor: 0x1234... (your wallet)
     beneficiary: 0x5678... (charity wallet)
     amount: 10000000000000000 (0.01 ETH in wei)
     receiptCid: "QmX7Yh9k2..." (IPFS CID)
     timestamp: 1704067200
   )
   ```

3. **Click the IPFS CID link:**
   ```
   https://gateway.pinata.cloud/ipfs/QmX7Yh9k2...
   ```
   Should show your receipt JSON/PDF!

---

## Cost Estimates

**Sepolia (Free Testnet ETH):**
- Deploy contract: ~$0 (free test ETH)
- Each donation: ~$0 (free test ETH)

**IPFS (Pinata Free Tier):**
- 1 GB storage free
- 1,000 receipts ≈ 10 MB
- Unlimited reads/downloads

**When Moving to Mainnet:**
- Deploy contract: ~$50-100 (depends on gas prices)
- Each donation: ~$2-5 per transaction
- Consider Layer 2 solutions (Polygon, Arbitrum) for lower fees

---

## Next Steps - Your Action Plan

### TODAY:
1. Deploy `DonationRegistry.sol` to Sepolia using Remix
2. Copy contract address
3. Sign up for free Pinata account
4. Sign up for free Infura account

### TOMORROW:
5. Create `ipfs_service.dart` (I'll provide the code)
6. Create `blockchain_service.dart` (I'll provide the code)
7. Update `app_state.dart` with new donation flow

### DAY 3:
8. Create `donation_history_screen.dart`
9. Add backend endpoint `/api/donations/:address`
10. Test complete flow end-to-end

### FINAL TESTING:
11. Make a test donation
12. Verify transaction on Etherscan
13. Check event logs show correct data
14. View receipt on IPFS
15. Confirm donation appears in history

---

## Questions to Answer Before Starting

1. Do you have MetaMask installed?
2. Do you have Sepolia test ETH? (Get from https://sepoliafaucet.com/)
3. Do you want to use Pinata or another IPFS service?
4. Do you want PDF receipts or JSON receipts?
5. Should I create the IPFS service code for you now?

Let me know and I'll provide the complete implementation code for each file!
