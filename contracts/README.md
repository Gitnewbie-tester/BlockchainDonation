# Smart Contract Deployment Guide

## DonationRegistry.sol

This Solidity contract bridges your PostgreSQL database with the Sepolia blockchain, enabling transparent and verifiable donations.

### Contract Address (After Deployment)
```
Sepolia Testnet: [PASTE YOUR DEPLOYED ADDRESS HERE]
```

### Prerequisites

1. **MetaMask** with Sepolia ETH
   - Get free Sepolia ETH from: https://sepoliafaucet.com/

2. **Remix IDE** (Easiest method)
   - Visit: https://remix.ethereum.org/

## Deployment Steps (Using Remix - Recommended)

### Step 1: Open Remix
1. Go to https://remix.ethereum.org/
2. Create a new file: `DonationRegistry.sol`
3. Copy the contract code from `contracts/DonationRegistry.sol`

### Step 2: Compile
1. Click on the "Solidity Compiler" tab (left sidebar)
2. Select compiler version: `0.8.19+`
3. Click "Compile DonationRegistry.sol"
4. Ensure there are no errors

### Step 3: Deploy
1. Click on the "Deploy & Run Transactions" tab
2. Set **Environment** to "Injected Provider - MetaMask"
3. Ensure MetaMask is connected to **Sepolia Test Network**
4. Click **Deploy**
5. Confirm the transaction in MetaMask
6. **IMPORTANT**: Copy the deployed contract address!

### Step 4: Verify on Etherscan
1. Go to: https://sepolia.etherscan.io/address/YOUR_CONTRACT_ADDRESS
2. Click "Contract" tab → "Verify and Publish"
3. Select compiler version 0.8.19
4. Paste the contract code
5. Submit

## Contract Functions

### `donate(campaignId, beneficiary, receiptCid)`
Records a donation on-chain and transfers ETH to the beneficiary.

**Parameters:**
- `campaignId` (string): UUID from your PostgreSQL campaigns table
- `beneficiary` (address): Charity's wallet address
- `receiptCid` (string): IPFS CID of the receipt PDF/JSON

**Example:**
```javascript
donate(
  "3996903c-6af4-488c-86b0-1f93c5cec81f",  // Campaign UUID
  "0x4A9D9e820651c21947906F1BAA7f7f210e682b12", // Charity wallet
  "QmX7Yh9k2..."  // IPFS CID
) payable: 0.001 ETH
```

### `getCampaignTotal(campaignId)`
Returns total wei donated to a campaign.

### `getDonorCount(donorAddress)`
Returns number of donations made by an address.

## Event Emitted

```solidity
event DonationReceived(
    bytes32 indexed campaignIdHash,  // For efficient filtering
    address indexed donor,
    address indexed beneficiary,
    uint256 amount,
    string receiptCid,
    uint256 timestamp
);
```

## Integration Flow

```
1. User clicks "Donate" in Flutter app
   ↓
2. App generates receipt JSON/PDF and uploads to IPFS
   ↓
3. App calls contract.donate() with campaignId + IPFS CID
   ↓
4. Contract transfers ETH to charity wallet
   ↓
5. Contract emits DonationReceived event with all details
   ↓
6. Transaction hash returned to Flutter app
   ↓
7. App records in PostgreSQL: (tx_hash, donor, campaign_id, cid, amount_wei)
   ↓
8. User can view in Donation History + verify on Etherscan
```

## Gas Costs (Approximate on Sepolia)

- Deploy: ~500,000 gas
- Donate: ~50,000 gas per transaction
- View functions: FREE (no gas)