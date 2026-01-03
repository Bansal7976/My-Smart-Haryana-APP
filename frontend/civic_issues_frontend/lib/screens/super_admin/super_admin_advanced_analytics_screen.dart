import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/charts/line_chart_widget.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/charts/heatmap_widget.dart';
import '../../utils/app_colors.dart';

class SuperAdminAdvancedAnalyticsScreen extends StatefulWidget {
  const SuperAdminAdvancedAnalyticsScreen({super.key});

  @override
  State<SuperAdminAdvancedAnalyticsScreen> createState() =>
      _SuperAdminAdvancedAnalyticsScreenState();
}

class _SuperAdminAdvancedAnalyticsScreenState
    extends State<SuperAdminAdvancedAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedDistrict = 'All Districts';

  final List<String> _districts = [
    'All Districts',
    'Ambala',
    'Bhiwani',
    'Charkhi Dadri',
    'Faridabad',
    'Fatehabad',
    'Gurugram',
    'Hisar',
    'Jhajjar',
    'Jind',
    'Kaithal',
    'Karnal',
    'Kurukshetra',
    'Mahendragarh',
    'Nuh',
    'Palwal',
    'Panchkula',
    'Panipat',
    'Rewari',
    'Rohtak',
    'Sirsa',
    'Sonipat',
    'Yamunanagar',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final analyticsProvider =
        Provider.of<AnalyticsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    await analyticsProvider.loadAllAnalytics(
      district: _selectedDistrict == 'All Districts' ? null : _selectedDistrict,
      token: authProvider.token,
    );

    if (!mounted) return;
    setState(() {});
  }

  void _onDateRangeChanged(DateTime start, DateTime end) {
    final analyticsProvider =
        Provider.of<AnalyticsProvider>(context, listen: false);
    analyticsProvider.updateDateRange(start, end);
    _loadInitialData();
  }

  void _onDistrictChanged(String? district) {
    setState(() {
      _selectedDistrict = district;
    });
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        backgroundColor: AppColors.superAdminColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Trends', icon: Icon(Icons.trending_up, size: 20)),
            Tab(text: 'Performance', icon: Icon(Icons.bar_chart, size: 20)),
            Tab(text: 'Distribution', icon: Icon(Icons.pie_chart, size: 20)),
            Tab(text: 'Heatmap', icon: Icon(Icons.map, size: 20)),
            Tab(text: 'Reports', icon: Icon(Icons.file_download, size: 20)),
          ],
        ),
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analyticsProvider, child) {
          if (analyticsProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.superAdminColor,
                  ),
                  SizedBox(height: 16),
                  Text('Loading analytics data...'),
                ],
              ),
            );
          }

          if (analyticsProvider.error != null) {
            return _buildErrorState(context, analyticsProvider.error!);
          }

          return Column(
            children: [
              _buildFiltersSection(analyticsProvider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTrendsTab(analyticsProvider),
                    _buildPerformanceTab(analyticsProvider),
                    _buildDistributionTab(analyticsProvider),
                    _buildHeatmapTab(analyticsProvider),
                    _buildReportsTab(analyticsProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics data',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.superAdminColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection(AnalyticsProvider analyticsProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quick date range buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    _onDateRangeChanged(
                        now.subtract(const Duration(days: 7)), now);
                  },
                  child: const Text('7 Days', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    _onDateRangeChanged(
                        now.subtract(const Duration(days: 30)), now);
                  },
                  child: const Text('30 Days', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    _onDateRangeChanged(
                        now.subtract(const Duration(days: 90)), now);
                  },
                  child: const Text('90 Days', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // District dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedDistrict,
            decoration: InputDecoration(
              labelText: 'Select District',
              prefixIcon: const Icon(Icons.location_city, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: _districts
                .map((district) =>
                    DropdownMenuItem(value: district, child: Text(district)))
                .toList(),
            onChanged: _onDistrictChanged,
          ),
          const SizedBox(height: 8),
          // Date range display
          Text(
            'Range: ${analyticsProvider.formattedStartDate} to ${analyticsProvider.formattedEndDate}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(AnalyticsProvider analyticsProvider) {
    final data = analyticsProvider.getDailyTrendsData();
    debugPrint('Trends tab data count: ${data.length}');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.withValues(alpha: 0.1), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.trending_up, size: 40, color: Colors.blue),
                const SizedBox(height: 8),
                const Text(
                  'Issue Trends Over Time',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track how issues are created, assigned, and completed',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LineChartWidget(
            data: data,
            title: 'Daily Issue Creation',
            xAxisLabel: 'Date',
            yAxisLabel: 'Issues Created',
          ),
          const SizedBox(height: 24),
          LineChartWidget(
            data: data,
            title: 'Daily Issue Assignment',
            xAxisLabel: 'Date',
            yAxisLabel: 'Issues Assigned',
          ),
          const SizedBox(height: 24),
          LineChartWidget(
            data: data,
            title: 'Daily Issue Completion',
            xAxisLabel: 'Date',
            yAxisLabel: 'Issues Completed',
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(AnalyticsProvider provider) {
    final departmentData = provider.getDepartmentPerformanceData();
    final workerData = provider.getWorkerPerformanceData();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.withValues(alpha: 0.1), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.bar_chart, size: 40, color: Colors.green),
                const SizedBox(height: 8),
                const Text(
                  'Performance Analytics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Department and worker performance metrics',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Department Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          PieChartWidget(
            data: departmentData,
            title: 'Issues by Department',
          ),
          const SizedBox(height: 32),
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'Top Performing Workers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (workerData.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workerData.length.clamp(0, 10),
              itemBuilder: (context, index) {
                final worker = workerData[index];
                final isTopThree = index < 3;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isTopThree ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isTopThree
                        ? BorderSide(
                            color: Colors.amber.withValues(alpha: 0.5),
                            width: 2)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isTopThree
                                ? Colors.amber.withValues(alpha: 0.2)
                                : AppColors.superAdminColor
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isTopThree
                                    ? Colors.amber[800]
                                    : AppColors.superAdminColor,
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
                                worker['full_name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${worker['department'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${worker['district'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${worker['completed_tasks'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    size: 14, color: Colors.amber[700]),
                                const SizedBox(width: 2),
                                Text(
                                  '${worker['average_rating']?.toStringAsFixed(1) ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No worker performance data available',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributionTab(AnalyticsProvider provider) {
    final issueTypes = provider.getIssueTypesDistributionData();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withValues(alpha: 0.1), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.pie_chart, size: 40, color: Colors.purple),
                const SizedBox(height: 8),
                const Text(
                  'Issue Type Distribution',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Breakdown of issues by category',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PieChartWidget(
            data: issueTypes,
            title: 'Issues by Type',
          ),
          const SizedBox(height: 32),
          const Text(
            'Detailed Breakdown',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (issueTypes.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issueTypes.length,
              itemBuilder: (context, index) {
                final type = issueTypes[index];
                final color = Colors.primaries[index % Colors.primaries.length];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(
                      type['problem_type'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${type['count']} issues',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${type['percentage']?.toStringAsFixed(1)}%',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No issue type distribution data available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeatmapTab(AnalyticsProvider provider) {
    final heatmapData = provider.heatMapData;
    List<Map<String, dynamic>> points = [];

    if (heatmapData.isNotEmpty && heatmapData.containsKey('heat_points')) {
      points = List<Map<String, dynamic>>.from(heatmapData['heat_points']);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Issue Location Heatmap',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Visualizes the geographic distribution of reported issues',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          HeatmapWidget(
            data: points,
            title: 'Issue Density Map',
          ),
          const SizedBox(height: 16),
          if (points.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.superAdminColor),
                        SizedBox(width: 8),
                        Text(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildStatRow('Total Issues', points.length.toString()),
                    _buildStatRow(
                        'District', _selectedDistrict ?? 'All Districts'),
                    _buildStatRow(
                      'Date Range',
                      '${provider.formattedStartDate} to ${provider.formattedEndDate}',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(AnalyticsProvider provider) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.superAdminColor.withValues(alpha: 0.1),
                  Colors.white
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.superAdminColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.file_download,
                    size: 48, color: AppColors.superAdminColor),
                const SizedBox(height: 12),
                const Text(
                  'Export Reports',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Download detailed analytics reports in CSV format',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildReportCard(
            'Trends Report',
            'Daily, weekly, and monthly trends',
            'trends',
            provider,
            Icons.trending_up,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Department Performance',
            'Department-wise analytics',
            'departments',
            provider,
            Icons.business,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Worker Performance',
            'Worker productivity metrics',
            'workers',
            provider,
            Icons.people,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            'Issue Distribution',
            'Issue types and categories',
            'issues',
            provider,
            Icons.pie_chart,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String description,
    String type,
    AnalyticsProvider provider,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _exportReport(type, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.superAdminColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportReport(String type, AnalyticsProvider provider) async {
    // Request storage permission first
    PermissionStatus status = await Permission.storage.status;

    // For Android 13+, use manageExternalStorage or photos permission
    if (Platform.isAndroid) {
      final androidInfo = await Permission.storage.status;
      if (!androidInfo.isGranted) {
        // Try requesting manageExternalStorage for Android 11+
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Fallback to regular storage permission
          status = await Permission.storage.request();
        }
      }
    }

    if (!status.isGranted && !status.isLimited) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Storage permission is required to save CSV files'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Grant Permission',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Generating CSV report...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final result = await provider.exportAnalyticsCSV(
        type,
        district:
            _selectedDistrict == 'All Districts' ? null : _selectedDistrict,
      );

      if (!mounted) return;

      if (result.containsKey('content') && result.containsKey('filename')) {
        // Save file to Downloads folder
        final String csvContent = result['content'];
        final String filename = result['filename'];

        // Get the Downloads directory
        Directory? directory;
        if (Platform.isAndroid) {
          // Try multiple paths for Android
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = Directory('/storage/emulated/0/Downloads');
          }
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          throw Exception('Unable to access storage directory');
        }

        final String filePath = '${directory.path}/$filename';
        final File file = File(filePath);
        await file.writeAsString(csvContent);

        if (!mounted) return;

        // Show success dialog with file details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                SizedBox(width: 12),
                Text('Report Saved!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your CSV report has been saved successfully.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              filename,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.folder, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Platform.isAndroid
                                  ? 'Downloads folder'
                                  : 'Documents folder',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.storage, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${(csvContent.length / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Path: $filePath',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: filePath));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Path copied to clipboard')),
                  );
                },
                child: const Text('Copy Path'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        debugPrint('✅ CSV Saved Successfully: $filePath');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report export failed - Invalid response'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint('Export error: $e');
    }
  }
}
