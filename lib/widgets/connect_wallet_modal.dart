import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class ConnectWalletModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String) onConnect;

  const ConnectWalletModal({
    super.key,
    required this.onClose,
    required this.onConnect,
  });

  @override
  State<ConnectWalletModal> createState() => _ConnectWalletModalState();
}

class _ConnectWalletModalState extends State<ConnectWalletModal> {
  bool _isMetaMaskConnecting = false;
  bool _isWalletConnectConnecting = false;
  String? _error;

  Future<void> _connectMetaMask() async {
    if (_isMetaMaskConnecting) return;

    setState(() {
      _isMetaMaskConnecting = true;
      _error = null;
    });

    try {
      if (!walletConnector.isMetaMaskAvailable) {
        throw WalletException('MetaMask extension not detected. Install MetaMask and refresh the page.');
      }

      final address = await walletConnector.connectMetaMask();
      if (!mounted) return;
      widget.onConnect(address);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isMetaMaskConnecting = false);
      }
    }
  }

  Future<void> _connectWalletConnect() async {
    if (_isWalletConnectConnecting) return;

    setState(() {
      _isWalletConnectConnecting = true;
      _error = null;
    });

    try {
      final address = await walletConnector.connectWithWalletConnect(context);
      if (!mounted) return;
      widget.onConnect(address);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isWalletConnectConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMetaMaskAvailable = walletConnector.isMetaMaskAvailable;
    final bool isWalletConnectAvailable = walletConnector.isWalletConnectAvailable;
    final bool hasAnyConnector = isMetaMaskAvailable || isWalletConnectAvailable;

    final String subtitle = isMetaMaskAvailable
        ? 'Use your MetaMask browser wallet to link a donation address.'
        : isWalletConnectAvailable
            ? 'Use WalletConnect to open MetaMask Mobile or any supported wallet.'
            : 'No compatible wallets detected for this platform yet.';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connect Wallet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.slate600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isMetaMaskAvailable)
            _WalletOption(
              icon: Icons.account_balance_wallet,
              name: 'MetaMask',
              subtitle: 'A MetaMask prompt will appear in your browser.',
              isLoading: _isMetaMaskConnecting,
              onTap: _isMetaMaskConnecting ? null : _connectMetaMask,
            ),
          if (isMetaMaskAvailable && isWalletConnectAvailable)
            const SizedBox(height: 12),
          if (isWalletConnectAvailable)
            _WalletOption(
              icon: Icons.qr_code_scanner,
              name: 'WalletConnect',
              subtitle: 'Choose MetaMask Mobile or another wallet via WalletConnect.',
              isLoading: _isWalletConnectConnecting,
              onTap: _isWalletConnectConnecting ? null : _connectWalletConnect,
            ),
          if (!hasAnyConnector)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.slate200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Install MetaMask (web) or configure WalletConnect (mobile) to proceed.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.red600),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onClose,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _WalletOption extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const _WalletOption({
    required this.icon,
    required this.name,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.slate200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.blue600),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.slate500),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
