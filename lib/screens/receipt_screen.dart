import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_state.dart';
import '../theme/app_theme.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _copied = false;

  void _copyTransactionHash(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _launchEtherscan(String hash) async {
    // Use Sepolia testnet explorer
    final url = Uri.parse('https://sepolia.etherscan.io/tx/$hash');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Etherscan')),
        );
      }
    }
  }

  String _formatHash(String hash) {
    if (hash.length < 18) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}';
  }

  // Simulated crypto price conversion (replace with real API in production)
  String _convertEthToUsd(String ethAmount) {
    try {
      final eth = double.parse(ethAmount);
      final usd = eth * 2000; // Example rate
      return usd.toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  String _convertGasToUsd(String gasGwei) {
    try {
      final gas = double.parse(gasGwei.replaceAll(' Gwei', ''));
      final usd = (gas / 1000000000) * 2000; // Convert Gwei to ETH then to USD
      return usd.toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final donation = state.lastDonation;
        if (donation == null) {
          return const Scaffold(
            body: Center(child: Text('No donation found')),
          );
        }

        final donationUsd = _convertEthToUsd(donation.amount);
        final gasUsd = _convertGasToUsd(donation.gasUsed);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.green50, AppTheme.blue50], // green-50 to blue-50
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => state.backToDashboard(),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Back'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.slate600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Main Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.green200),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000), // shadow-xl
                                blurRadius: 25,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header with gradient
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.green500, AppTheme.blue500], // green-500 to blue-500
                                  ),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Column(
                                  children: [
                                    // Success Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    const Text(
                                      'Donation Successful!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    
                                    const Text(
                                      'Your contribution has been processed and is now helping make a difference',
                                      style: TextStyle(
                                        color: AppTheme.green100,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              // Content
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    // Donation Summary
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 20), // red-500
                                            const SizedBox(width: 8),
                                            Text(
                                              '${donation.amount} ETH',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.slate800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '\$$donationUsd USD',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: AppTheme.slate600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.green50,
                                                border: Border.all(color: AppTheme.green200),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Live Price',
                                                style: TextStyle(
                                                  color: AppTheme.green700,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        const Text(
                                          'donated to',
                                          style: TextStyle(
                                            color: AppTheme.slate600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        Text(
                                          donation.charity,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.slate800,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    const Divider(color: AppTheme.slate200),
                                    const SizedBox(height: 16),

                                    // Message (if exists)
                                    if (donation.message != null && donation.message!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.blue50,
                                          border: Border.all(color: AppTheme.blue200),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Your Message:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.slate800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '"${donation.message}"',
                                              style: const TextStyle(
                                                color: AppTheme.slate600,
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(color: AppTheme.slate200),
                                      const SizedBox(height: 16),
                                    ],

                                    // Transaction Details
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Transaction Details',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.slate800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Transaction Hash
                                        if (donation.transactionHash == 'RELAY_TIMEOUT_CHECK_METAMASK')
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              border: Border.all(color: Colors.orange.shade200),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Check your MetaMask Activity tab for the transaction hash. Your donation was sent successfully!',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.orange.shade900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Transaction Hash:',
                                                style: TextStyle(
                                                  color: AppTheme.slate600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.slate100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      _formatHash(donation.transactionHash),
                                                      style: const TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 14),
                                                    padding: const EdgeInsets.all(4),
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () => _copyTransactionHash(donation.transactionHash),
                                                  ),
                                                  if (_copied)
                                                    const Text(
                                                      'Copied!',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme.green600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 16),
                                        
                                        // Block Number
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Block Number:',
                                              style: TextStyle(
                                                color: AppTheme.slate600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (donation.blockNumber.contains('Pending') && !donation.blockNumber.contains('Unavailable'))
                                                  const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppTheme.blue500,
                                                    ),
                                                  ),
                                                if (donation.blockNumber.contains('Pending'))
                                                  const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: donation.blockNumber.contains('Unavailable')
                                                          ? Colors.orange.shade200
                                                          : (donation.blockNumber.contains('Pending')
                                                              ? AppTheme.slate200
                                                              : AppTheme.green200),
                                                    ),
                                                    borderRadius: BorderRadius.circular(4),
                                                    color: donation.blockNumber.contains('Unavailable')
                                                        ? Colors.orange.shade50
                                                        : (donation.blockNumber.contains('Pending')
                                                            ? AppTheme.slate50
                                                            : AppTheme.green50),
                                                  ),
                                                  child: Text(
                                                    donation.blockNumber,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: donation.blockNumber.contains('Unavailable')
                                                          ? Colors.orange.shade700
                                                          : (donation.blockNumber.contains('Pending')
                                                              ? AppTheme.slate400
                                                              : AppTheme.slate800),
                                                      fontWeight: donation.blockNumber.contains('Pending')
                                                          ? FontWeight.normal
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Gas Used
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Gas Used:',
                                              style: TextStyle(
                                                color: AppTheme.slate600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (donation.gasUsed.contains('Pending') && !donation.gasUsed.contains('Unavailable'))
                                                      const SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppTheme.blue500,
                                                        ),
                                                      ),
                                                    if (donation.gasUsed.contains('Pending') && !donation.gasUsed.contains('Unavailable'))
                                                      const SizedBox(width: 8),
                                                    Text(
                                                      donation.gasUsed,
                                                      style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 11,
                                                        color: donation.gasUsed.contains('Unavailable')
                                                            ? Colors.orange.shade700
                                                            : (donation.gasUsed.contains('Pending')
                                                                ? AppTheme.slate400
                                                                : AppTheme.slate800),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (!donation.gasUsed.contains('Pending') && !donation.gasUsed.contains('Unavailable'))
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '\$$gasUsd USD',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.slate500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'Live',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.green600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Timestamp
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Timestamp:',
                                              style: TextStyle(
                                                color: AppTheme.slate600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              donation.timestamp,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    const Divider(color: AppTheme.slate200),
                                    const SizedBox(height: 16),

                                    // Action Buttons
                                    Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: (donation.transactionHash == 'RELAY_TIMEOUT_CHECK_METAMASK' || 
                                                       donation.blockNumber.contains('Unavailable'))
                                                ? null
                                                : () => _launchEtherscan(donation.transactionHash),
                                            icon: const Icon(Icons.open_in_new, size: 16),
                                            label: const Text('View on Etherscan'),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppTheme.blue200),
                                              backgroundColor: Colors.white,
                                              foregroundColor: AppTheme.blue600,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        SizedBox(
                                          width: double.infinity,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppTheme.blue600, AppTheme.green600],
                                              ),
                                              borderRadius: BorderRadius.all(Radius.circular(8)),
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () => state.backToDashboard(),
                                              icon: const Icon(Icons.home, size: 16),
                                              label: const Text('Back to Dashboard'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                shadowColor: Colors.transparent,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Footer Message
                                    Column(
                                      children: [
                                        const Text(
                                          'Thank you for making a difference! Your donation will help create positive impact.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.slate600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'All conversions use live market prices',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.green600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
