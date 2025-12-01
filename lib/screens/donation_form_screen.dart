import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../widgets/header_widget.dart';
import '../utils/wallet_connection_helper.dart';

class DonationFormScreen extends StatefulWidget {
  const DonationFormScreen({super.key});

  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final state = Provider.of<AppState>(context, listen: false);

    try {
      // Show dialog explaining the process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening wallet to approve transaction...'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      await state.submitDonation(_amountController.text, _messageController.text);
      
      // Success - AppState will navigate to receipt screen
    } catch (error) {
      if (mounted) {
        final errorMessage = error.toString().replaceAll('Exception: ', '');
        
        // Check if this is the SUCCESS_NO_HASH case
        if (errorMessage.contains('SUCCESS_NO_HASH:')) {
          final message = errorMessage.replaceAll('SUCCESS_NO_HASH:', '');
          
          // Show SUCCESS message (not error)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Transaction Sent!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        } else if (errorMessage.contains('TRANSACTION_REJECTED:') || 
                   errorMessage.contains('cancelled by user') ||
                   errorMessage.contains('Transaction was cancelled') ||
                   errorMessage.contains('rejected by user')) {
          // User cancelled/rejected the transaction
          final message = errorMessage
              .replaceAll('TRANSACTION_REJECTED:', '')
              .replaceAll('Transaction was ', '')
              .replaceAll('by user', '')
              .trim();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.isEmpty ? 'Transaction was cancelled' : message,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Don't navigate - stay on donation form
          return;
        } else {
          // Show actual error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final charity = state.selectedCharity;
        if (charity == null) {
          return const Scaffold(
            body: Center(child: Text('No charity selected')),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              HeaderWidget(
                walletAddress: state.walletAddress,
                walletBalance: state.walletBalance,
                userName: state.user.fullName,
                onWalletClick: () => _handleWalletTap(context, state),
                onProfileClick: () => state.navigateTo(Screen.profile),
                onLogout: () => state.logout(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => state.backToDashboard(),
                            ),
                            Text(
                              'Make a Donation',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Donating to:',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  charity.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Donation Amount (ETH)',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Balance: ${state.walletBalance} ETH',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _amountController,
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  prefixText: 'ETH ',
                                  helperText: 'Note: ~0.002 ETH will be needed for gas fees',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an amount';
                                  }
                                  final amount = double.tryParse(value);
                                  if (amount == null || amount <= 0) {
                                    return 'Please enter a valid amount';
                                  }
                                  
                                  // Check against wallet balance
                                  final balance = double.tryParse(state.walletBalance) ?? 0;
                                  if (amount > balance) {
                                    return 'Insufficient balance (${state.walletBalance} ETH)';
                                  }
                                  
                                  // Check if enough for gas
                                  if (amount + 0.002 > balance) {
                                    return 'Not enough ETH for gas fees (~0.002 ETH needed)';
                                  }
                                  
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Quick amounts
                              Row(
                                children: [
                                  _QuickAmountButton(
                                    amount: '0.1',
                                    onTap: () => _amountController.text = '0.1',
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickAmountButton(
                                    amount: '0.5',
                                    onTap: () => _amountController.text = '0.5',
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickAmountButton(
                                    amount: '1.0',
                                    onTap: () => _amountController.text = '1.0',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              Text(
                                'Message (Optional)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Add a message...',
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 32),
                              
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: _isSubmitting
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Waiting for approval...'),
                                          ],
                                        )
                                      : const Text('Send Transaction'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _handleWalletTap(BuildContext context, AppState state) async {
  await ensureWalletConnection(context, state);
}

class _QuickAmountButton extends StatelessWidget {
  final String amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text('$amount ETH'),
    );
  }
}
