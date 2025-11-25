# Contracts

Solidity sources for deploying to Sepolia.

## CharityChainDonations.sol

- Allows the backend admin to register campaign beneficiaries.
- Donors call `donate(campaignId, receiptHash)` sending ETH; contract forwards funds to the campaign wallet and emits events.
- Designed for Sepolia testnet (chainId 11155111).

### Deployment (Foundry example)

```bash
forge create ContractName --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY
```

Record the deployed address and expose it to the Flutter app + backend via environment variables.