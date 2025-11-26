import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:app_links/app_links.dart';
import 'screens/app_screen.dart' as screen;
import 'theme/app_theme.dart';
import 'utils/app_state.dart';

late AppLinks _appLinks;
StreamSubscription<Uri>? _linkSubscription;

// Global reference to WalletConnect service for deep link handling
WalletConnectModalService? _globalWalletService;

// Callback to notify when deep link is received
void Function()? _onDeepLinkReceived;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _appLinks = AppLinks();
  runApp(const BlockchainDonationApp());
}

// Function to register WalletConnect service for deep link callbacks
void registerWalletService(WalletConnectModalService service) {
  _globalWalletService = service;
  print('WalletConnect service registered for deep link handling');
}

// Function to register a callback for when deep links are received
void registerDeepLinkCallback(void Function() callback) {
  _onDeepLinkReceived = callback;
  print('Deep link callback registered');
}

class BlockchainDonationApp extends StatefulWidget {
  const BlockchainDonationApp({super.key});

  @override
  State<BlockchainDonationApp> createState() => _BlockchainDonationAppState();
}

class _BlockchainDonationAppState extends State<BlockchainDonationApp> with WidgetsBindingObserver {
  bool _isAppResumed = true;
  Timer? _resumeDelayTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinkListener();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeDelayTimer?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('\n🔄 APP LIFECYCLE STATE CHANGED: $state');
    
    if (state == AppLifecycleState.resumed) {
      print('✅ App is RESUMING from background');
      print('   Waiting 300ms for app to fully wake up before processing deep links...');
      
      _isAppResumed = false;
      
      // Give the app time to fully resume before processing deep links
      _resumeDelayTimer?.cancel();
      _resumeDelayTimer = Timer(const Duration(milliseconds: 300), () {
        _isAppResumed = true;
        print('✅ App fully resumed - ready to process deep links');
        
        // Check if we missed a connection while waking up
        if (_globalWalletService != null) {
          final connected = _globalWalletService!.isConnected;
          final address = _globalWalletService!.address;
          print('   Post-resume check: connected=$connected, address=$address');
        }
      });
    } else if (state == AppLifecycleState.paused) {
      print('⏸️  App PAUSED - likely user went to MetaMask');
      _isAppResumed = false;
    } else if (state == AppLifecycleState.inactive) {
      print('⚠️  App INACTIVE - transition state');
    }
  }

  void _initDeepLinkListener() {
    // Handle deep links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('Deep link received: $uri');
      _handleDeepLink(uri);
    }, onError: (err) {
      print('Deep link error: $err');
    });

    // Handle deep link that opened the app
    _appLinks.getInitialAppLink().then((uri) {
      if (uri != null) {
        print('Initial deep link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    print('\n' + '='*60);
    print('🔗 DEEP LINK RECEIVED');
    print('='*60);
    print('Full URI: $uri');
    print('  scheme: ${uri.scheme}');
    print('  host: ${uri.host}');
    print('  path: ${uri.path}');
    print('  query: ${uri.query}');
    print('  fragment: ${uri.fragment}');
    print('  query params: ${uri.queryParameters}');
    print('  App resumed state: $_isAppResumed');
    print('='*60 + '\n');
    
    // WalletConnect deep links: charitychain://wc or charitychain://wc?uri=wc:...
    if (uri.scheme == 'charitychain') {
      print('✅ CharityChain deep link detected');
      
      if (uri.host == 'wc' || uri.path.contains('/wc')) {
        print('🔄 WalletConnect callback detected - User returned from wallet!');
        
        // CRITICAL: Wait for app to fully resume before processing
        if (!_isAppResumed) {
          print('⏳ App still waking up, waiting 500ms before processing...');
          Future.delayed(const Duration(milliseconds: 500), () {
            _processWalletConnectDeepLink(uri);
          });
        } else {
          print('✅ App already resumed, processing immediately');
          _processWalletConnectDeepLink(uri);
        }
      }
    } else {
      print('ℹ️ Non-charitychain deep link: ${uri.scheme}');
    }
  }
  
  void _processWalletConnectDeepLink(Uri uri) {
    print('\n🔧 PROCESSING WALLETCONNECT DEEP LINK');
    
    // Notify any registered callbacks FIRST
    if (_onDeepLinkReceived != null) {
      print('📢 Triggering deep link callback...');
      _onDeepLinkReceived!();
    }
        
    if (_globalWalletService != null) {
      print('📡 WalletConnect service is available');
      
      // Check all sessions directly from web3App FIRST
      final allSessions = _globalWalletService!.web3App?.sessions.getAll();
      print('   Total sessions in web3App: ${allSessions?.length ?? 0}');
      
      if (allSessions != null && allSessions.isNotEmpty) {
        print('\n📦 SESSIONS FOUND:');
        for (var sess in allSessions) {
          print('   Topic: ${sess.topic.substring(0, 20)}...');
          print('   Peer: ${sess.peer.metadata.name}');
          if (sess.namespaces.containsKey('eip155')) {
            final accounts = sess.namespaces['eip155']?.accounts;
            print('   Accounts: $accounts');
          }
        }
      }
      
      print('   Service state:');
      print('     - isConnected: ${_globalWalletService!.isConnected}');
      print('     - address: ${_globalWalletService!.address}');
      print('     - session topic: ${_globalWalletService!.session?.topic}');
      
      // CRITICAL: Process the redirect URI
      // The WalletConnect v2 SDK should automatically handle this when the app resumes
      // but we need to give it a moment to process
      print('\n⏳ Waiting for WalletConnect to process redirect...');
      
      // Check multiple times with increasing delays
      final delays = [100, 300, 500, 1000, 2000];
      for (int i = 0; i < delays.length; i++) {
        Future.delayed(Duration(milliseconds: delays[i]), () {
          if (_globalWalletService != null) {
            final connected = _globalWalletService!.isConnected;
            final addr = _globalWalletService!.address;
            final session = _globalWalletService!.session;
            
            print('Check ${i+1}/${delays.length} (${delays[i]}ms): connected=$connected, address=$addr');
            
            if (connected && addr != null) {
              print('✅✅✅ CONNECTION SUCCESSFUL! Address: $addr');
            } else if (session != null) {
              print('📄 Session exists but address not ready yet...');
              print('   Session topic: ${session.topic}');
              print('   Namespaces: ${session.namespaces.keys.toList()}');
              
              // Try to extract address manually
              if (session.namespaces.containsKey('eip155')) {
                final accounts = session.namespaces['eip155']?.accounts;
                print('   Accounts in session: $accounts');
              }
            }
          }
        });
      }
    } else {
      print('❌❌❌ WalletConnect service NOT registered!');
      print('This is a critical error - the service should be registered before connecting.');
    }
    
    // Check for explicit URI parameter (some wallets pass this)
    final wcUri = uri.queryParameters['uri'];
    if (wcUri != null) {
      print('📋 WC URI in params: ${wcUri.substring(0, math.min(wcUri.length, 80))}...');
      print('   Full WC URI length: ${wcUri.length} characters');
    } else {
      print('⚠️ No "uri" query parameter found in deep link');
      print('   MetaMask may have sent approval via different mechanism');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: WalletConnectModalTheme(
        data: WalletConnectModalThemeData.lightMode,
        child: MaterialApp(
          title: 'Blockchain Donation App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const screen.AppScreen(),
        ),
      ),
    );
  }
}
