import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/charts/line_chart_widget.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/charts/analytics_date_picker.dart';
import '../../widgets/charts/heatmap_widget.dart';
import '../../utils/app_colors.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen>
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

    await analyticsProvider.loadAllAnalytics(
      district: _selectedDistrict == 'All Districts' ? null : _selectedDistrict,
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Trends', icon: Icon(Icons.trending_up)),
            Tab(text: 'Performance', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Distribution', icon: Icon(Icons.pie_chart)),
            Tab(text: 'Heatmap', icon: Icon(Icons.map)),
            Tab(text: 'Reports', icon: Icon(Icons.file_download)),
          ],
        ),
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analyticsProvider, child) {
          if (analyticsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
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

  // -------------------- ERROR UI --------------------

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading analytics data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // -------------------- FILTERS --------------------

  Widget _buildFiltersSection(AnalyticsProvider analyticsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          AnalyticsDatePicker(
            onDateRangeSelected: _onDateRangeChanged,
            initialStartDate: analyticsProvider.startDate,
            initialEndDate: analyticsProvider.endDate,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDistrict,
            decoration: const InputDecoration(
              labelText: 'District',
              border: OutlineInputBorder(),
            ),
            items: _districts
                .map((district) =>
                    DropdownMenuItem(value: district, child: Text(district)))
                .toList(),
            onChanged: _onDistrictChanged,
          ),
        ],
      ),
    );
  }

  // -------------------- TABS --------------------

  Widget _buildTrendsTab(AnalyticsProvider analyticsProvider) {
    final data = analyticsProvider.getDailyTrendsData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issue Trends Over Time',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          LineChartWidget(
            data: data,
            title: 'Daily Issue Creation',
            xAxisLabel: 'Date',
            yAxisLabel: 'Issues Created',
          ),
          const SizedBox(height: 16),
          LineChartWidget(
            data: data,
            title: 'Daily Issue Assignment',
            xAxisLabel: 'Date',
            yAxisLabel: 'Issues Assigned',
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Department Performance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        PieChartWidget(
          data: departmentData,
          title: 'Issues by Department',
        ),
        const SizedBox(height: 32),
        const Text('Top Performing Workers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (workerData.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workerData.length.clamp(0, 10),
            itemBuilder: (context, index) {
              final worker = workerData[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(worker['full_name'] ?? 'Unknown'),
                  subtitle: Text(
                    '${worker['department'] ?? 'Unknown'} • '
                    '${worker['district'] ?? 'Unknown'}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${worker['completed_tasks'] ?? 0} tasks',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rating: ${worker['average_rating']?.toStringAsFixed(1) ?? 'N/A'}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          const Center(child: Text('No worker performance data available')),
      ]),
    );
  }

  Widget _buildDistributionTab(AnalyticsProvider provider) {
    final issueTypes = provider.getIssueTypesDistributionData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Issue Type Distribution',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        PieChartWidget(
          data: issueTypes,
          title: 'Issues by Type',
        ),
        const SizedBox(height: 32),
        const Text('Detailed Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    color: color,
                  ),
                  title: Text(type['problem_type'] ?? 'Unknown'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${type['count']} issues',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${type['percentage']?.toStringAsFixed(1)}%',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          const Center(child: Text('No issue type distribution data available'))
      ]),
    );
  }

  // -------------------- HEATMAP TAB --------------------

  Widget _buildHeatmapTab(AnalyticsProvider provider) {
    final heatmapData = provider.heatMapData;
    List<Map<String, dynamic>> points = [];

    if (heatmapData.isNotEmpty && heatmapData.containsKey('data')) {
      points = List<Map<String, dynamic>>.from(heatmapData['data']);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issue Location Heatmap',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Visualizes the geographic distribution of reported issues',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          HeatmapWidget(
            data: points,
            title: 'Issue Density Map',
          ),
          const SizedBox(height: 16),
          if (points.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow('Total Issues', points.length.toString()),
                    _buildStatRow(
                      'District',
                      _selectedDistrict ?? 'All Districts',
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // -------------------- REPORTS TAB --------------------

  Widget _buildReportsTab(AnalyticsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Export Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text(
          'Download detailed analytics reports in CSV format for further analysis.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _buildReportCard('Trends Report', 'Daily trends', 'trends', provider),
        const SizedBox(height: 16),
        _buildReportCard('Performance Report', 'Worker & department metrics',
            'performance', provider),
        const SizedBox(height: 16),
        _buildReportCard('Distribution Report', 'Types & geographic spread',
            'distribution', provider),
        const SizedBox(height: 16),
        _buildReportCard('Complete Analytics', 'All analytics included',
            'complete', provider),
      ]),
    );
  }

  Widget _buildReportCard(String title, String description, String type,
      AnalyticsProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _exportReport(type, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport(String type, AnalyticsProvider provider) async {
    try {
      final result = await provider.exportAnalyticsCSV(
        type,
        district:
            _selectedDistrict == 'All Districts' ? null : _selectedDistrict,
      );

      if (!mounted) return;

      if (result.containsKey('download_url')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report exported successfully!'),
            action: SnackBarAction(
              label: 'Download',
              onPressed: () {
                debugPrint("Download URL: ${result['download_url']}");
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report export failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
