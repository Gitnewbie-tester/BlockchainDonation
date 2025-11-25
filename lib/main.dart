import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:app_links/app_links.dart';
import 'screens/app_screen.dart' as screen;
import 'theme/app_theme.dart';
import 'utils/app_state.dart';

late AppLinks _appLinks;
StreamSubscription<Uri>? _linkSubscription;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _appLinks = AppLinks();
  runApp(const BlockchainDonationApp());
}

class BlockchainDonationApp extends StatefulWidget {
  const BlockchainDonationApp({super.key});

  @override
  State<BlockchainDonationApp> createState() => _BlockchainDonationAppState();
}

class _BlockchainDonationAppState extends State<BlockchainDonationApp> {
  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
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
    print('Processing deep link: scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
    
    // WalletConnect deep links: charitychain://wc?uri=wc:...
    if (uri.scheme == 'charitychain' && uri.host == 'wc') {
      final wcUri = uri.queryParameters['uri'];
      print('WalletConnect callback detected, wcUri=$wcUri');
      
      if (wcUri != null) {
        // The WalletConnect modal service will handle this automatically
        // Just log for debugging
        print('WalletConnect URI will be processed by modal service');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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
