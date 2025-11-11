import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class SuperAdminReportsScreen extends StatefulWidget {
  const SuperAdminReportsScreen({super.key});

  @override
  State<SuperAdminReportsScreen> createState() =>
      _SuperAdminReportsScreenState();
}

class _SuperAdminReportsScreenState extends State<SuperAdminReportsScreen> {
  List<Map<String, dynamic>> _districtLeaderboard = [];
  List<Map<String, dynamic>> _departmentStats = [];
  List<Map<String, dynamic>> _topWorkers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final districts =
          await ApiService.getDistrictAnalytics(authProvider.token!);
      final departments =
          await ApiService.getDepartmentStats(authProvider.token!);
      final workers = await ApiService.getTopWorkers(authProvider.token!);

      setState(() {
        _districtLeaderboard = districts;
        _departmentStats = departments;
        _topWorkers = workers;
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
          languageProvider.getText('Haryana Reports', 'हरियाणा रिपोर्ट्स'),
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
            onPressed: _loadReports,
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
                        onPressed: _loadReports,
                        child: Text(languageProvider.getText(
                            'Retry', 'पुन: प्रयास करें')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🏆 Best District Leaderboard
                        _buildSectionHeader(
                          context,
                          '🏆 ${languageProvider.getText(
                            'Best Districts Leaderboard',
                            'सर्वश्रेष्ठ जिला लीडरबोर्ड',
                          )}',
                          Icons.emoji_events,
                          AppColors.warning,
                        ),
                        const SizedBox(height: 16),
                        _buildDistrictLeaderboard(languageProvider),

                        const SizedBox(height: 32),

                        // 🏢 Department Statistics
                        _buildSectionHeader(
                          context,
                          '🏢 ${languageProvider.getText(
                            'Department-wise Problem Statistics',
                            'विभागवार समस्या सांख्यिकी',
                          )}',
                          Icons.business,
                          AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        _buildDepartmentStats(languageProvider),

                        const SizedBox(height: 32),

                        // ⭐ Top Workers
                        _buildSectionHeader(
                          context,
                          '⭐ ${languageProvider.getText(
                            'Top Performing Workers in Haryana',
                            'हरियाणा में सर्वश्रेष्ठ कार्यकर्ता',
                          )}',
                          Icons.star,
                          AppColors.success,
                        ),
                        const SizedBox(height: 16),
                        _buildTopWorkers(languageProvider),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictLeaderboard(LanguageProvider languageProvider) {
    if (_districtLeaderboard.isEmpty) {
      return _buildEmptyState(languageProvider.getText(
        'No district data available',
        'कोई जिला डेटा उपलब्ध नहीं है',
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _districtLeaderboard.length,
      itemBuilder: (context, index) {
        final district = _districtLeaderboard[index];
        final rank = index + 1;
        final districtName = district['district_name'] ?? 'Unknown';
        final resolutionRate = district['resolution_rate'] ?? 0.0;
        final totalProblems = district['total_problems'] ?? 0;
        final completedProblems = (district['completed_problems'] ?? 0) +
            (district['verified_problems'] ?? 0);

        Color rankColor = AppColors.textSecondary;
        IconData? medalIcon;

        if (rank == 1) {
          rankColor = const Color(0xFFFFD700); // Gold
          medalIcon = Icons.emoji_events;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          medalIcon = Icons.emoji_events;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          medalIcon = Icons.emoji_events;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: rank <= 3 ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.5)
                  : AppColors.border,
              width: rank <= 3 ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: rankColor, width: 2),
                      ),
                      child: Center(
                        child: medalIcon != null
                            ? Icon(medalIcon, color: rankColor, size: 24)
                            : Text(
                                '#$rank',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            districtName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '$completedProblems / $totalProblems ${languageProvider.getText('problems resolved', 'समस्याएं हल')}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Resolution Rate
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${resolutionRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: resolutionRate / 100,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    rank <= 3 ? rankColor : AppColors.success,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentStats(LanguageProvider languageProvider) {
    if (_departmentStats.isEmpty) {
      return _buildEmptyState(languageProvider.getText(
        'No department data available',
        'कोई विभाग डेटा उपलब्ध नहीं है',
      ));
    }

    // Find max for scaling
    final maxProblems = _departmentStats.fold<int>(
      0,
      (max, dept) =>
          (dept['total_problems'] ?? 0) > max ? dept['total_problems'] : max,
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _departmentStats.length,
      itemBuilder: (context, index) {
        final department = _departmentStats[index];
        final deptName = department['department_name'] ?? 'Unknown';
        final totalProblems = department['total_problems'] ?? 0;
        final completed = department['completed_problems'] ?? 0;
        final verified = department['verified_problems'] ?? 0;
        final pending = department['pending_problems'] ?? 0;
        final assigned = department['assigned_problems'] ?? 0;

        final barWidth = maxProblems > 0 ? (totalProblems / maxProblems) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        deptName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalProblems ${languageProvider.getText('total', 'कुल')}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Visual bar chart
                Container(
                  height: 24,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: barWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Stats breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDeptStat(
                      languageProvider.getText('Pending', 'लंबित'),
                      pending.toString(),
                      AppColors.pending,
                    ),
                    _buildDeptStat(
                      languageProvider.getText('Assigned', 'निर्दिष्ट'),
                      assigned.toString(),
                      AppColors.inProgress,
                    ),
                    _buildDeptStat(
                      languageProvider.getText('Done', 'पूर्ण'),
                      (completed + verified).toString(),
                      AppColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeptStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopWorkers(LanguageProvider languageProvider) {
    if (_topWorkers.isEmpty) {
      return _buildEmptyState(languageProvider.getText(
        'No worker data available',
        'कोई कार्यकर्ता डेटा उपलब्ध नहीं है',
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topWorkers.length,
      itemBuilder: (context, index) {
        final worker = _topWorkers[index];
        final rank = index + 1;
        final workerName = worker['worker_name'] ?? 'Unknown';
        final district = worker['district'] ?? 'N/A';
        final department = worker['department'] ?? 'N/A';
        final completedTasks = worker['completed_tasks'] ?? 0;
        final totalTasks = worker['total_tasks'] ?? 0;
        final avgRating = worker['average_rating'];
        final completionRate = worker['completion_rate'] ?? 0.0;

        Color rankColor = AppColors.textSecondary;
        IconData? starIcon;

        if (rank == 1) {
          rankColor = const Color(0xFFFFD700); // Gold
          starIcon = Icons.star;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          starIcon = Icons.star;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          starIcon = Icons.star;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: rank <= 3 ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.5)
                  : AppColors.border,
              width: rank <= 3 ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: rankColor, width: 2),
                  ),
                  child: Center(
                    child: starIcon != null
                        ? Icon(starIcon, color: rankColor, size: 28)
                        : Text(
                            '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rankColor,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            district,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.business,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              department,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$completedTasks/$totalTasks ${languageProvider.getText('tasks', 'कार्य')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (avgRating != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Text(
                            '${completionRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: rankColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
