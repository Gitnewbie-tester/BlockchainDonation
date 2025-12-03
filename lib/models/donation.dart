class Donation {
  final String amount;
  final String charity;
  final String? message;
  final String transactionHash;
  final String timestamp;
  final String gasUsed;
  final String blockNumber;
  final String? receiptCid;  // IPFS CID for blockchain-verified receipt
  final String? gatewayUrl;  // Full IPFS gateway URL

  Donation({
    required this.amount,
    required this.charity,
    this.message,
    required this.transactionHash,
    required this.timestamp,
    required this.gasUsed,
    required this.blockNumber,
    this.receiptCid,
    this.gatewayUrl,
  });
}
