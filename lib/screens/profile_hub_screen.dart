import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../theme/app_theme.dart';

class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => state.navigateTo(Screen.dashboard),
            ),
            title: const Text('Profile'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.blue600,
                          child: Text(
                            _initialFromName(state.user.fullName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.user.fullName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.user.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Member since ${state.user.joinDate}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Wallet Section
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet),
                        title: const Text('Wallet'),
                        subtitle: Text(
                          state.walletAddress.isEmpty
                              ? 'Not connected'
                              : '${state.walletAddress.substring(0, 6)}...${state.walletAddress.substring(state.walletAddress.length - 4)}',
                        ),
                        trailing: state.walletAddress.isEmpty
                            ? null
                            : TextButton(
                                onPressed: () => state.disconnectWallet(),
                                child: const Text('Disconnect'),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Account Settings
                Card(
                  child: Column(
                    children: [
                      _ProfileMenuItem(
                        icon: Icons.person,
                        title: 'Update Information',
                        onTap: () => state.navigateTo(Screen.updateInfo),
                      ),
                      const Divider(height: 1),
                      _ProfileMenuItem(
                        icon: Icons.history,
                        title: 'Donation History',
                        onTap: () => state.navigateTo(Screen.donationHistory),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => state.logout(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.red600,
                      side: const BorderSide(color: AppTheme.red600),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.slate600),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

String _initialFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'C'; // Default CharityChain initial
  }
  return trimmed.substring(0, 1).toUpperCase();
}
