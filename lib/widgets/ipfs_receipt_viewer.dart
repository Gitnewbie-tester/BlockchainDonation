import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ipfs_service.dart';
import '../theme/app_theme.dart';

/// Widget that fetches and displays blockchain-verified receipt from IPFS
class IpfsReceiptViewer extends StatelessWidget {
  final String cid;
  final String? gatewayUrl;

  const IpfsReceiptViewer({
    super.key,
    required this.cid,
    this.gatewayUrl,
  });

  Future<Map<String, dynamic>> _fetchReceipt() async {
    final ipfsService = IpfsService();
    return await ipfsService.getReceipt(cid);
  }

  void _copyCid(BuildContext context) {
    Clipboard.setData(ClipboardData(text: cid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('IPFS CID copied!'),
          ],
        ),
        backgroundColor: AppTheme.green600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchReceipt(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.green50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.green200),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.green600),
                SizedBox(height: 16),
                Text(
                  'Loading blockchain-verified receipt from IPFS...',
                  style: TextStyle(color: AppTheme.slate600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Failed to load IPFS receipt',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final receipt = snapshot.data!;
        final transaction = receipt['transaction'] as Map<String, dynamic>? ?? {};
        final donor = receipt['donor'] as Map<String, dynamic>? ?? {};
        final campaign = receipt['campaign'] as Map<String, dynamic>? ?? {};
        final donation = receipt['donation'] as Map<String, dynamic>? ?? {};
        final verification = receipt['verification'] as Map<String, dynamic>? ?? {};

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.green50, AppTheme.blue50],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.green300, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.green200.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with IPFS badge
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.green600, AppTheme.blue600],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blockchain-Verified Receipt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Permanently stored on IPFS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Receipt content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Donation amount (prominent)
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Donation Amount',
                            style: TextStyle(
                              color: AppTheme.slate600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.green300),
                            ),
                            child: Text(
                              '${donation['amount_eth'] ?? '0.0'} ETH',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.green700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(color: AppTheme.green200),
                    const SizedBox(height: 16),

                    // Campaign details
                    _buildInfoSection(
                      icon: Icons.campaign,
                      title: 'Campaign',
                      value: campaign['name'] ?? 'Unknown Campaign',
                      color: AppTheme.blue600,
                    ),
                    const SizedBox(height: 16),

                    // Donor address
                    _buildInfoSection(
                      icon: Icons.account_balance_wallet,
                      title: 'Donor Address',
                      value: _formatAddress(donor['address'] ?? ''),
                      color: AppTheme.green600,
                      fullValue: donor['address'],
                    ),
                    const SizedBox(height: 16),

                    // Beneficiary address
                    _buildInfoSection(
                      icon: Icons.savings,
                      title: 'Beneficiary Address',
                      value: _formatAddress(campaign['beneficiary'] ?? ''),
                      color: AppTheme.slate600,
                      fullValue: campaign['beneficiary'],
                    ),
                    const SizedBox(height: 16),

                    // Transaction hash
                    _buildInfoSection(
                      icon: Icons.receipt_long,
                      title: 'Transaction Hash',
                      value: _formatAddress(transaction['hash'] ?? ''),
                      color: AppTheme.blue600,
                      fullValue: transaction['hash'],
                    ),
                    const SizedBox(height: 16),

                    // Network
                    _buildInfoSection(
                      icon: Icons.hub,
                      title: 'Network',
                      value: '${transaction['network']?.toString().toUpperCase() ?? 'SEPOLIA'} (Chain ID: ${transaction['chainId'] ?? '11155111'})',
                      color: AppTheme.slate600,
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: AppTheme.green200),
                    const SizedBox(height: 16),

                    // IPFS proof section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.green200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud_done, color: AppTheme.green600, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'IPFS Proof',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.slate700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.slate50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cid,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: AppTheme.slate700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => _copyCid(context),
                                  tooltip: 'Copy CID',
                                  color: AppTheme.green600,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            verification['note'] ?? 'This receipt is permanently stored on IPFS and can be verified on the blockchain.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Timestamp
                    Center(
                      child: Text(
                        'Recorded: ${receipt['timestamp'] ?? DateTime.now().toIso8601String()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.slate500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? fullValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.slate800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (fullValue != null && fullValue.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  fullValue,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.slate400,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
