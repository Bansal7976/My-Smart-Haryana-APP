import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/haryana_logo_small.dart';
import 'client/client_dashboard_screen.dart';
import 'worker/worker_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'super_admin/super_admin_dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    // Role-based navigation
    Widget getRoleBasedScreen() {
      switch (authProvider.user!.role.toLowerCase()) {
        case 'client':
          return const ClientDashboardScreen();
        case 'worker':
          return const WorkerDashboardScreen();
        case 'admin':
          return const AdminDashboardScreen();
        case 'super_admin':
          return const SuperAdminDashboardScreen();
        default:
          return const ClientDashboardScreen(); // Default fallback
      }
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const HaryanaLogoSmall(size: 32),
            const SizedBox(width: 12),
            Text(
              languageProvider.getText('Smart Haryana', 'स्मार्ट हरियाणा'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          // Language Toggle Button
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: () {
              _showLanguageDialog(context);
            },
          ),
          // Profile Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showProfileDialog(context);
                  break;
                case 'about':
                  _showAboutDialog(context);
                  break;
                case 'logout':
                  _handleLogout(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Text(languageProvider.getText('Profile', 'प्रोफाइल')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(languageProvider.getText('About', 'के बारे में')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(languageProvider.getText('Logout', 'लॉग आउट')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: getRoleBasedScreen(),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getText('Select Language', 'भाषा चुनें')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Icon(Icons.language),
              onTap: () {
                languageProvider.setLanguage('en');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('हिंदी'),
              leading: const Icon(Icons.language),
              onTap: () {
                languageProvider.setLanguage('hi');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final user = authProvider.user;
    
    // Get user-friendly role name
    String getRoleName(String role) {
      switch (role.toLowerCase()) {
        case 'client':
          return languageProvider.getText('Citizen', 'नागरिक');
        case 'worker':
          return languageProvider.getText('Worker', 'कर्मचारी');
        case 'admin':
          return languageProvider.getText('District Admin', 'जिला व्यवस्थापक');
        case 'super_admin':
          return languageProvider.getText('State Admin', 'राज्य व्यवस्थापक');
        default:
          return role;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              languageProvider.getText('My Profile', 'मेरी प्रोफाइल'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildProfileRow(
              Icons.person_outline,
              languageProvider.getText('Full Name', 'पूरा नाम'),
              user?.name ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildProfileRow(
              Icons.email_outlined,
              languageProvider.getText('Email', 'ईमेल'),
              user?.email ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildProfileRow(
              Icons.location_city_outlined,
              languageProvider.getText('District', 'जिला'),
              user?.district ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildProfileRow(
              Icons.badge_outlined,
              languageProvider.getText('Account Type', 'खाता प्रकार'),
              getRoleName(user?.role ?? 'N/A'),
            ),
            if (user?.pincode != null && user!.pincode!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildProfileRow(
                Icons.pin_drop_outlined,
                languageProvider.getText('Pincode', 'पिनकोड'),
                user.pincode!,
              ),
            ],
            const SizedBox(height: 8),
            const Divider(),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: Text(languageProvider.getText('Close', 'बंद करें')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_city, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText('Smart Haryana', 'स्मार्ट हरियाणा'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 16),
              
              // Tagline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        languageProvider.getText(
                          'Every voice matters, every issue counts — powered by AI for a smarter Haryana.',
                          'हर आवाज़ मायने रखती है, हर मुद्दा गिनती करता है — एक स्मार्ट हरियाणा के लिए AI द्वारा संचालित।'
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // About Section
              Text(
                languageProvider.getText('About This App', 'इस ऐप के बारे में'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              
              Text(
                languageProvider.getText(
                  'Smart Haryana is an intelligent civic issue reporting platform designed to make governance transparent, efficient, and citizen-centric. Our AI-powered system ensures that every complaint is heard, tracked, and resolved promptly.',
                  'स्मार्ट हरियाणा एक बुद्धिमान नागरिक समस्या रिपोर्टिंग प्लेटफॉर्म है जो शासन को पारदर्शी, कुशल और नागरिक-केंद्रित बनाने के लिए डिज़ाइन किया गया है। हमारी AI-संचालित प्रणाली सुनिश्चित करती है कि हर शिकायत सुनी जाए, ट्रैक की जाए और तुरंत हल की जाए।'
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
              
              const SizedBox(height: 20),
              
              // Key Features
              Text(
                languageProvider.getText('Key Features', 'मुख्य विशेषताएं'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildFeatureItem(
                Icons.mic,
                languageProvider.getText('Voice-Enabled Reporting', 'आवाज-सक्षम रिपोर्टिंग'),
                languageProvider.getText('Report issues using voice in English or Hindi', 'अंग्रेजी या हिंदी में आवाज़ का उपयोग करके मुद्दों की रिपोर्ट करें'),
              ),
              _buildFeatureItem(
                Icons.smart_toy,
                languageProvider.getText('AI-Powered Assistant', 'AI-संचालित सहायक'),
                languageProvider.getText('24/7 multilingual chatbot support', '24/7 बहुभाषी चैटबॉट समर्थन'),
              ),
              _buildFeatureItem(
                Icons.location_on,
                languageProvider.getText('GPS Verification', 'GPS सत्यापन'),
                languageProvider.getText('Location-based issue tracking and verification', 'स्थान-आधारित मुद्दा ट्रैकिंग और सत्यापन'),
              ),
              _buildFeatureItem(
                Icons.security,
                languageProvider.getText('Transparent System', 'पारदर्शी प्रणाली'),
                languageProvider.getText('Real-time tracking and status updates', 'वास्तविक समय ट्रैकिंग और स्थिति अपडेट'),
              ),
              _buildFeatureItem(
                Icons.analytics,
                languageProvider.getText('Smart Analytics', 'स्मार्ट विश्लेषण'),
                languageProvider.getText('Priority-based assignment and resolution', 'प्राथमिकता-आधारित असाइनमेंट और समाधान'),
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              
              // Footer
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.favorite, color: AppColors.error, size: 20),
                    const SizedBox(height: 8),
                    Text(
                      languageProvider.getText(
                        'Built with passion for the people of Haryana',
                        'हरियाणा के लोगों के लिए जुनून के साथ बनाया गया'
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© 2024 Smart Haryana',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: Text(languageProvider.getText('Close', 'बंद करें')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    try {
      await authProvider.logout();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText('Logged out successfully', 'सफलतापूर्वक लॉग आउट')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout successful'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}




