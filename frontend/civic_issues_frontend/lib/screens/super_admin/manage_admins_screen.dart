import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/haryana_districts.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final admins = await ApiService.getAllAdmins(authProvider.token!);
      setState(() {
        _admins = admins;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deactivateAdmin(int adminId, String adminName) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getText('Confirm', 'पुष्टि करें')),
        content: Text(
          languageProvider.getText(
            'Are you sure you want to deactivate $adminName?',
            'क्या आप वाकई $adminName को निष्क्रिय करना चाहते हैं?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child:
                Text(languageProvider.getText('Deactivate', 'निष्क्रिय करें')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await ApiService.deactivateAdmin(authProvider.token!, adminId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getText(
                'Admin deactivated successfully',
                'एडमिन सफलतापूर्वक निष्क्रिय किया गया',
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAdmins(); // Reload list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getText(
                'Failed to deactivate admin: ${e.toString()}',
                'एडमिन को निष्क्रिय करने में विफल: ${e.toString()}',
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateAdminDialog() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final pincodeController = TextEditingController();
    String? selectedDistrict;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getText('Create New Admin', 'नया एडमिन बनाएं'),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: languageProvider.getText('Full Name', 'पूरा नाम'),
                  hint: languageProvider.getText(
                      'Enter full name', 'पूरा नाम दर्ज करें'),
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter name',
                        'कृपया नाम दर्ज करें',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: emailController,
                  label: languageProvider.getText('Email', 'ईमेल'),
                  hint:
                      languageProvider.getText('Enter email', 'ईमेल दर्ज करें'),
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter email',
                        'कृपया ईमेल दर्ज करें',
                      );
                    }
                    if (!value.contains('@')) {
                      return languageProvider.getText(
                        'Invalid email',
                        'अमान्य ईमेल',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: passwordController,
                  label: languageProvider.getText('Password', 'पासवर्ड'),
                  hint: languageProvider.getText(
                      'Enter password', 'पासवर्ड दर्ज करें'),
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.getText(
                        'Please enter password',
                        'कृपया पासवर्ड दर्ज करें',
                      );
                    }
                    if (value.length < 6) {
                      return languageProvider.getText(
                        'Password must be at least 6 characters',
                        'पासवर्ड कम से कम 6 वर्ण का होना चाहिए',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDistrict,
                  decoration: InputDecoration(
                    labelText: languageProvider.getText('District', 'जिला'),
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: HaryanaDistricts.getAllDistricts()
                      .map((district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedDistrict = value;
                  },
                  validator: (value) {
                    if (value == null) {
                      return languageProvider.getText(
                        'Please select district',
                        'कृपया जिला चुनें',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: pincodeController,
                  label: languageProvider.getText(
                      'Pincode (Optional)', 'पिनकोड (वैकल्पिक)'),
                  hint: languageProvider.getText(
                      'Enter pincode', 'पिनकोड दर्ज करें'),
                  prefixIcon: Icons.pin_drop,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.getText('Cancel', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  await ApiService.createAdmin(
                    authProvider.token!,
                    fullName: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                    district: selectedDistrict!,
                    pincode: pincodeController.text.isEmpty
                        ? null
                        : pincodeController.text,
                  );

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          languageProvider.getText(
                            'Admin created successfully',
                            'एडमिन सफलतापूर्वक बनाया गया',
                          ),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _loadAdmins(); // Reload list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          languageProvider.getText(
                            'Failed to create admin: ${e.toString()}',
                            'एडमिन बनाने में विफल: ${e.toString()}',
                          ),
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.adminColor,
            ),
            child: Text(languageProvider.getText('Create', 'बनाएं')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Manage Admins', 'एडमिन प्रबंधन'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.superAdminColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAdmins,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        languageProvider.getText('Error', 'त्रुटि'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAdmins,
                        child: Text(languageProvider.getText(
                            'Retry', 'पुन: प्रयास करें')),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.superAdminGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            languageProvider.getText(
                                'Total Admins', 'कुल एडमिन'),
                            _admins.length.toString(),
                            Icons.people,
                          ),
                          _buildStatItem(
                            languageProvider.getText('Active', 'सक्रिय'),
                            _admins
                                .where((a) => a['is_active'] == true)
                                .length
                                .toString(),
                            Icons.check_circle,
                          ),
                          _buildStatItem(
                            languageProvider.getText('Inactive', 'निष्क्रिय'),
                            _admins
                                .where((a) => a['is_active'] == false)
                                .length
                                .toString(),
                            Icons.cancel,
                          ),
                        ],
                      ),
                    ),

                    // Admins List
                    Expanded(
                      child: _admins.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.admin_panel_settings,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    languageProvider.getText(
                                      'No admins found',
                                      'कोई एडमिन नहीं मिला',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _admins.length,
                              itemBuilder: (context, index) {
                                final admin = _admins[index];
                                return _buildAdminCard(admin, languageProvider);
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAdminDialog,
        backgroundColor: AppColors.adminColor,
        icon: const Icon(Icons.add),
        label: Text(
          languageProvider.getText('Create Admin', 'एडमिन बनाएं'),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(
      Map<String, dynamic> admin, LanguageProvider languageProvider) {
    final bool isActive = admin['is_active'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isActive ? AppColors.success : AppColors.error,
                  child: Text(
                    admin['full_name'].toString()[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin['full_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        admin['email'] ?? 'N/A',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    isActive
                        ? languageProvider.getText('Active', 'सक्रिय')
                        : languageProvider.getText('Inactive', 'निष्क्रिय'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor:
                      isActive ? AppColors.success : AppColors.error,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_city,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  admin['district'] ?? 'N/A',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.badge,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'ID: ${admin['id']}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text:
                      languageProvider.getText('Deactivate', 'निष्क्रिय करें'),
                  onPressed: () =>
                      _deactivateAdmin(admin['id'], admin['full_name']),
                  backgroundColor: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

