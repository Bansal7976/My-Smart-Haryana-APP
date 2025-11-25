import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/haryana_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pincodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedDistrict;

  final List<String> _haryanaDistricts = [
    'Ambala',
    'Bhiwani',
    'Charkhi Dadri',
    'Faridabad',
    'Fatehabad',
    'Gurugram',
    'Hisar',
    'Jhajjar',
    'Jind',
    'Kaithal',
    'Karnal',
    'Kurukshetra',
    'Mahendragarh',
    'Nuh',
    'Palwal',
    'Panchkula',
    'Panipat',
    'Rewari',
    'Rohtak',
    'Sirsa',
    'Sonipat',
    'Yamunanagar',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await authProvider.register({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'district': _selectedDistrict ?? '',
        'pincode': _pincodeController.text.trim(),
      });

      if (!mounted) return;

      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText(
                'Registration successful!', 'पंजीकरण सफल!')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.error ??
                languageProvider.getText(
                    'Registration failed', 'पंजीकरण असफल')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        languageProvider.getText(
                            'Create Account', 'खाता बनाएं'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        const HaryanaLogo(size: 60, showText: false),
                        const SizedBox(height: 16),

                        Text(
                          languageProvider.getText('Join Smart Haryana',
                              'स्मार्ट हरियाणा में शामिल हों'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Form Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: _fullNameController,
                                label: languageProvider.getText(
                                    'Full Name', 'पूरा नाम'),
                                hint: languageProvider.getText(
                                    'Enter your full name',
                                    'अपना पूरा नाम दर्ज करें'),
                                prefixIcon: Icons.person_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return languageProvider.getText(
                                        'Please enter your full name',
                                        'कृपया अपना पूरा नाम दर्ज करें');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: _emailController,
                                label:
                                    languageProvider.getText('Email', 'ईमेल'),
                                hint: languageProvider.getText(
                                    'Enter your email', 'अपना ईमेल दर्ज करें'),
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return languageProvider.getText(
                                        'Please enter your email',
                                        'कृपया अपना ईमेल दर्ज करें');
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return languageProvider.getText(
                                        'Please enter a valid email',
                                        'कृपया एक वैध ईमेल दर्ज करें');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // District Dropdown
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: languageProvider.getText(
                                      'District', 'जिला'),
                                  hintText: languageProvider.getText(
                                      'Select your district',
                                      'अपना जिला चुनें'),
                                  prefixIcon:
                                      const Icon(Icons.location_city_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                items: _haryanaDistricts.map((district) {
                                  return DropdownMenuItem(
                                      value: district, child: Text(district));
                                }).toList(),
                                initialValue: _selectedDistrict,
                                onChanged: (value) {
                                  setState(() => _selectedDistrict = value);
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return languageProvider.getText(
                                        'Please select your district',
                                        'कृपया अपना जिला चुनें');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: _pincodeController,
                                label: languageProvider.getText(
                                    'Pincode', 'पिनकोड'),
                                hint: languageProvider.getText(
                                    'Enter your pincode',
                                    'अपना पिनकोड दर्ज करें'),
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.location_on_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return languageProvider.getText(
                                        'Please enter your pincode',
                                        'कृपया अपना पिनकोड दर्ज करें');
                                  }
                                  if (value.length != 6) {
                                    return languageProvider.getText(
                                        'Pincode must be 6 digits',
                                        'पिनकोड 6 अंकों का होना चाहिए');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: _passwordController,
                                label: languageProvider.getText(
                                    'Password', 'पासवर्ड'),
                                hint: languageProvider.getText(
                                    'Create a password', 'पासवर्ड बनाएं'),
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outlined,
                                suffixIcon: _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                onSuffixTap: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return languageProvider.getText(
                                        'Please enter a password',
                                        'कृपया पासवर्ड दर्ज करें');
                                  }
                                  if (value.length < 8) {
                                    return languageProvider.getText(
                                        'Password must be at least 8 characters',
                                        'पासवर्ड कम से कम 8 अक्षर का होना चाहिए');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: _confirmPasswordController,
                                label: languageProvider.getText(
                                    'Confirm Password',
                                    'पासवर्ड की पुष्टि करें'),
                                hint: languageProvider.getText(
                                    'Confirm your password',
                                    'अपने पासवर्ड की पुष्टि करें'),
                                obscureText: _obscureConfirmPassword,
                                prefixIcon: Icons.lock_outlined,
                                suffixIcon: _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                onSuffixTap: () {
                                  setState(() => _obscureConfirmPassword =
                                      !_obscureConfirmPassword);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return languageProvider.getText(
                                        'Please confirm your password',
                                        'कृपया अपने पासवर्ड की पुष्टि करें');
                                  }
                                  if (value != _passwordController.text) {
                                    return languageProvider.getText(
                                        'Passwords do not match',
                                        'पासवर्ड मेल नहीं खाते');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              CustomButton(
                                text: languageProvider.getText(
                                    'Create Account', 'खाता बनाएं'),
                                onPressed: _isLoading ? null : _handleRegister,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              languageProvider.getText(
                                  "Already have an account? ",
                                  'पहले से खाता है? '),
                              style:
                                  const TextStyle(color: AppColors.textPrimary),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8)),
                              child: Text(
                                languageProvider.getText('Sign In', 'साइन इन'),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }
}
