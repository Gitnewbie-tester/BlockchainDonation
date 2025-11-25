import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'charity_detail_screen.dart';
import 'donation_form_screen.dart';
import 'receipt_screen.dart';
import 'profile_hub_screen.dart';
import 'update_information_screen.dart';
import 'donation_history_screen.dart';

class AppScreen extends StatelessWidget {
  const AppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isLoggedIn) {
          switch (state.currentScreen) {
            case Screen.register:
              return const RegisterScreen();
            default:
              return const LoginScreen();
          }
        }
        
        switch (state.currentScreen) {
          case Screen.dashboard:
            return const DashboardScreen();
          case Screen.charityDetail:
            return const CharityDetailScreen();
          case Screen.donate:
            return const DonationFormScreen();
          case Screen.receipt:
            return const ReceiptScreen();
          case Screen.profile:
            return const ProfileHubScreen();
          case Screen.updateInfo:
            return const UpdateInformationScreen();
          case Screen.donationHistory:
            return const DonationHistoryScreen();
          default:
            return const DashboardScreen();
        }
      },
    );
  }
}
