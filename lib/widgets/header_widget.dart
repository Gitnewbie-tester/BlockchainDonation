import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeaderWidget extends StatelessWidget {
  final String walletAddress;
  final String walletBalance;
  final String userName;
  final VoidCallback onWalletClick;
  final VoidCallback onProfileClick;
  final VoidCallback onLogout;

  const HeaderWidget({
    super.key,
    required this.walletAddress,
    required this.walletBalance,
    required this.userName,
    required this.onWalletClick,
    required this.onProfileClick,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Wallet Button
            if (walletAddress.isNotEmpty)
              _WalletButton(
                address: walletAddress,
                balance: walletBalance,
                onClick: onWalletClick,
              )
            else
              OutlinedButton.icon(
                onPressed: onWalletClick,
                icon: const Icon(Icons.account_balance_wallet, size: 16),
                label: const Text('Connect Wallet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.blue600,
                  side: const BorderSide(color: AppTheme.blue200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            const SizedBox(width: 12),
            
            // User Profile Menu
            PopupMenuButton(
              offset: const Offset(0, 40),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.blue600,
                child: Text(
                  _initialFromName(userName),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: onProfileClick,
                  child: const Row(
                    children: [
                      Icon(Icons.person, size: 16),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: onLogout,
                  child: const Row(
                    children: [
                      Icon(Icons.logout, size: 16, color: AppTheme.red600),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: AppTheme.red600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _initialFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'U';
  return trimmed.substring(0, 1).toUpperCase();
}

class _WalletButton extends StatelessWidget {
  final String address;
  final String balance;
  final VoidCallback onClick;

  const _WalletButton({
    required this.address,
    required this.balance,
    required this.onClick,
  });

  String get _label {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onClick,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppTheme.green50,
        foregroundColor: AppTheme.green700,
        side: const BorderSide(color: AppTheme.green200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '$balance ETH',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
