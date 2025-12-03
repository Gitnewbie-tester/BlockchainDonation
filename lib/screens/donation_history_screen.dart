import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ipfs_receipt_viewer.dart';
import '../theme/app_theme.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<Map<String, dynamic>> _donations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final userEmail = appState.user.email;

      if (userEmail.isEmpty) {
        setState(() {
          _error = 'Please login first';
          _loading = false;
        });
        return;
      }

      print('📡 Loading donation history for user: $userEmail');

      final apiService = ApiService();
      final donations = await apiService.fetchDonationsByEmail(userEmail);
      
      setState(() {
        _donations = donations;
        _loading = false;
      });
      print('✅ Loaded ${_donations.length} donations');
    } catch (e) {
      print('❌ Error loading donations: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Provider.of<AppState>(context, listen: false).navigateTo(Screen.profile);
          },
        ),
        title: const Text('Donation History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDonations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your donation history...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load donations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDonations,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_donations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No donations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation history will appear here',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDonations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _donations.length,
        itemBuilder: (context, index) {
          return _buildDonationCard(_donations[index]);
        },
      ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> donation) {
    // Parse amount
    final amountWei = BigInt.tryParse(donation['amount_wei'] ?? '0') ?? BigInt.zero;
    final amountEth = (amountWei / BigInt.from(10).pow(18)).toStringAsFixed(4);

    // Parse date
    final createdAt = donation['created_at'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
        : 'Unknown date';

    // Get data
    final campaignName = donation['campaign_name'] ?? 'Unknown Campaign';
    final txHash = donation['tx_hash'] ?? '';
    final gatewayUrl = donation['gateway_url'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campaign name
            Row(
              children: [
                const Icon(Icons.campaign, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    campaignName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Amount
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '$amountEth ETH',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Date
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 6),

            // Transaction hash
            if (txHash.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.tag, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TX: ${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Receipt on IPFS
                if (gatewayUrl.isNotEmpty && donation['cid'] != null)
                  TextButton.icon(
                    onPressed: () => _showReceiptDialog(context, donation['cid'], campaignName, amountEth),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text('View Receipt'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: AppTheme.green600,
                    ),
                  ),

                const SizedBox(width: 8),

                // View on Etherscan
                if (txHash.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _openEtherscan(txHash),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Etherscan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppTheme.blue600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      }
    } catch (e) {
      print('Error opening URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open link')),
        );
      }
    }
  }

  Future<void> _openEtherscan(String txHash) async {
    final url = 'https://sepolia.etherscan.io/tx/$txHash';
    await _openUrl(url);
  }

  void _showReceiptDialog(BuildContext context, String cid, String campaignName, String amountEth) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.green600, AppTheme.blue600],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Donation Receipt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            campaignName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Receipt content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: IpfsReceiptViewer(cid: cid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
