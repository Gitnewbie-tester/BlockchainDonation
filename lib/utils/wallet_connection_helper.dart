import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/wallet_service.dart';
import '../widgets/connect_wallet_modal.dart';
import 'app_state.dart';

Future<void> ensureWalletConnection(BuildContext context, AppState state) async {
  if (state.walletAddress.isNotEmpty) {
    state.navigateTo(Screen.profile);
    return;
  }

  if (kIsWeb && walletConnector.isMetaMaskAvailable) {
    await _showWebWalletModal(context, state);
    return;
  }

  if (walletConnector.isWalletConnectAvailable) {
    await _connectViaWalletConnect(context, state);
    return;
  }

  if (kIsWeb) {
    await _showWebWalletModal(context, state);
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'No supported wallets detected. Install MetaMask or configure WalletConnect to proceed.',
      ),
    ),
  );
}

Future<void> _showWebWalletModal(BuildContext context, AppState state) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return ConnectWalletModal(
        onClose: () => Navigator.of(sheetContext).pop(),
        onConnect: (address) {
          state.connectWallet(address);
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wallet connected.')),
          );
        },
      );
    },
  );
}

Future<void> _connectViaWalletConnect(BuildContext context, AppState state) async {
  try {
    final address = await walletConnector.connectWithWalletConnect(context);
    if (!context.mounted) return;
    state.connectWallet(address);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet connected.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wallet connection failed: $error')),
    );
  }
}
