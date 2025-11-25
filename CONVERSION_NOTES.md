# Blockchain Donation App - Flutter Conversion

This file documents the conversion from React/TypeScript to Flutter/Dart.

## Conversion Mapping

### Files Converted

| React/TypeScript | Flutter/Dart | Notes |
|-----------------|--------------|-------|
| index.html | pubspec.yaml | App configuration |
| main.tsx | lib/main.dart | App entry point |
| App.tsx | lib/screens/app_screen.dart | Main app logic |
| LoginScreen.tsx | lib/screens/login_screen.dart | Login UI |
| RegisterScreen.tsx | lib/screens/register_screen.dart | Registration UI |
| Header.tsx | lib/widgets/header_widget.dart | App header |
| CharityCard.tsx | lib/widgets/charity_card_widget.dart | Charity card component |
| DashboardStats.tsx | lib/widgets/dashboard_stats_widget.dart | Stats display |
| CategoryFilter.tsx | lib/widgets/category_filter_widget.dart | Category chips |
| CharityDetail.tsx | lib/screens/charity_detail_screen.dart | Charity details |
| DonationForm.tsx | lib/screens/donation_form_screen.dart | Donation form |
| ReceiptScreen.tsx | lib/screens/receipt_screen.dart | Transaction receipt |
| ProfileHub.tsx | lib/screens/profile_hub_screen.dart | Profile page |
| UpdateInformation.tsx | lib/screens/update_information_screen.dart | Edit profile |
| DonationHistory.tsx | lib/screens/donation_history_screen.dart | History view |
| AIChatbot.tsx | lib/widgets/ai_chatbot_widget.dart | Chatbot widget |
| ConnectWalletModal.tsx | lib/widgets/connect_wallet_modal.dart | Wallet modal |

### Concepts Mapped

| React/TypeScript | Flutter/Dart | Implementation |
|-----------------|--------------|----------------|
| useState | StatefulWidget + setState | Local component state |
| Props | Constructor parameters | Widget configuration |
| Component | Widget | UI building blocks |
| useEffect | initState/dispose | Lifecycle methods |
| Context/Provider | Provider package | Global state |
| CSS/Tailwind | ThemeData + inline styles | Styling |
| onClick | onTap/onPressed | Event handlers |
| className | decoration/style | Widget styling |
| map() | map() | List rendering |
| conditional rendering | Conditional expressions | UI logic |
| JSX | Widget tree | UI declaration |

### State Management

**React (useState + Context):**
```typescript
const [isLoggedIn, setIsLoggedIn] = useState(false);
```

**Flutter (Provider):**
```dart
class AppState extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  
  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }
}
```

### Styling Comparison

**React/Tailwind:**
```tsx
<div className="bg-blue-600 rounded-lg p-4">
  <h1 className="text-xl font-bold text-white">Title</h1>
</div>
```

**Flutter:**
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.blue600,
    borderRadius: BorderRadius.circular(8),
  ),
  padding: EdgeInsets.all(16),
  child: Text(
    'Title',
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
)
```

### Navigation

**React:**
```typescript
setCurrentScreen("dashboard");
```

**Flutter:**
```dart
appState.navigateTo(AppScreen.dashboard);
```

### Image Handling

**React:**
```tsx
<img src={imageUrl} alt="Charity" />
```

**Flutter:**
```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

## Key Differences

1. **Type System**: Dart has null safety built-in, TypeScript requires explicit typing
2. **UI Building**: Flutter uses widget composition instead of JSX
3. **Styling**: Flutter uses programmatic styling instead of CSS classes
4. **State**: Flutter uses ChangeNotifier pattern with Provider
5. **Async**: Flutter uses Future/async-await similar to TypeScript Promises
6. **Platform**: Flutter is native cross-platform, React is web-first

## Testing the Flutter App

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Navigate to project: `cd blockchain_donation_app`
3. Get dependencies: `flutter pub get`
4. Run: `flutter run`

## Notes

- All UI components have been converted to Material Design widgets
- State management uses Provider pattern
- Images are loaded using cached_network_image package
- Colors match the original Tailwind theme
- Responsive design maintained with LayoutBuilder and MediaQuery where needed
