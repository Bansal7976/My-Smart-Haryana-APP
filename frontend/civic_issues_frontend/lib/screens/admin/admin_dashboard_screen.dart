import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import 'admin_issues_screen.dart';
import 'admin_workers_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<IssueProvider>(context, listen: false)
            .loadAllProblems(authProvider.token!);
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'assigned':
        return AppColors.inProgress;
      case 'completed':
        return AppColors.success;
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'pending':
        return languageProvider.getText('Pending', 'लंबित');
      case 'assigned':
        return languageProvider.getText('Assigned', 'निर्दिष्ट');
      case 'completed':
        return languageProvider.getText('Completed', 'पूर्ण');
      case 'verified':
        return languageProvider.getText('Verified', 'सत्यापित');
      case 'rejected':
        return languageProvider.getText('Rejected', 'अस्वीकृत');
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final issueProvider = Provider.of<IssueProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.token != null) {
            await issueProvider.loadAllProblems(authProvider.token!);
          }
        },
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
                    colors: AppColors.adminGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.adminColor.withValues(alpha: 0.3),
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
                            Icons.admin_panel_settings,
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
                                    'Welcome, Admin!', 'स्वागत है, एडमिन!'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                languageProvider.getText(
                                    'Manage issues and oversee operations',
                                    'समस्याओं का प्रबंधन करें और संचालन की निगरानी करें'),
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

              // Quick Stats
              Consumer<IssueProvider>(
                builder: (context, issueProvider, child) {
                  final totalIssues = issueProvider.allProblems.length;
                  final pendingIssues = issueProvider.allProblems
                      .where((issue) => issue.status.toLowerCase() == 'pending')
                      .length;
                  final assignedIssues = issueProvider.allProblems
                      .where(
                          (issue) => issue.status.toLowerCase() == 'assigned')
                      .length;
                  final completedIssues = issueProvider.allProblems
                      .where(
                          (issue) => issue.status.toLowerCase() == 'completed')
                      .length;
                  final verifiedIssues = issueProvider.allProblems
                      .where(
                          (issue) => issue.status.toLowerCase() == 'verified')
                      .length;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText(
                                  'Total Issues', 'कुल समस्याएं'),
                              totalIssues.toString(),
                              Icons.assignment,
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText('Pending', 'लंबित'),
                              pendingIssues.toString(),
                              Icons.schedule,
                              AppColors.pending,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText('Assigned', 'निर्दिष्ट'),
                              assignedIssues.toString(),
                              Icons.assignment_ind,
                              AppColors.inProgress,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText('Completed', 'पूर्ण'),
                              completedIssues.toString(),
                              Icons.check_circle,
                              AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText('Verified', 'सत्यापित'),
                              verifiedIssues.toString(),
                              Icons.verified,
                              AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              languageProvider.getText(
                                  'Resolution Rate', 'समाधान दर'),
                              totalIssues > 0
                                  ? '${((completedIssues + verifiedIssues) / totalIssues * 100).toStringAsFixed(1)}%'
                                  : '0%',
                              Icons.trending_up,
                              AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Management Actions
              Text(
                languageProvider.getText('Management', 'प्रबंधन'),
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
                    languageProvider.getText('All Issues', 'सभी समस्याएं'),
                    Icons.assignment,
                    AppColors.primary,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminIssuesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Workers', 'कार्यकर्ता'),
                    Icons.work,
                    AppColors.workerColor,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminWorkersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Departments', 'विभाग'),
                    Icons.business,
                    AppColors.adminColor,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminDepartmentsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    languageProvider.getText('Analytics', 'विश्लेषण'),
                    Icons.analytics,
                    AppColors.superAdminColor,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminAnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Issues Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.getText(
                        'Recent Issues', 'हाल की समस्याएं'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminIssuesScreen(),
                        ),
                      );
                    },
                    child: Text(
                      languageProvider.getText('View All', 'सभी देखें'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Issues List
              Consumer<IssueProvider>(
                builder: (context, issueProvider, child) {
                  if (issueProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (issueProvider.error != null) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            languageProvider.getText('Failed to load issues',
                                'समस्याएं लोड करने में असफल'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            issueProvider.error!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: languageProvider.getText(
                                'Retry', 'पुनः प्रयास'),
                            onPressed: () {
                              if (authProvider.token != null) {
                                issueProvider
                                    .loadAllProblems(authProvider.token!);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  if (issueProvider.allProblems.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            languageProvider.getText(
                                'No issues found', 'कोई समस्या नहीं मिली'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: issueProvider.allProblems.take(5).length,
                    itemBuilder: (context, index) {
                      final issue = issueProvider.allProblems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(issue.status)
                                .withValues(alpha: 0.1),
                            child: Icon(
                              _getStatusIcon(issue.status),
                              color: _getStatusColor(issue.status),
                            ),
                          ),
                          title: Text(
                            issue.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(issue.status)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusText(
                                          issue.status, languageProvider),
                                      style: TextStyle(
                                        color: _getStatusColor(issue.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(issue.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            // Navigate to issue detail or management screen
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const AdminIssuesScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'assigned':
        return Icons.assignment_ind;
      case 'completed':
        return Icons.check_circle;
      case 'verified':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
