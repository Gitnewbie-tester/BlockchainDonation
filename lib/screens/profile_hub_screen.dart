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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => state.navigateTo(Screen.dashboard),
            ),
            title: const Text('Profile', style: TextStyle(color: Colors.white)),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.blue600, AppTheme.green600],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.blue600.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
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
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.slate800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.user.email,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Wallet Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.blue50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet, color: AppTheme.blue600),
                              const SizedBox(width: 8),
                              Text(
                                'Wallet Connection',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.blue600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          title: Text(
                            state.walletAddress.isEmpty
                                ? 'Not connected'
                                : '${state.walletAddress.substring(0, 6)}...${state.walletAddress.substring(state.walletAddress.length - 4)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: state.walletAddress.isEmpty
                              ? null
                              : Text(
                                  'Balance: ${state.walletBalance} ETH',
                                  style: TextStyle(color: AppTheme.green600, fontWeight: FontWeight.bold),
                                ),
                          trailing: state.walletAddress.isEmpty
                              ? null
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    await state.disconnectWallet();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Wallet disconnected'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text('Disconnect'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.red600,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Account Settings
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.blue600, AppTheme.green600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => state.logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
