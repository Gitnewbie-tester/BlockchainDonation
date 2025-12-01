# 🧪 Testing IPFS Integration

## How to Test if IPFS Upload is Working

### Method 1: Check Console Logs (Easiest)

When you make a donation, watch the Flutter console. You should see:

```
📤 Step 1: Uploading receipt to IPFS...
✅ Receipt uploaded! CID: QmX7Yh9k2Qv8eN3j... (real IPFS hash)
🔧 Step 2: Encoding contract call...
📝 Step 3: Calling smart contract...
```

**If IPFS is working:**
- ✅ CID starts with `Qm` or `bafy` (IPFS format)
- ✅ CID is ~46 characters long
- ✅ Looks like: `QmX7Yh9k2Qv8eN3jP4bRtZ...`

**If IPFS is NOT working:**
- ❌ CID looks like: `receipt-1732723200` (timestamp format)
- ❌ Shows error: "Failed to upload receipt to IPFS"

---

### Method 2: Check Receipt in Donation History

1. **Make a donation** (any amount)
2. **Wait for confirmation**
3. **Go to Donation History** (Profile → Donation History)
4. **Click "Receipt" button** on your donation
5. **Browser opens** → Should show IPFS gateway

**What you should see:**
```json
{
  "type": "donation_receipt",
  "version": "1.0",
  "timestamp": "2024-11-27T10:30:00Z",
  "transaction": {
    "hash": "0xabc123...",
    "network": "sepolia",
    "chainId": 11155111
  },
  "donor": {
    "address": "0x1234..."
  },
  "campaign": {
    "id": "3996903c-6af4-488c-86b0-1f93c5cec81f",
    "name": "Clean Water Initiative",
    "beneficiary": "0x5678..."
  },
  "donation": {
    "amount_eth": 0.001,
    "amount_wei": "1000000000000000",
    "currency": "ETH"
  },
  "verification": {
    "etherscan_url": "https://sepolia.etherscan.io/tx/0xabc123...",
    "note": "This receipt is stored permanently on IPFS..."
  }
}
```

---

### Method 3: Check Etherscan Event Logs

1. **Make a donation**
2. **Copy transaction hash** from receipt screen
3. **Go to:** https://sepolia.etherscan.io/tx/YOUR_TX_HASH
4. **Click "Logs" tab**
5. **Look for `DonationReceived` event**

**You should see:**
```
Event: DonationReceived
- campaignIdHash: 0x7f8a... (hashed UUID)
- donor: 0x1234... (your wallet)
- beneficiary: 0x5678... (charity wallet)
- amount: 1000000000000000 (wei)
- receiptCid: "QmX7Yh9k2..." ← THIS IS THE IPFS CID!
- timestamp: 1732723200
```

**Click the IPFS CID link** or manually go to:
```
https://gateway.pinata.cloud/ipfs/QmX7Yh9k2...
```

---

### Method 4: Check PostgreSQL Database

Connect to your database and run:

```sql
-- Check if receipts are being saved
SELECT * FROM receipts ORDER BY created_at DESC LIMIT 5;

-- Check if donations are linked to receipts
SELECT 
  d.tx_hash,
  d.amount_wei,
  c.name as campaign_name,
  r.cid,
  r.gateway_url
FROM donations d
JOIN campaigns c ON d.campaign_id = c.id
JOIN receipts r ON d.cid = r.cid
ORDER BY d.created_at DESC
LIMIT 5;
```

**Expected results:**
- `cid` column should have IPFS hashes like `QmX7Yh9k2...`
- `gateway_url` should be `https://gateway.pinata.cloud/ipfs/...`
- `size_bytes` should be > 0 (e.g., 512-1024 bytes)

---

### Method 5: Direct Pinata Dashboard Check

1. **Go to:** https://www.pinata.cloud/
2. **Log in** with your account
3. **Click "Files"** in sidebar
4. **Check recent uploads**

**You should see:**
- Files named like: `receipt_1732723200.json`
- Size: ~500-1000 bytes
- Date: Recent (last few minutes)
- CID: QmX7... format

---

## 🐛 Troubleshooting

### Error: "Failed to upload receipt to IPFS"

**Check:**
1. ✅ Pinata API keys are correct in `ipfs_service.dart`
2. ✅ Internet connection is working
3. ✅ No firewall blocking Pinata API
4. ✅ Pinata account has available storage (free tier = 1GB)

**Fix:**
```dart
// In lib/services/ipfs_service.dart
static const String PINATA_API_KEY = '76450d150885059a7bbc';
static const String PINATA_SECRET = '0e47322e3995a8f1b4523c408cb24271730d1920dc130bda2c46ceb1365ca7ba';
```

---

### Receipt shows old fake CID format

**Symptoms:**
- CID looks like: `receipt-1732723200`
- Not a real IPFS hash

**Cause:**
- Old donations before IPFS was implemented
- OR IPFS upload failed silently

**Fix:**
- Make a new donation and check the logs
- Should see "Uploading receipt to IPFS..." message

---

### Can't view receipt (404 error)

**Symptoms:**
- Click "Receipt" button
- Browser shows: "404 Not Found" or "Gateway Timeout"

**Possible causes:**
1. **IPFS pin not propagated yet** → Wait 1-2 minutes, try again
2. **Wrong gateway URL** → Try different gateway:
   - `https://gateway.pinata.cloud/ipfs/CID`
   - `https://ipfs.io/ipfs/CID`
   - `https://cloudflare-ipfs.com/ipfs/CID`
3. **CID is fake** → Make a new donation with IPFS working

---

## ✅ Success Checklist

After making a donation, verify:

- [ ] Console shows: "✅ Receipt uploaded! CID: Qm..."
- [ ] Donation appears in history screen
- [ ] Click "Receipt" button → Opens IPFS gateway
- [ ] Receipt JSON displays with all donation data
- [ ] Click "Etherscan" button → Shows transaction
- [ ] Event logs show `receiptCid` field with IPFS hash
- [ ] Clicking CID in Etherscan opens receipt
- [ ] PostgreSQL `receipts` table has new row with CID
- [ ] Pinata dashboard shows new file uploaded

---

## 📊 Expected Data Flow

```
1. User donates 0.001 ETH
   ↓
2. Flutter generates receipt JSON:
   {
     "transaction": {"hash": "pending"},
     "donor": {"address": "0x1234..."},
     "campaign": {"id": "uuid...", "name": "Clean Water"},
     "donation": {"amount_eth": 0.001}
   }
   ↓
3. Upload to Pinata:
   POST https://api.pinata.cloud/pinning/pinFileToIPFS
   Headers: {
     "pinata_api_key": "76450d...",
     "pinata_secret_api_key": "0e4732..."
   }
   ↓
4. Pinata returns:
   {
     "IpfsHash": "QmX7Yh9k2...",  ← THIS IS THE CID
     "PinSize": 512,
     "Timestamp": "2024-11-27T10:30:00Z"
   }
   ↓
5. Flutter calls smart contract:
   donate(
     "3996903c-6af4-488c-86b0-1f93c5cec81f",  // Campaign UUID
     "0x5678...",  // Beneficiary
     "QmX7Yh9k2..."  // IPFS CID
   ) + 0.001 ETH
   ↓
6. Contract emits event with CID
   ↓
7. Backend saves to PostgreSQL:
   receipts: (cid="QmX7...", gateway_url="https://...", size_bytes=512)
   donations: (tx_hash="0xabc...", cid="QmX7...")
   ↓
8. Receipt viewable forever on IPFS!
```

---

## 🎯 Quick Test Command

To quickly verify IPFS is working, watch the logs:

```bash
# Run app with logs
flutter run --dart-define=WC_PROJECT_ID=52aa65a43d9f23d950d3daaaa3642979

# Make a donation
# Watch console for:
# "📤 Step 1: Uploading receipt to IPFS..."
# "✅ Receipt uploaded! CID: Qm..."

# If you see fake CID (receipt-123...), IPFS failed
# If you see real CID (Qm...), IPFS working! ✅
```

---

**Your IPFS integration is fully implemented!** Just make a donation and follow the steps above to verify it's working. 🎉
