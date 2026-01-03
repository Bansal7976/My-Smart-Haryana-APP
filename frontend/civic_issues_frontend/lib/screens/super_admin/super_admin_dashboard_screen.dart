import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import 'manage_admins_screen.dart';
import 'super_admin_analytics_screen.dart';
import 'super_admin_reports_screen.dart';
import 'super_admin_advanced_analytics_screen.dart';
import '../client/leaderboard_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  Map<String, dynamic>? _overview;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final overview = await ApiService.getSuperAdminOverview(authProvider.token!);
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadOverview,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.superAdminColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
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
                            languageProvider.getText('Welcome, Super Admin!', 'स्वागत है, सुपर एडमिन!'),
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
                              'पूर्ण सिस्टम नियंत्रण और प्रशासन',
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
              ),

              const SizedBox(height: 24),

              // System Overview Stats
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_overview != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        languageProvider.getText('Total Issues', 'कुल समस्याएं'),
                        _overview!['total_issues']?.toString() ?? '0',
                        Icons.assignment,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        languageProvider.getText('Total Admins', 'कुल एडमिन'),
                        _overview!['total_admins']?.toString() ?? '0',
                        Icons.admin_panel_settings,
                        AppColors.adminColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        languageProvider.getText('Total Workers', 'कुल कार्यकर्ता'),
                        _overview!['total_workers']?.toString() ?? '0',
                        Icons.work,
                        AppColors.workerColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        languageProvider.getText('Total Users', 'कुल उपयोगकर्ता'),
                        _overview!['total_users']?.toString() ?? '0',
                        Icons.people,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Management Actions
              Text(
                languageProvider.getText('System Management', 'सिस्टम प्रबंधन'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Action Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  _buildActionCard(
                    context,
                    languageProvider.getText('Admins', 'एडमिन'),
                    Icons.admin_panel_settings,
                    AppColors.adminColor,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAdminsScreen())),
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Analytics', 'विश्लेषण'),
                    Icons.analytics,
                    AppColors.primary,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminAnalyticsScreen())),
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Reports', 'रिपोर्ट्स'),
                    Icons.description,
                    AppColors.superAdminColor,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminReportsScreen())),
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Advanced', 'उन्नत'),
                    Icons.insights,
                    const Color(0xFF00897B),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminAdvancedAnalyticsScreen())),
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Leaderboard', 'लीडरबोर्ड'),
                    Icons.leaderboard,
                    const Color(0xFFFF6B35),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Settings', 'सेटिंग्स'),
                    Icons.settings,
                    AppColors.textSecondary,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(languageProvider.getText(
                            'Settings feature coming soon!',
                            'सेटिंग्स सुविधा जल्द आ रही है!',
                          )),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // District Performance Overview
              if (_overview != null && _overview!['district_stats'] != null) ...[
                Text(
                  languageProvider.getText('District Overview', 'जिला अवलोकन'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageProvider.getText('Total Districts', 'कुल जिले'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _overview!['total_districts']?.toString() ?? '0',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageProvider.getText('Active Districts', 'सक्रिय जिले'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _overview!['active_districts']?.toString() ?? '0',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 10.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            child: Icon(icon, color: color, size: 20),
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
}
