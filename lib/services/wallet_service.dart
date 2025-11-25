import 'wallet_service_base.dart';
import 'wallet_service_stub.dart'
    if (dart.library.html) 'wallet_service_web.dart'
    if (dart.library.io) 'wallet_service_mobile.dart';

export 'wallet_service_base.dart';

final WalletConnector walletConnector = createWalletConnector();
