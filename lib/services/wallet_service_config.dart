import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

const String walletConnectProjectId = String.fromEnvironment(
  'WC_PROJECT_ID',
  defaultValue: '',
);

const String walletConnectRelayUrl = String.fromEnvironment(
  'WC_RELAY_URL',
  defaultValue: 'wss://relay.walletconnect.com',
);

const PairingMetadata walletConnectMetadata = PairingMetadata(
  name: 'CharityChain',
  description: 'Transparent blockchain donations from your phone.',
  url: 'https://charitychain.app',
  icons: [
    'https://raw.githubusercontent.com/github/explore/main/topics/flutter/flutter.png',
  ],
  redirect: Redirect(
    native: 'charitychain://wc',
    universal: 'https://charitychain.app/wc',
  ),
);
