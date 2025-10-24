import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final analytics = await ApiService.getAdminAnalytics(authProvider.token!);

      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          languageProvider.getText('Analytics Dashboard', 'विश्लेषण डैशबोर्ड'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.adminColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalytics,
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
                        onPressed: _loadAnalytics,
                        child: Text(languageProvider.getText('Retry', 'पुन: प्रयास करें')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // District Overview
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.adminColor, Color(0xFF1565C0)],
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
                                  const Icon(
                                    Icons.location_city,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _analytics?['district'] ?? 'Your District',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          languageProvider.getText(
                                            'District Analytics',
                                            'जिला विश्लेषण',
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

                        // Key Metrics Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.3,
                          children: [
                            _buildMetricCard(
                              languageProvider.getText('Total Problems', 'कुल समस्याएं'),
                              _analytics?['total_problems']?.toString() ?? '0',
                              Icons.assignment,
                              AppColors.info,
                            ),
                            _buildMetricCard(
                              languageProvider.getText('Active Workers', 'सक्रिय कार्यकर्ता'),
                              _analytics?['total_workers']?.toString() ?? '0',
                              Icons.engineering,
                              AppColors.workerColor,
                            ),
                            _buildMetricCard(
                              languageProvider.getText('Pending', 'लंबित'),
                              _analytics?['pending_problems']?.toString() ?? '0',
                              Icons.pending,
                              AppColors.pending,
                            ),
                            _buildMetricCard(
                              languageProvider.getText('Completed', 'पूर्ण'),
                              _analytics?['completed_problems']?.toString() ?? '0',
                              Icons.check_circle,
                              AppColors.success,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Problem Breakdown
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getText(
                                  'Problem Status Breakdown',
                                  'समस्या स्थिति विवरण',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatusRow(
                                languageProvider.getText('Pending', 'लंबित'),
                                _analytics?['pending_problems']?.toString() ?? '0',
                                AppColors.pending,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Assigned', 'निर्दिष्ट'),
                                _analytics?['assigned_problems']?.toString() ?? '0',
                                AppColors.inProgress,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Completed', 'पूर्ण'),
                                _analytics?['completed_problems']?.toString() ?? '0',
                                AppColors.success,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Verified', 'सत्यापित'),
                                _analytics?['verified_problems']?.toString() ?? '0',
                                AppColors.success,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Performance Metrics
                        Text(
                          languageProvider.getText(
                            'Performance Metrics',
                            'प्रदर्शन मेट्रिक्स',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 16),

                        _buildPerformanceCard(
                          languageProvider.getText('Completion Rate', 'पूर्णता दर'),
                          _calculateCompletionRate(),
                          Icons.trending_up,
                          AppColors.success,
                        ),

                        const SizedBox(height: 12),

                        _buildPerformanceCard(
                          languageProvider.getText('Average Response Time', 'औसत प्रतिक्रिया समय'),
                          _analytics?['avg_response_time']?.toString() ?? 'N/A',
                          Icons.schedule,
                          AppColors.info,
                        ),

                        const SizedBox(height: 12),

                        _buildPerformanceCard(
                          languageProvider.getText('Worker Utilization', 'कार्यकर्ता उपयोग'),
                          _calculateWorkerUtilization(),
                          Icons.people,
                          AppColors.workerColor,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
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

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateCompletionRate() {
    if (_analytics == null) return '0%';
    final total = _analytics!['total_problems'] ?? 0;
    final completed = _analytics!['completed_problems'] ?? 0;
    if (total == 0) return '0%';
    final rate = (completed / total * 100).toStringAsFixed(1);
    return '$rate%';
  }

  String _calculateWorkerUtilization() {
    if (_analytics == null) return '0%';
    final workers = _analytics!['total_workers'] ?? 0;
    final assigned = _analytics!['assigned_problems'] ?? 0;
    if (workers == 0) return '0%';
    final utilization = (assigned / workers * 100).toStringAsFixed(1);
    return '$utilization%';
  }
}


