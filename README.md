# Blockchain Donation App (Flutter)

A Flutter implementation of the Blockchain Donation App UI, converted from the original React/TypeScript version.

## Overview

This is a mobile-first blockchain-based donation application built with Flutter and Dart. The app allows users to browse charitable causes, connect their crypto wallets, and make donations using cryptocurrency.

## Features

- **User Authentication**: Login and registration screens
- **Dashboard**: Browse charitable campaigns with category filtering
- **Charity Details**: View detailed information about each charity
- **Wallet Integration**: Connect crypto wallets (MetaMask via browser, WalletConnect on mobile)
- **Donations**: Make cryptocurrency donations with custom amounts and messages
- **Transaction Receipts**: View detailed transaction information
- **Profile Management**: Update user information
- **Donation History**: Track all your past donations

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── charity.dart
│   └── donation.dart
├── screens/                  # Screen widgets
│   ├── app_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── dashboard_screen.dart
│   ├── charity_detail_screen.dart
│   ├── donation_form_screen.dart
│   ├── receipt_screen.dart
│   ├── profile_hub_screen.dart
│   ├── update_information_screen.dart
│   └── donation_history_screen.dart
├── widgets/                  # Reusable widgets
│   ├── header_widget.dart
│   ├── dashboard_stats_widget.dart
│   ├── category_filter_widget.dart
│   ├── charity_card_widget.dart
│   ├── ai_chatbot_widget.dart
│   └── connect_wallet_modal.dart
├── theme/                    # App theming
│   └── app_theme.dart
└── utils/                    # Utilities
    └── app_state.dart        # State management
```

## Dependencies

- **flutter**: SDK
- **provider**: State management
- **http**: API calls
- **web3dart**: Blockchain integration
- **cached_network_image**: Image caching
- **flutter_svg**: SVG support
- **lucide_icons_flutter**: Icons
- **intl**: Internationalization
- **url_launcher**: URL launching

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- An IDE (VS Code, Android Studio, or IntelliJ IDEA)

### Installation

1. Clone the repository:
   ```bash
   cd blockchain_donation_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Running on Different Platforms

- **Android**: `flutter run -d android`
- **iOS**: `flutter run -d ios` (requires Mac)
- **Web**: `flutter run -d chrome`
- **Windows**: `flutter run -d windows`

## State Management

The app uses **Provider** for state management. The main app state is managed in `lib/utils/app_state.dart`, which includes:

- User authentication state
- Wallet connection status
- Selected charity and category
- Donation history
- Navigation state

## Key Features Explanation

### Wallet Connection

The app simulates wallet connections by generating mock addresses. In a production app, this would integrate with actual Web3 providers using the `web3dart` package.

### MetaMask (Web)
- Run `flutter run -d chrome`.
- Click **Connect Wallet**; the modal surfaces the MetaMask option powered by `flutter_web3`.
- Approve the request inside the MetaMask browser extension.

### MetaMask (Android/iOS via WalletConnect)
- Create a WalletConnect Project ID at [https://cloud.walletconnect.com](https://cloud.walletconnect.com).
- Supply it when running the app: `flutter run --dart-define=WC_PROJECT_ID=<your_project_id>`.
   - Alternatively, hardcode it in `lib/services/wallet_service_config.dart` for local testing.
- Install the MetaMask mobile app on your emulator/device.
- Tap **Connect Wallet** in the Flutter app; it now automatically launches a WalletConnect session, deep-linking into MetaMask for approval.
- After approving, return to the Flutter app and it will continue with the connected wallet address.

### Donations

Donations create mock transactions with:
- Transaction hash
- Block number
- Gas used
- Timestamp

In production, these would be real blockchain transactions.

### Image Handling

The app uses `cached_network_image` for efficient image loading and caching from URLs.

## Conversion Notes

This Flutter app is a direct conversion from the original React/TypeScript implementation:

- React components → Flutter widgets
- TypeScript interfaces → Dart classes
- React hooks → Flutter State/Provider
- CSS/Tailwind → Flutter MaterialApp theming
- React Router → Custom navigation via AppState

## Customization

### Themes

Modify `lib/theme/app_theme.dart` to customize:
- Colors
- Typography
- Button styles
- Input decorations

### Campaign Data & Backend API

Campaigns are now loaded from PostgreSQL via the Node/Express backend (`backend/server.js`).

1. Start the backend server: `cd backend && npm install && node server.js`.
2. Seed the `campaigns` table using `POST /api/campaign` or direct SQL inserts. Required fields include `name`, `goal_eth`, `owner_address`, and `beneficiary_address` (the wallet that ultimately receives funds).
3. The Flutter app calls `GET /api/campaigns` during startup and whenever you press **Retry** on the dashboard. Progress, supporter counts, and goal tracking update automatically after each donation.

User profile mocks still live in `lib/utils/app_state.dart` for now, but campaign cards, categories, and totals are fully dynamic.

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Original Project

This is a Flutter conversion of the original Blockchain Donation App UI available at:
https://www.figma.com/design/5jEwYva8FqtYxGZNBdHAQU/Blockchain-Donation-App-UI

## License

This project is for educational purposes.

## Future Enhancements

- Real Web3 wallet integration
- Actual blockchain transactions
- Backend API integration
- Push notifications
- Multi-language support
- Dark mode
- Analytics integration
