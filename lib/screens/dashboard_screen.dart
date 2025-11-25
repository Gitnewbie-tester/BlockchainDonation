import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../widgets/header_widget.dart';
import '../widgets/dashboard_stats_widget.dart';
import '../widgets/category_filter_widget.dart';
import '../widgets/charity_card_widget.dart';
import '../widgets/ai_chatbot_widget.dart';
import '../utils/wallet_connection_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  HeaderWidget(
                    walletAddress: state.walletAddress,
                    walletBalance: state.walletBalance,
                    userName: state.user.fullName,
                    onWalletClick: () => _handleWalletClick(state),
                    onProfileClick: () => state.navigateTo(Screen.profile),
                    onLogout: () => state.logout(),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF8FAFC),
                            Color(0xFFEFF6FF),
                          ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, ${state.user.fullName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                DashboardStatsWidget(
                                  totalDonated:
                                      state.dashboardStats.totalDonatedEth,
                                  charitiesSupported:
                                      state.dashboardStats.charitiesSupported,
                                  impactScore: state.dashboardStats.impactScore,
                                  totalDonations:
                                      state.dashboardStats.totalDonations,
                                ),
                                const SizedBox(height: 24),
                                CategoryFilterWidget(
                                  categories: state.categories,
                                  selectedCategory: state.selectedCategory,
                                  onCategorySelect: (category) =>
                                      state.selectCategory(category),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Campaigns',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                if (state.isCampaignsLoading &&
                                    state.charities.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child:
                                        LinearProgressIndicator(minHeight: 3),
                                  ),
                                if (state.campaignsError != null &&
                                    state.charities.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Unable to refresh campaigns. Showing last synced data.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: Colors.orange[700]),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => state.loadCampaigns(
                                              forceRefresh: true),
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                _buildCampaignsSection(context, state),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const AIChatbotWidget(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleWalletClick(AppState state) async {
    await ensureWalletConnection(context, state);
  }

  Widget _buildCampaignsSection(BuildContext context, AppState state) {
    if (state.isCampaignsLoading && state.charities.isEmpty) {
      return const _CampaignsLoadingView();
    }

    if (state.campaignsError != null && state.charities.isEmpty) {
      return _CampaignsErrorView(
        message: state.campaignsError ?? 'Unknown error',
        onRetry: () => state.loadCampaigns(forceRefresh: true),
      );
    }

    if (state.filteredCharities.isEmpty) {
      final hasFilter = state.selectedCategory != null;
      return _EmptyCampaignsView(
        hasFilter: hasFilter,
        onRefresh: () => state.loadCampaigns(forceRefresh: true),
        onClearFilter: hasFilter ? () => state.selectCategory(null) : null,
      );
    }

    final charities = state.filteredCharities;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: charities.length,
      itemBuilder: (context, index) {
        final charity = charities[index];
        return CharityCardWidget(
          charity: charity,
          onTap: () => state.selectCharity(charity.id),
        );
      },
    );
  }
}

class _CampaignsLoadingView extends StatelessWidget {
  const _CampaignsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CampaignsErrorView extends StatelessWidget {
  const _CampaignsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unable to load campaigns', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Please ensure the backend server and database are running, then try again.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCampaignsView extends StatelessWidget {
  const _EmptyCampaignsView({
    required this.hasFilter,
    required this.onRefresh,
    this.onClearFilter,
  });

  final bool hasFilter;
  final VoidCallback onRefresh;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = hasFilter
        ? 'No campaigns match this filter'
        : 'No campaigns available yet';
    final subtitle = hasFilter
        ? 'Try selecting "All" or pick another category to keep exploring.'
        : 'Add campaigns via the admin tools and refresh once they are approved.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (hasFilter)
                OutlinedButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear filter'),
                ),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
