import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../theme/app_theme.dart';

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});

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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DonationHistoryItem(
            charityName: 'Clean Water for Rural Communities',
            amount: '0.25 ETH',
            date: 'Nov 15, 2024',
            status: 'Completed',
            onViewReceipt: () {
              // Mock receipt view
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt feature coming soon')),
              );
            },
          ),
          const SizedBox(height: 12),
          _DonationHistoryItem(
            charityName: 'Education for Every Child',
            amount: '0.50 ETH',
            date: 'Nov 10, 2024',
            status: 'Completed',
            onViewReceipt: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt feature coming soon')),
              );
            },
          ),
          const SizedBox(height: 12),
          _DonationHistoryItem(
            charityName: 'Emergency Medical Aid',
            amount: '0.72 ETH',
            date: 'Nov 5, 2024',
            status: 'Completed',
            onViewReceipt: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DonationHistoryItem extends StatelessWidget {
  final String charityName;
  final String amount;
  final String date;
  final String status;
  final VoidCallback onViewReceipt;

  const _DonationHistoryItem({
    required this.charityName,
    required this.amount,
    required this.date,
    required this.status,
    required this.onViewReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    charityName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: AppTheme.green700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amount,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.blue600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewReceipt,
                child: const Text('View Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
