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
  final _districtController = TextEditingController();
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
    _districtController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'district': _selectedDistrict ?? '',
        'pincode': _pincodeController.text.trim(),
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false)
                .getText('Registration successful!', 'पंजीकरण सफल!')),
            backgroundColor: Colors.green,
          ),
        );
        // Navigation will be handled automatically by the main app
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false)
                .getText('Registration failed', 'पंजीकरण असफल')}: ${authProvider.error ?? 'Unknown error'}'),
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Create Account', 'खाता बनाएं'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Smart Haryana Logo
                const HaryanaLogo(
                  size: 80,
                  showText: true,
                  text: 'Smart Haryana',
                ),
                
                const SizedBox(height: 20),
                
                // Title
                Text(
                  languageProvider.getText(
                    'Join Smart Haryana',
                    'स्मार्ट हरियाणा में शामिल हों'
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  languageProvider.getText(
                    'Help us make Haryana better',
                    'हरियाणा को बेहतर बनाने में हमारी मदद करें'
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Full Name Field
                CustomTextField(
                  controller: _fullNameController,
                  label: languageProvider.getText('Full Name', 'पूरा नाम'),
                  hint: languageProvider.getText('Enter your full name', 'अपना पूरा नाम दर्ज करें'),
                  prefixIcon: Icons.person_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter your full name',
                        'कृपया अपना पूरा नाम दर्ज करें'
                      );
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Email Field
                CustomTextField(
                  controller: _emailController,
                  label: languageProvider.getText('Email', 'ईमेल'),
                  hint: languageProvider.getText('Enter your email', 'अपना ईमेल दर्ज करें'),
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter your email',
                        'कृपया अपना ईमेल दर्ज करें'
                      );
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return languageProvider.getText(
                        'Please enter a valid email',
                        'कृपया एक वैध ईमेल दर्ज करें'
                      );
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // District Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getText('District', 'जिला'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedDistrict,
                        decoration: InputDecoration(
                          hintText: languageProvider.getText('Select your district', 'अपना जिला चुनें'),
                          hintStyle: const TextStyle(color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: _haryanaDistricts.map((district) {
                          return DropdownMenuItem<String>(
                            value: district,
                            child: Text(district),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageProvider.getText(
                              'Please select your district',
                              'कृपया अपना जिला चुनें'
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Pincode Field
                CustomTextField(
                  controller: _pincodeController,
                  label: languageProvider.getText('Pincode', 'पिनकोड'),
                  hint: languageProvider.getText('Enter your pincode', 'अपना पिनकोड दर्ज करें'),
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter your pincode',
                        'कृपया अपना पिनकोड दर्ज करें'
                      );
                    }
                    if (value.length != 6) {
                      return languageProvider.getText(
                        'Pincode must be 6 digits',
                        'पिनकोड 6 अंकों का होना चाहिए'
                      );
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Password Field
                CustomTextField(
                  controller: _passwordController,
                  label: languageProvider.getText('Password', 'पासवर्ड'),
                  hint: languageProvider.getText('Enter your password', 'अपना पासवर्ड दर्ज करें'),
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  onSuffixTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter your password',
                        'कृपया अपना पासवर्ड दर्ज करें'
                      );
                    }
                    if (value.length < 8) {
                      return languageProvider.getText(
                        'Password must be at least 8 characters',
                        'पासवर्ड कम से कम 8 अक्षर का होना चाहिए'
                      );
                    }
                    // Check for uppercase letter
                    if (!value.contains(RegExp(r'[A-Z]'))) {
                      return languageProvider.getText(
                        'Password must contain at least one uppercase letter',
                        'पासवर्ड में कम से कम एक बड़ा अक्षर होना चाहिए'
                      );
                    }
                    // Check for lowercase letter
                    if (!value.contains(RegExp(r'[a-z]'))) {
                      return languageProvider.getText(
                        'Password must contain at least one lowercase letter',
                        'पासवर्ड में कम से कम एक छोटा अक्षर होना चाहिए'
                      );
                    }
                    // Check for digit
                    if (!value.contains(RegExp(r'[0-9]'))) {
                      return languageProvider.getText(
                        'Password must contain at least one digit',
                        'पासवर्ड में कम से कम एक अंक होना चाहिए'
                      );
                    }
                    // Check for special character
                    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                      return languageProvider.getText(
                        'Password must contain at least one special character',
                        'पासवर्ड में कम से कम एक विशेष वर्ण होना चाहिए'
                      );
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Confirm Password Field
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: languageProvider.getText('Confirm Password', 'पासवर्ड की पुष्टि करें'),
                  hint: languageProvider.getText('Confirm your password', 'अपने पासवर्ड की पुष्टि करें'),
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  onSuffixTap: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please confirm your password',
                        'कृपया अपने पासवर्ड की पुष्टि करें'
                      );
                    }
                    if (value != _passwordController.text) {
                      return languageProvider.getText(
                        'Passwords do not match',
                        'पासवर्ड मेल नहीं खाते'
                      );
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Register Button
                CustomButton(
                  text: languageProvider.getText('Create Account', 'खाता बनाएं'),
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                ),
                
                const SizedBox(height: 24),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      languageProvider.getText(
                        "Already have an account? ",
                        'पहले से खाता है? '
                      ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        languageProvider.getText('Sign In', 'साइन इन'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
