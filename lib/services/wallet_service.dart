// Mobile-only wallet service (removed web support)
import 'wallet_service_base.dart';
import 'wallet_service_mobile.dart';

export 'wallet_service_base.dart';

final WalletConnector walletConnector = createWalletConnector();
