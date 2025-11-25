# WalletConnect Deep Link Setup

## Changes Made

### 1. Android Deep Link Configuration
**File:** `android/app/src/main/AndroidManifest.xml`

Added deep link intent filter to capture WalletConnect callbacks:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="charitychain"/>
    <data android:host="wc"/>
</intent-filter>
```

This allows the app to handle URLs like: `charitychain://wc?...`

### 2. Redirect Configuration
**File:** `lib/services/wallet_service_config.dart`

Added `Redirect` to WalletConnect metadata:
```dart
redirect: Redirect(
  native: 'charitychain://wc',
  universal: 'https://charitychain.app/wc',
),
```

This tells MetaMask where to redirect after approval.

### 3. Deep Link Dependency
**File:** `pubspec.yaml`

Added `uni_links` package for handling incoming deep links:
```yaml
uni_links: ^0.5.1
```

## How It Works

1. **User taps WalletConnect** → Modal opens
2. **User selects MetaMask** → MetaMask launches with connection request
3. **User approves in MetaMask** → MetaMask redirects to `charitychain://wc?session=...`
4. **Android OS** recognizes the deep link and reopens your Flutter app
5. **WalletConnect SDK** automatically handles the callback URI
6. **Your app** receives the wallet address from the session

## Testing Steps

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --dart-define=WC_PROJECT_ID=52aa65a43d9f23d950d3daaaa3642979
   ```

2. **Test connection flow:**
   - Tap "Connect Wallet" → WalletConnect
   - Select MetaMask from the list
   - Approve in MetaMask
   - **Don't manually switch back** - let Android handle the deep link
   - Your app should reopen automatically and complete the connection

## Expected Console Output

```
WalletConnect: rebuilding URI and opening modal
WalletConnect: modal opened, awaiting address
WalletConnect: [1s] isOpen=true connected=false hasSession=false address=null
WalletConnect: [2s] isOpen=true connected=false hasSession=false address=null
WalletConnect: new session detected, parsing namespaces...
WalletConnect: available namespaces: eip155
WalletConnect: eip155 accounts: [eip155:1:0xYourAddress...]
WalletConnect: parsing account: eip155:1:0xYourAddress...
WalletConnect: ✓ extracted address from session: 0xYourAddress...
WalletConnect: closing modal (isOpen=false)
```

## Troubleshooting

### If MetaMask doesn't redirect back:
- Make sure you approved the connection (not rejected)
- Don't manually press Back in MetaMask
- Let MetaMask finish and tap "Return to CharityChain" if prompted
- Android should automatically switch apps via the deep link

### If still timing out:
- Reset MetaMask: Settings → Advanced → Reset Account
- Clear app data: Android Settings → Apps → CharityChain → Clear Data
- Reinstall both apps
- Make sure emulator has internet connectivity

### Check deep link registration:
```bash
adb shell dumpsys package com.example.blockchain_donation_app | grep -A 5 "charitychain"
```

Should show the registered intent filter.

## Alternative: Manual Deep Link Listening

If automatic handling doesn't work, you can manually listen for deep links in your main app:

```dart
import 'package:uni_links/uni_links.dart';
import 'dart:async';

class MyApp extends StatefulWidget {
  // ...
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    // Handle initial deep link if app was closed
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        print('App opened with: $initialUri');
      }
    } catch (e) {
      print('Failed to get initial URI: $e');
    }

    // Listen for deep links while app is running
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print('Received deep link: $uri');
        // WalletConnect SDK handles this automatically
      }
    }, onError: (err) {
      print('Deep link error: $err');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

## Notes

- The `uni_links` package is discontinued but still works for this use case
- Modern alternative is `app_links` but requires more setup
- WalletConnect v2 SDK automatically handles the deep link callback
- The redirect configuration in metadata is critical for MetaMask to know where to send the user
