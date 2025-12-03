import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'token_info_dialog.dart';

class HeaderWidget extends StatelessWidget {
  final String walletAddress;
  final String walletBalance;
  final String userName;
  final String tokenBalance;
  final VoidCallback onWalletClick;
  final VoidCallback onProfileClick;
  final VoidCallback onLogout;

  const HeaderWidget({
    super.key,
    required this.walletAddress,
    required this.walletBalance,
    required this.userName,
    required this.tokenBalance,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // User Profile Button (at far left) - direct navigation
            InkWell(
              onTap: onProfileClick,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.blue600,
                child: Text(
                  _initialFromName(userName),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            
            // Token and Wallet Section (at far right)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Token Display (Clickable)
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => TokenInfoDialog(currentBalance: tokenBalance),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF3E8FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, size: 16, color: Color(0xFF9333EA)),
                        const SizedBox(width: 6),
                        Text(
                          tokenBalance,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B21A8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'CCT',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9333EA),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF9333EA)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
