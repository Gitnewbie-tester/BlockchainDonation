import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show registerDeepLinkCallback;

class WalletConnectTestScreen extends StatefulWidget {
  final WalletConnectModalService service;
  
  const WalletConnectTestScreen({
    super.key,
    required this.service,
  });

  @override
  State<WalletConnectTestScreen> createState() => _WalletConnectTestScreenState();
}

class _WalletConnectTestScreenState extends State<WalletConnectTestScreen> with WidgetsBindingObserver {
  String? _connectionUri;
  bool _isConnecting = false;
  String? _errorMessage;
  String _appLifecycleState = 'active';
  Timer? _connectionTimeoutTimer;
  Timer? _pollingTimer;
  int _pollAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupListeners();
    _setupDeepLinkCallback();
    _openWalletConnectModal();
  }
  
  void _setupDeepLinkCallback() {
    // Register to be notified when deep link is received
    registerDeepLinkCallback(() {
      print('🎯 WalletConnect screen: Deep link callback received!');
      if (mounted && _isConnecting) {
        print('   App is in connecting state, checking connection immediately...');
        _checkConnection();
        
        // Also restart polling with fresh timer
        _startConnectionPolling();
      }
    });
  }
  
  Future<void> _openWalletConnectModal() async {
    // Simply show a button to open the built-in WalletConnect modal
    // The modal service handles everything automatically via the relay server
    setState(() {
      _connectionUri = 'use-button-below';
    });
  }

  @override
  void dispose() {
    _connectionTimeoutTimer?.cancel();
    _pollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle changed: $state');
    setState(() {
      _appLifecycleState = state.toString().split('.').last;
    });
    
    // When app resumes from background, start aggressive polling
    if (state == AppLifecycleState.resumed && _isConnecting) {
      print('🔄 App resumed - checking immediately then starting polling...');
      
      // Check immediately first
      _checkConnection();
      
      // Then start polling in case it takes a moment
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isConnecting) {
          _startConnectionPolling();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      // App went to background (likely to MetaMask)
      print('⏸️ App paused - user likely in MetaMask');
    }
  }

  void _checkConnection() {
    if (!mounted) return;
    
    final isConnected = widget.service.isConnected;
    final address = widget.service.address;
    final session = widget.service.session;
    
    print('🔍 Checking connection: connected=$isConnected, address=$address, session=${session?.topic}');
    
    // Check if connected via service.address
    if (isConnected && address != null && address.isNotEmpty) {
      print('✅ Connected via service.address: $address');
      _pollingTimer?.cancel();
      _connectionTimeoutTimer?.cancel();
      Navigator.of(context).pop(address);
      return;
    }
    
    // Check all sessions in the web3App directly (more reliable)
    final allSessions = widget.service.web3App?.sessions.getAll();
    if (allSessions != null && allSessions.isNotEmpty) {
      print('📦 Found ${allSessions.length} session(s) in web3App');
      
      for (final sess in allSessions) {
        print('   Session ${sess.topic}:');
        print('     Peer: ${sess.peer.metadata.name}');
        print('     Namespaces: ${sess.namespaces.keys.toList()}');
        
        if (sess.namespaces.containsKey('eip155')) {
          final accounts = sess.namespaces['eip155']?.accounts;
          print('     Accounts: $accounts');
          
          if (accounts != null && accounts.isNotEmpty) {
            final account = accounts.first;
            final parts = account.split(':');
            if (parts.length >= 3) {
              final extractedAddress = parts[2];
              print('✅✅✅ Found active session with address: $extractedAddress');
              _pollingTimer?.cancel();
              _connectionTimeoutTimer?.cancel();
              Navigator.of(context).pop(extractedAddress);
              return;
            }
          }
        }
      }
    }
    
    // Try to extract address from service.session as fallback
    if (session != null) {
      final namespaces = session.namespaces;
      print('📋 Service session namespaces: ${namespaces.keys.toList()}');
      
      if (namespaces.containsKey('eip155')) {
        final accounts = namespaces['eip155']?.accounts;
        print('👛 Accounts: $accounts');
        
        if (accounts != null && accounts.isNotEmpty) {
          final account = accounts.first;
          final parts = account.split(':');
          if (parts.length >= 3) {
            final extractedAddress = parts[2];
            print('✅ Extracted address from service session: $extractedAddress');
            _pollingTimer?.cancel();
            _connectionTimeoutTimer?.cancel();
            Navigator.of(context).pop(extractedAddress);
            return;
          }
        }
      }
    }
    
    print('⏳ No connection found yet, will keep checking...');
  }

  void _startConnectionPolling() {
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    
    // Poll more frequently - every 500ms
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _pollAttempts++;
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      print('🔍 Poll attempt $_pollAttempts (${_pollAttempts * 0.5}s)');
      
      // Check connection
      _checkConnection();
      
      // Timeout after max attempts (30 seconds = 60 attempts at 500ms)
      if (_pollAttempts >= 60) {
        print('⏱️ Polling timeout after ${_pollAttempts * 0.5} seconds');
        timer.cancel();
        _connectionTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _errorMessage = 'Connection timeout. MetaMask may not have approved. Please try again or use manual URI method.';
          });
        }
      }
    });
  }

  void _setupListeners() {
    widget.service.addListener(() {
      if (mounted) {
        print('🔔 WalletConnect: service state changed');
        print('  - isConnected: ${widget.service.isConnected}');
        print('  - address: ${widget.service.address}');
        
        // Use the unified check connection method
        if (_isConnecting) {
          _checkConnection();
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
      print('🚀 WalletConnect: Launching wallet...');
      print('📋 Connection URI: ${_connectionUri!.substring(0, 60)}...');
      
      // CRITICAL FIX: Use the WalletConnect universal link format
      // This is the CORRECT way to open MetaMask with WalletConnect v2
      final encodedUri = Uri.encodeComponent(_connectionUri!);
      
      // Try multiple connection methods in order of preference
      bool launched = false;
      
      // Method 1: MetaMask universal link (most reliable for Android)
      print('📱 Method 1: Trying MetaMask universal link...');
      try {
        final metamaskUniversal = Uri.parse('https://metamask.app.link/wc?uri=$encodedUri');
        launched = await launchUrl(
          metamaskUniversal,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print('✅ Launched via MetaMask universal link');
        }
      } catch (e) {
        print('⚠️ Universal link failed: $e');
      }
      
      // Method 2: MetaMask direct deep link
      if (!launched) {
        print('📱 Method 2: Trying MetaMask direct deep link...');
        try {
          final metamaskDeep = Uri.parse('metamask://wc?uri=$encodedUri');
          launched = await launchUrl(
            metamaskDeep,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            print('✅ Launched via MetaMask deep link');
          }
        } catch (e) {
          print('⚠️ Deep link failed: $e');
        }
      }
      
      // Method 3: Generic WalletConnect link (opens wallet chooser)
      if (!launched) {
        print('📱 Method 3: Trying generic WalletConnect link...');
        try {
          final wcLink = Uri.parse('wc:$encodedUri');
          launched = await launchUrl(
            wcLink,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            print('✅ Launched via WalletConnect link');
          }
        } catch (e) {
          print('⚠️ WalletConnect link failed: $e');
        }
      }
      
      if (launched) {
        print('✅ Wallet app launched successfully');
        
        // Start a timeout timer (2 minutes)
        _connectionTimeoutTimer?.cancel();
        _connectionTimeoutTimer = Timer(const Duration(minutes: 2), () {
          if (mounted && _isConnecting) {
            print('⏱️ Connection timeout - no response from wallet');
            _pollingTimer?.cancel();
            setState(() {
              _isConnecting = false;
              _errorMessage = 'Connection timeout. Please try again or use the manual URI copy method.';
            });
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Wallet opened. Approve the connection and the app will detect it automatically.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // None of the methods worked
        throw Exception(
          'Could not open wallet app. Please:\n\n'
          '1. Install MetaMask Mobile from Play Store/App Store\n'
          '2. Or use the "Copy URI" button and paste in MetaMask manually:\n'
          '   MetaMask → Settings → Experimental → WalletConnect\n\n'
          'Then paste the URI and approve the connection.'
        );
      }
    } catch (e) {
      print('❌ Error launching wallet: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isConnecting = false;
        });
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to Open Wallet'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  const Text(
                    'Use the manual URI copy option below as an alternative.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
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
            const SizedBox(height: 8),
            // Show app state for debugging
            Text(
              'App state: $_appLifecycleState',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_isConnecting) ...[
              const Text(
                'Waiting for approval in MetaMask...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Approve connection in MetaMask\n'
                '2. Return to this app (it will auto-detect)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking connection... ${(_pollAttempts * 0.5).toStringAsFixed(1)}s / 30s',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _pollingTimer?.cancel();
                      _connectionTimeoutTimer?.cancel();
                      setState(() {
                        _isConnecting = false;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      print('🔍 Manual connection check requested...');
                      _checkConnection();
                    },
                    child: const Text('Check Now'),
                  ),
                ],
              ),
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
                'Use the official WalletConnect button below to connect',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              // Use the OFFICIAL WalletConnect modal - this handles everything!
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    print('📱 Opening WalletConnect modal...');
                    await widget.service.open(context: context);
                    print('✅ Modal opened/closed');
                    
                    // Check connection after modal closes
                    if (widget.service.isConnected && widget.service.address != null) {
                      print('✅✅✅ CONNECTED: ${widget.service.address}');
                      Navigator.of(context).pop(widget.service.address);
                    } else {
                      print('❌ No connection established');
                    }
                  } catch (e) {
                    print('❌ Modal error: $e');
                  }
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Connect Wallet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will show a list of wallets including MetaMask.\nThe connection happens via WalletConnect relay server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blue),
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
