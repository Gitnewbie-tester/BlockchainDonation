import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _emailShakeController;
  late AnimationController _passwordShakeController;
  late Animation<double> _emailShakeAnimation;
  late Animation<double> _passwordShakeAnimation;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    
    // Email shake animation
    _emailShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _emailShakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_emailShakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _emailShakeController.reverse();
        }
      });
    
    // Password shake animation
    _passwordShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _passwordShakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_passwordShakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _passwordShakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _emailShakeController.dispose();
    _passwordShakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (error) {
      if (mounted) {
        final errorMsg = error.toString()
            .replaceAll('ApiException: ', '')
            .replaceAll('Exception: ', '');
        
        // Detect if it's an email or password error
        final lowerMsg = errorMsg.toLowerCase();
        final isEmailError = lowerMsg.contains('email') || 
                            lowerMsg.contains('user not found') ||
                            lowerMsg.contains('not found');
        final isPasswordError = lowerMsg.contains('password') || 
                               lowerMsg.contains('invalid');
        
        setState(() {
          if (isPasswordError && !isEmailError) {
            // Password wrong
            _passwordError = errorMsg;
            _emailError = null;
            _passwordShakeController.forward(from: 0);
          } else if (isEmailError) {
            // Email not found or invalid
            _emailError = errorMsg;
            _passwordError = null;
            _emailShakeController.forward(from: 0);
          } else {
            // Generic error - show on both or password field
            _passwordError = errorMsg;
            _emailError = null;
            _passwordShakeController.forward(from: 0);
          }
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _emailError == null && _passwordError == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFF6FF), // blue-50
              Color(0xFFF0FDF4), // green-50
              Color(0xFFDBEAFE), // blue-100
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Column(
                  children: [
                    // Logo and Branding
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.blue600, AppTheme.green600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CharityChain',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 32),
                    
                    // Login Form Card
                    Card(
                        color: Colors.white.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Text(
                                  'Login',
                                  style: Theme.of(context).textTheme.displaySmall,
                                ),
                                const SizedBox(height: 24),
                                
                                // Email Field with inline error
                                AnimatedBuilder(
                                  animation: _emailShakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_emailShakeAnimation.value, 0),
                                      child: child,
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          hintText: 'Enter your @gmail.com email',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _emailError != null ? const Color(0xFFDC2626) : Colors.grey,
                                              width: _emailError != null ? 2 : 1,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _emailError != null ? const Color(0xFFDC2626) : Colors.grey,
                                              width: _emailError != null ? 2 : 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _emailError != null ? const Color(0xFFDC2626) : AppTheme.blue600,
                                              width: 2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                          ),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        onChanged: (_) {
                                          if (_emailError != null) {
                                            setState(() => _emailError = null);
                                          }
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          // Gmail validation regex
                                          final gmailRegex = RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9._%+-]{0,62}[a-zA-Z0-9])?@gmail\.com$', caseSensitive: false);
                                          if (!gmailRegex.hasMatch(value.trim())) {
                                            return 'Email must be a valid @gmail.com address';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_emailError != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            border: Border.all(color: const Color(0xFFDC2626)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _emailError!,
                                                  style: const TextStyle(
                                                    color: Color(0xFF991B1B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                  const SizedBox(height: 16),
                                
                                // Password Field with inline error
                                AnimatedBuilder(
                                  animation: _passwordShakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_passwordShakeAnimation.value, 0),
                                      child: child,
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _passwordController,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          hintText: 'Enter your password',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _passwordError != null ? const Color(0xFFDC2626) : Colors.grey,
                                              width: _passwordError != null ? 2 : 1,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _passwordError != null ? const Color(0xFFDC2626) : Colors.grey,
                                              width: _passwordError != null ? 2 : 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: _passwordError != null ? const Color(0xFFDC2626) : AppTheme.blue600,
                                              width: 2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                          ),
                                        ),
                                        obscureText: true,
                                        onChanged: (_) {
                                          if (_passwordError != null) {
                                            setState(() => _passwordError = null);
                                          }
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_passwordError != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            border: Border.all(color: const Color(0xFFDC2626)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _passwordError!,
                                                  style: const TextStyle(
                                                    color: Color(0xFF991B1B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.blue600, AppTheme.green600],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: Text(
                                          _isLoading ? 'Signing in...' : 'Login',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Forgot Password
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.blue600,
                                ),
                                child: const Text('Forgot Password?'),
                              ),
                              ],
                            ),
                          ),
                        ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Trust Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security, color: AppTheme.green600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Secure',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 24),
                        const Icon(Icons.account_balance_wallet, color: AppTheme.blue600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Web3 Ready',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => appState.navigateTo(Screen.register),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.blue600,
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
