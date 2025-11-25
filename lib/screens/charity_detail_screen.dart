import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/header_widget.dart';
import '../utils/wallet_connection_helper.dart';
import '../utils/formatting_utils.dart';

class CharityDetailScreen extends StatelessWidget {
  const CharityDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final charity = state.selectedCharity;
        if (charity == null) {
          return const Scaffold(
            body: Center(child: Text('No charity selected')),
          );
        }

        final hasGoal = charity.goal > 0;
        final progressValue = hasGoal
            ? (charity.raised / charity.goal).clamp(0.0, 1.0).toDouble()
            : 0.0;
        final raisedLabel = '${formatEth(charity.raised)} ETH';
        final goalLabel =
            hasGoal ? 'of ${formatEth(charity.goal)} ETH' : 'Goal not set';
        final fundedLabel = hasGoal
            ? '${charity.progress.toStringAsFixed(0)}% funded'
            : 'Open contribution';

        return Scaffold(
          body: Column(
            children: [
              HeaderWidget(
                walletAddress: state.walletAddress,
                walletBalance: state.walletBalance,
                userName: state.user.fullName,
                onWalletClick: () => _handleWalletTap(context, state),
                onProfileClick: () => state.navigateTo(Screen.profile),
                onLogout: () => state.logout(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Image
                      Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: charity.image,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 300,
                              color: AppTheme.slate100,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 300,
                              color: AppTheme.slate100,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => state.backToDashboard(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    charity.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall,
                                  ),
                                ),
                                if (charity.verified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.green600,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Verified',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Chip(
                              label: Text(charity.category),
                              backgroundColor: AppTheme.blue50,
                            ),
                            const SizedBox(height: 16),

                            Text(
                              charity.description,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),

                            // Progress Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          raisedLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                color: AppTheme.blue600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          goalLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressValue,
                                        backgroundColor: AppTheme.slate200,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                AppTheme.blue600),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${charity.backers} backers',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        Text(
                                          fundedLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'On-chain details',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    _AddressLine(
                                      label: 'Beneficiary wallet',
                                      value: charity.beneficiaryAddress,
                                    ),
                                    const SizedBox(height: 8),
                                    _AddressLine(
                                      label: 'Campaign owner',
                                      value: charity.ownerAddress,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Donate Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _handleDonateClick(context, state, charity.id),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                                child: const Text('Donate Now'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _handleWalletTap(BuildContext context, AppState state) async {
  await ensureWalletConnection(context, state);
}

Future<void> _handleDonateClick(BuildContext context, AppState state, String charityId) async {
  // If wallet not connected, connect first
  if (state.walletAddress.isEmpty) {
    await ensureWalletConnection(context, state);
    // After connection attempt, check if connected and proceed
    if (state.walletAddress.isEmpty) {
      return; // User cancelled or connection failed
    }
  }
  
  // Now navigate to donation form
  state.donateToCharity(charityId);
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasValue = value.isNotEmpty;
    final displayValue = hasValue ? value : 'Not provided';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SelectableText(
            displayValue,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasValue ? AppTheme.blue600 : AppTheme.slate600,
            ),
          ),
        ),
      ],
    );
  }
}
