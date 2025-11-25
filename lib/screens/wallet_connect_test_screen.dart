import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletConnectTestScreen extends StatefulWidget {
  final WalletConnectModalService service;
  
  const WalletConnectTestScreen({
    super.key,
    required this.service,
  });

  @override
  State<WalletConnectTestScreen> createState() => _WalletConnectTestScreenState();
}

class _WalletConnectTestScreenState extends State<WalletConnectTestScreen> {
  String? _connectionUri;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _prepareConnection();
  }

  void _setupListeners() {
    widget.service.addListener(() {
      if (mounted) {
        print('WalletConnect: service state changed');
        print('  - isConnected: ${widget.service.isConnected}');
        print('  - address: ${widget.service.address}');
        
        if (widget.service.isConnected && widget.service.address != null) {
          print('WalletConnect: ✅ Connection successful, returning address');
          Navigator.of(context).pop(widget.service.address);
        }
      }
    });
  }

  Future<void> _prepareConnection() async {
    try {
      print('WalletConnect: Preparing connection URI...');
      await widget.service.rebuildConnectionUri();
      
      // Get the WalletConnect URI
      final wcUri = widget.service.wcUri;
      if (wcUri != null && wcUri.isNotEmpty) {
        setState(() {
          _connectionUri = wcUri;
        });
        print('WalletConnect: URI ready: ${wcUri.substring(0, 50)}...');
      } else {
        setState(() {
          _errorMessage = 'Failed to generate connection URI';
        });
      }
    } catch (e) {
      print('WalletConnect: Error preparing connection: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _launchMetaMask() async {
    if (_connectionUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection URI not ready')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      print('WalletConnect: Launching MetaMask with URI...');
      
      // Encode the WalletConnect URI for MetaMask deep link
      final encodedUri = Uri.encodeComponent(_connectionUri!);
      
      // MetaMask deep link format for Android
      final metamaskUri = Uri.parse('metamask://wc?uri=$encodedUri');
      
      print('WalletConnect: MetaMask URI: $metamaskUri');
      
      if (await canLaunchUrl(metamaskUri)) {
        final launched = await launchUrl(
          metamaskUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          print('WalletConnect: ✅ MetaMask launched successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('MetaMask opened. Please approve the connection.'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception('Failed to launch MetaMask');
        }
      } else {
        throw Exception('MetaMask app not installed or cannot be opened');
      }
    } catch (e) {
      print('WalletConnect: ❌ Error launching MetaMask: $e');
      setState(() {
        _errorMessage = 'Failed to open MetaMask: $e';
        _isConnecting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Wallet'),
        actions: [
          if (_connectionUri != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _connectionUri!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URI copied to clipboard')),
                );
              },
              tooltip: 'Copy URI',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Connect to MetaMask',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isConnecting) ...[
              const Text(
                'Waiting for approval in MetaMask...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ] else if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _prepareConnection,
                child: const Text('Retry'),
              ),
            ] else if (_connectionUri != null) ...[
              const Text(
                'Tap the button below to open MetaMask and approve the connection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _launchMetaMask,
                icon: const Icon(Icons.link),
                label: const Text('Open MetaMask'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ] else ...[
              const Text(
                'Preparing connection...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Alternative: Copy the URI below and paste it into MetaMask manually',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_connectionUri != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  _connectionUri!,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Make sure MetaMask is installed on your device.\nIf not installed, the "Open MetaMask" button will not work.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
