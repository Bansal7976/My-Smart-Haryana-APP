import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class SuperAdminAnalyticsScreen extends StatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  State<SuperAdminAnalyticsScreen> createState() =>
      _SuperAdminAnalyticsScreenState();
}

class _SuperAdminAnalyticsScreenState extends State<SuperAdminAnalyticsScreen> {
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _districtStats = [];
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
      final overview = await ApiService.getSuperAdminOverview(authProvider.token!);
      final districtStats =
          await ApiService.getDistrictAnalytics(authProvider.token!);

      setState(() {
        _overview = overview;
        _districtStats = districtStats;
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
          languageProvider.getText('Analytics & Reports', 'विश्लेषण और रिपोर्ट'),
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
                        // Haryana Overview
                        Text(
                          languageProvider.getText(
                            'Haryana Overview',
                            'हरियाणा अवलोकन',
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

                        // Overview Stats Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _buildStatCard(
                              languageProvider.getText('Total Users', 'कुल उपयोगकर्ता'),
                              (((_overview?['total_clients'] ?? 0) + 
                                (_overview?['total_workers'] ?? 0) + 
                                (_overview?['total_admins'] ?? 0))).toString(),
                              Icons.people,
                              AppColors.primary,
                            ),
                            _buildStatCard(
                              languageProvider.getText('Total Problems', 'कुल समस्याएं'),
                              _overview?['total_problems']?.toString() ?? '0',
                              Icons.assignment,
                              AppColors.info,
                            ),
                            _buildStatCard(
                              languageProvider.getText('Total Admins', 'कुल एडमिन'),
                              _overview?['total_admins']?.toString() ?? '0',
                              Icons.admin_panel_settings,
                              AppColors.adminColor,
                            ),
                            _buildStatCard(
                              languageProvider.getText('Total Workers', 'कुल कार्यकर्ता'),
                              _overview?['total_workers']?.toString() ?? '0',
                              Icons.work,
                              AppColors.workerColor,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Problem Status Breakdown
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
                                  'Problem Status',
                                  'समस्या स्थिति',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatusRow(
                                languageProvider.getText('Pending', 'लंबित'),
                                _overview?['problems_by_status']?['pending']
                                        ?.toString() ??
                                    '0',
                                AppColors.pending,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Assigned', 'निर्दिष्ट'),
                                _overview?['problems_by_status']?['assigned']
                                        ?.toString() ??
                                    '0',
                                AppColors.inProgress,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Completed', 'पूर्ण'),
                                _overview?['problems_by_status']?['completed']
                                        ?.toString() ??
                                    '0',
                                AppColors.success,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Verified', 'सत्यापित'),
                                _overview?['problems_by_status']?['verified']
                                        ?.toString() ??
                                    '0',
                                AppColors.success,
                              ),
                              _buildStatusRow(
                                languageProvider.getText('Rejected', 'अस्वीकृत'),
                                _overview?['problems_by_status']?['rejected']
                                        ?.toString() ??
                                    '0',
                                AppColors.error,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // District-wise Analytics
                        Text(
                          languageProvider.getText(
                            'District-wise Statistics',
                            'जिलेवार आंकड़े',
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

                        // District Stats List
                        _districtStats.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    languageProvider.getText(
                                      'No district data available',
                                      'कोई जिला डेटा उपलब्ध नहीं है',
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _districtStats.length,
                                itemBuilder: (context, index) {
                                  final district = _districtStats[index];
                                  return _buildDistrictCard(
                                      district, languageProvider);
                                },
                              ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildDistrictCard(
      Map<String, dynamic> district, LanguageProvider languageProvider) {
    final totalProblems = district['total_problems'] ?? 0;
    final pendingProblems = district['pending_problems'] ?? 0;
    final completedProblems = district['completed_problems'] ?? 0;
    final districtName = district['district_name'] ?? district['district'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            districtName[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          districtName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${languageProvider.getText('Total', 'कुल')}: $totalProblems ${languageProvider.getText('problems', 'समस्याएं')}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDistrictStat(
                      languageProvider.getText('Pending', 'लंबित'),
                      pendingProblems.toString(),
                      AppColors.pending,
                    ),
                    _buildDistrictStat(
                      languageProvider.getText('Completed', 'पूर्ण'),
                      completedProblems.toString(),
                      AppColors.success,
                    ),
                    _buildDistrictStat(
                      languageProvider.getText('Workers', 'कार्यकर्ता'),
                      (district['total_workers'] ?? 0).toString(),
                      AppColors.workerColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalProblems > 0
                      ? completedProblems / totalProblems
                      : 0,
                  backgroundColor: AppColors.pending.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
                const SizedBox(height: 8),
                Text(
                  '${totalProblems > 0 ? ((completedProblems / totalProblems) * 100).toStringAsFixed(1) : 0}% ${languageProvider.getText('Completion Rate', 'पूर्णता दर')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictStat(String label, String value, Color color) {
    return Column(
      children: [
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
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}



