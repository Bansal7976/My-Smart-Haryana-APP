import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';

class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.superAdminGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.superAdminColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText(
                                'Welcome, Super Admin!',
                                'स्वागत है, सुपर एडमिन!'
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              languageProvider.getText(
                                'Full system control and administration',
                                'पूर्ण सिस्टम नियंत्रण और प्रशासन'
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // System Overview Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    languageProvider.getText('System Status', 'सिस्टम स्थिति'),
                    'Active',
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    languageProvider.getText('Total Users', 'कुल उपयोगकर्ता'),
                    '1,234',
                    Icons.people,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    languageProvider.getText('Active Issues', 'सक्रिय समस्याएं'),
                    '89',
                    Icons.assignment,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    languageProvider.getText('Workers Online', 'ऑनलाइन कार्यकर्ता'),
                    '45',
                    Icons.work,
                    AppColors.info,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Management Actions
            Text(
              languageProvider.getText('System Management', 'सिस्टम प्रबंधन'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildActionCard(
                  context,
                  languageProvider.getText('User Management', 'उपयोगकर्ता प्रबंधन'),
                  Icons.people,
                  AppColors.primary,
                  () {
                    _showComingSoonDialog(context, languageProvider.getText(
                      'User Management',
                      'उपयोगकर्ता प्रबंधन'
                    ));
                  },
                ),
                _buildActionCard(
                  context,
                  languageProvider.getText('System Settings', 'सिस्टम सेटिंग्स'),
                  Icons.settings,
                  AppColors.adminColor,
                  () {
                    _showComingSoonDialog(context, languageProvider.getText(
                      'System Settings',
                      'सिस्टम सेटिंग्स'
                    ));
                  },
                ),
                _buildActionCard(
                  context,
                  languageProvider.getText('Reports', 'रिपोर्ट्स'),
                  Icons.assessment,
                  AppColors.workerColor,
                  () {
                    _showComingSoonDialog(context, languageProvider.getText(
                      'Reports',
                      'रिपोर्ट्स'
                    ));
                  },
                ),
                _buildActionCard(
                  context,
                  languageProvider.getText('Backup & Restore', 'बैकअप और रिस्टोर'),
                  Icons.backup,
                  AppColors.superAdminColor,
                  () {
                    _showComingSoonDialog(context, languageProvider.getText(
                      'Backup & Restore',
                      'बैकअप और रिस्टोर'
                    ));
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              languageProvider.getText('Quick Actions', 'त्वरित कार्य'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Action Buttons
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: languageProvider.getText('Create New Admin', 'नया एडमिन बनाएं'),
                onPressed: () {
                  _showComingSoonDialog(context, languageProvider.getText(
                    'Create New Admin',
                    'नया एडमिन बनाएं'
                  ));
                },
                backgroundColor: AppColors.adminColor,
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: languageProvider.getText('System Maintenance', 'सिस्टम रखरखाव'),
                onPressed: () {
                  _showComingSoonDialog(context, languageProvider.getText(
                    'System Maintenance',
                    'सिस्टम रखरखाव'
                  ));
                },
                backgroundColor: AppColors.warning,
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: languageProvider.getText('View System Logs', 'सिस्टम लॉग देखें'),
                onPressed: () {
                  _showComingSoonDialog(context, languageProvider.getText(
                    'View System Logs',
                    'सिस्टम लॉग देखें'
                  ));
                },
                backgroundColor: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // System Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getText('System Information', 'सिस्टम जानकारी'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    languageProvider.getText('App Version', 'ऐप संस्करण'),
                    '1.0.0',
                  ),
                  _buildInfoRow(
                    languageProvider.getText('Database Status', 'डेटाबेस स्थिति'),
                    'Connected',
                  ),
                  _buildInfoRow(
                    languageProvider.getText('Server Status', 'सर्वर स्थिति'),
                    'Online',
                  ),
                  _buildInfoRow(
                    languageProvider.getText('Last Backup', 'अंतिम बैकअप'),
                    '2 hours ago',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  void _showComingSoonDialog(BuildContext context, String feature) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text(languageProvider.getText(
          'This feature will be available in the next update.',
          'यह सुविधा अगले अपडेट में उपलब्ध होगी।'
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(languageProvider.getText('OK', 'ठीक है')),
          ),
        ],
      ),
    );
  }
}