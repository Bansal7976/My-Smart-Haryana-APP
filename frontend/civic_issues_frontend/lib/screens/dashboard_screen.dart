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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getText('Profile', 'प्रोफाइल')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow(languageProvider.getText('Name', 'नाम'), authProvider.user?.name ?? 'N/A'),
            _buildProfileRow(languageProvider.getText('Email', 'ईमेल'), authProvider.user?.email ?? 'N/A'),
            _buildProfileRow(languageProvider.getText('Role', 'भूमिका'), authProvider.user!.role.toUpperCase()),
            _buildProfileRow(languageProvider.getText('User ID', 'उपयोगकर्ता आईडी'), authProvider.user?.id.toString() ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.getText('Close', 'बंद करें')),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

