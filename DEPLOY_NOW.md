# 🚀 DEPLOY YOUR SMART CONTRACT NOW!

## ⚡ Quick Start (15 minutes)

Your API keys are configured! Now deploy the contract:

### Step 1: Open Remix IDE
🔗 **Click here:** https://remix.ethereum.org/

### Step 2: Create the Contract File
1. In Remix, click **"File Explorer"** icon (left sidebar)
2. Click the **"+"** button to create a new file
3. Name it: `DonationRegistry.sol`
4. **Copy ALL the code** from your local file:
   - File location: `contracts/DonationRegistry.sol`
   - Copy lines 1-85 (the entire contract)
5. **Paste** into the Remix editor

### Step 3: Compile
1. Click the **"Solidity Compiler"** icon (left sidebar, 2nd icon)
2. Select compiler version: **0.8.19** or higher
3. Click the big blue **"Compile DonationRegistry.sol"** button
4. ✅ Wait for "Compilation successful" checkmark

### Step 4: Get Sepolia Test ETH
Before deploying, you need free test ETH:

🔗 **Get free Sepolia ETH:**
- https://sepoliafaucet.com/
- OR: https://sepolia-faucet.pk910.de/

**How to use:**
1. Open MetaMask
2. Switch to **Sepolia Test Network**
3. Copy your wallet address
4. Paste into faucet website
5. Wait 1-2 minutes for ETH to arrive

### Step 5: Deploy to Sepolia
1. Click the **"Deploy & Run Transactions"** icon (left sidebar, 3rd icon)
2. In **"ENVIRONMENT"** dropdown, select: **"Injected Provider - MetaMask"**
3. MetaMask will pop up → Click **"Connect"**
4. Ensure MetaMask shows: **"Sepolia Test Network"** at the top
5. Click the orange **"Deploy"** button
6. MetaMask will pop up again → Click **"Confirm"**
7. Wait 10-30 seconds for deployment...

### Step 6: Copy the Contract Address 🎯
After deployment succeeds:
1. Look at the bottom of the left panel
2. You'll see **"Deployed Contracts"** section
3. Your contract will appear with an address like:
   ```
   DONATIONREGISTRY AT 0x1234...5678 (Sepolia)
   ```
4. **COPY THIS ADDRESS!** (Click the copy icon)

### Step 7: Update Your Flutter App
1. Open file: `lib/utils/app_state.dart`
2. Find line ~30 (search for `CONTRACT_ADDRESS`)
3. Replace `'DEPLOY_CONTRACT_FIRST'` with your address:
   ```dart
   static const String CONTRACT_ADDRESS = '0xYOUR_ADDRESS_HERE';
   ```
4. Save the file

### Step 8: Verify on Etherscan (Optional but Recommended)
1. Go to: https://sepolia.etherscan.io/
2. Paste your contract address in the search bar
3. Click on your contract
4. Go to **"Contract"** tab
5. Click **"Verify and Publish"**
6. Select:
   - Compiler: **0.8.19**
   - License: **MIT**
7. Copy-paste your contract code from `DonationRegistry.sol`
8. Submit!

---

## ✅ Testing Your Setup

After deployment, test everything:

### Test 1: Make a Donation
1. Run your Flutter app
2. Connect MetaMask
3. Select a campaign
4. Click "Donate" (try 0.001 ETH)
5. **Check console logs** - should see:
   ```
   📤 Step 1: Uploading receipt to IPFS...
   ✅ Receipt uploaded! CID: QmX7...
   🔨 Step 2: Encoding contract call...
   📝 Step 3: Calling smart contract...
   ```
6. Approve in MetaMask
7. Wait for confirmation

### Test 2: Verify on Etherscan
1. After donation, copy the transaction hash
2. Go to: https://sepolia.etherscan.io/tx/YOUR_TX_HASH
3. Click **"Logs"** tab
4. You should see:
   ```
   Event: DonationReceived(...)
   - campaignIdHash: 0x7f8a...
   - donor: 0x1234... (your wallet)
   - beneficiary: 0x5678... (charity wallet)
   - amount: 1000000000000000 (0.001 ETH)
   - receiptCid: "QmX7..." (IPFS CID)
   - timestamp: 1732723200
   ```

### Test 3: View Receipt on IPFS
1. Copy the IPFS CID from the event logs
2. Go to: https://gateway.pinata.cloud/ipfs/YOUR_CID
3. You should see your receipt JSON!

### Test 4: Check Donation History
1. In your app, navigate to donation history
2. You should see your donation listed
3. Click "Receipt" → Opens IPFS gateway
4. Click "Etherscan" → Opens transaction on Etherscan

---

## 🎉 Success Checklist

- ✅ Smart contract deployed to Sepolia
- ✅ Contract address updated in app_state.dart
- ✅ IPFS uploads working (Pinata API keys configured)
- ✅ Donations call the smart contract (not direct transfer)
- ✅ Transaction events visible on Etherscan
- ✅ Receipts viewable on IPFS
- ✅ Donation history shows past donations
- ✅ Backend saves to PostgreSQL database

---

## 🆘 Troubleshooting

### Error: "Smart contract not deployed yet!"
- Make sure you updated `CONTRACT_ADDRESS` in `app_state.dart`
- The address should start with `0x` and be 42 characters long
- Restart your Flutter app after updating

### Error: IPFS upload failed
- Check your Pinata API keys in `ipfs_service.dart`
- Make sure they're not wrapped in quotes twice
- Check internet connection

### MetaMask doesn't pop up
- Make sure MetaMask is on Sepolia network
- Try disconnecting and reconnecting wallet
- Check if MetaMask app is installed on emulator

### Transaction fails
- Make sure you have enough Sepolia ETH
- Check gas limit (should be ~50k for contract call)
- Verify contract address is correct
- Check Etherscan for error messages

### Backend error when saving donation
- Make sure backend server is running
- Check PostgreSQL is running
- Verify campaigns table has the campaign_id
- Check console logs for SQL errors

---

## 📊 Expected Flow After Setup

```
1. User clicks "Donate 0.001 ETH"
   ↓
2. Flutter generates receipt JSON
   ↓
3. Receipt uploaded to IPFS → Returns CID: QmX7Yh9k2...
   ↓
4. Flutter encodes contract call with (campaignId, beneficiary, CID)
   ↓
5. Transaction sent to contract (not beneficiary!)
   ↓
6. MetaMask pops up → User approves
   ↓
7. Contract executes:
   - Transfers 0.001 ETH to charity wallet
   - Updates campaignTotals mapping
   - Increments donorCounts
   - Emits DonationReceived event with all data
   ↓
8. Transaction hash returned: 0xabc123...
   ↓
9. Flutter calls backend /api/donate:
   - Saves receipt (cid, size_bytes, gateway_url)
   - Saves donation (tx_hash, donor, campaign_id, cid, amount_wei)
   ↓
10. Receipt screen shows:
    - Transaction Hash: 0xabc123... [View on Etherscan]
    - Block Number: 12345678
    - IPFS Receipt: QmX7... [View Receipt]
    ↓
11. User can navigate to "Donation History"
    ↓
12. History screen queries: GET /api/donations/0xYOUR_WALLET
    ↓
13. Shows list of all donations with:
    - Campaign name
    - Amount in ETH
    - Date/time
    - Transaction hash
    - [Receipt] button → Opens IPFS
    - [Etherscan] button → Opens blockchain explorer
```

---

## 🎓 What You've Achieved

**Before:**
- ❌ Direct ETH transfers (no on-chain record)
- ❌ Fake IPFS CIDs (no actual storage)
- ❌ Receipts in memory only (lost on app close)
- ❌ No way to verify donations
- ❌ No donation history

**After:**
- ✅ Smart contract records every donation
- ✅ Real IPFS storage for receipts
- ✅ Receipts permanently accessible
- ✅ Full transparency on Etherscan
- ✅ Complete donation history
- ✅ Proper bridge between off-chain (PostgreSQL) and on-chain (Solidity)
- ✅ Audit trail: Database → Contract Event → IPFS Receipt

---

## 📞 Need Help?

If you get stuck:
1. Check console logs in Flutter for detailed error messages
2. Check backend logs (in terminal where `node server.js` is running)
3. Check Etherscan transaction page for revert reasons
4. Verify all configuration:
   - ✅ Pinata API keys in `ipfs_service.dart`
   - ✅ Contract address in `app_state.dart`
   - ✅ MetaMask on Sepolia network
   - ✅ Backend server running on port 3000
   - ✅ PostgreSQL database running

---

**Your instructor will be impressed! You now have a production-ready architecture that properly bridges off-chain and on-chain data! 🎉**
