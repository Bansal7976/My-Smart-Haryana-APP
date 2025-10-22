import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/haryana_logo.dart';
import 'language_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false)
                .getText('Login successful!', 'लॉगिन सफल!')),
            backgroundColor: Colors.green,
          ),
        );
        // Navigation will be handled automatically by the main app
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${Provider.of<LanguageProvider>(context, listen: false).getText('Login failed', 'लॉगिन असफल')}: ${authProvider.error ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _quickLogin(String email, String password) async {
    _emailController.text = email;
    _passwordController.text = password;
    await _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Smart Haryana Logo
                const HaryanaLogo(
                  size: 120,
                  showText: true,
                  text: 'Smart Haryana',
                ),

                const SizedBox(height: 40),

                // Welcome Text
                Text(
                  languageProvider.getText('Welcome to Smart Haryana',
                      'स्मार्ट हरियाणा में आपका स्वागत है'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  languageProvider.getText(
                      'Your Gateway to Better Civic Services',
                      'बेहतर नागरिक सेवाओं का आपका प्रवेश द्वार'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Email Field
                CustomTextField(
                  controller: _emailController,
                  label: languageProvider.getText('Email', 'ईमेल'),
                  hint: languageProvider.getText(
                      'Enter your email', 'अपना ईमेल दर्ज करें'),
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText('Please enter your email',
                          'कृपया अपना ईमेल दर्ज करें');
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return languageProvider.getText(
                          'Please enter a valid email',
                          'कृपया एक वैध ईमेल दर्ज करें');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                CustomTextField(
                  controller: _passwordController,
                  label: languageProvider.getText('Password', 'पासवर्ड'),
                  hint: languageProvider.getText(
                      'Enter your password', 'अपना पासवर्ड दर्ज करें'),
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  onSuffixTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                          'Please enter your password',
                          'कृपया अपना पासवर्ड दर्ज करें');
                    }
                    if (value.length < 8) {
                      return languageProvider.getText(
                          'Password must be at least 8 characters',
                          'पासवर्ड कम से कम 8 अक्षर का होना चाहिए');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Login Button
                CustomButton(
                  text: languageProvider.getText('Login', 'लॉगिन'),
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Quick Login Section
                Text(
                  languageProvider.getText('Quick Login:', 'त्वरित लॉगिन:'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 12),

                // Quick Login Buttons
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _quickLogin('client@haryana.gov.in', 'client123'),
                    icon: const Icon(Icons.person, size: 18),
                    label: Text(languageProvider.getText(
                        'Login as Citizen', 'नागरिक के रूप में लॉगिन')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.clientColor,
                      side: BorderSide(color: AppColors.clientColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _quickLogin('worker@haryana.gov.in', 'worker123'),
                    icon: const Icon(Icons.work, size: 18),
                    label: Text(languageProvider.getText(
                        'Login as Worker', 'कार्यकर्ता के रूप में लॉगिन')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.workerColor,
                      side: BorderSide(color: AppColors.workerColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _quickLogin('admin@haryana.gov.in', 'admin123'),
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: Text(languageProvider.getText(
                        'Login as Admin', 'एडमिन के रूप में लॉगिन')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.adminColor,
                      side: BorderSide(color: AppColors.adminColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      languageProvider.getText(
                          "Don't have an account? ", 'खाता नहीं है? '),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const LanguageSelectionScreen(),
                          ),
                        );
                      },
                      child: Text(
                        languageProvider.getText('Sign Up', 'साइन अप'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Language Selection
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LanguageSelectionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.language, size: 18),
                    label: Text(
                      languageProvider.getText('Change Language', 'भाषा बदलें'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
