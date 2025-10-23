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

  void _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    await authProvider.logout();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getText('Logged out successfully', 'सफलतापूर्वक लॉग आउट')),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

