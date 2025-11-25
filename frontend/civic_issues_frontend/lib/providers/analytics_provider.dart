import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AnalyticsProvider with ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> _dailyTrends = {};
  Map<String, dynamic> _weeklyTrends = {};
  Map<String, dynamic> _monthlyTrends = {};
  Map<String, dynamic> _departmentPerformance = {};
  Map<String, dynamic> _workerPerformance = {};
  Map<String, dynamic> _issueTypesDistribution = {};
  Map<String, dynamic> _heatMapData = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic> get dailyTrends => _dailyTrends;
  Map<String, dynamic> get weeklyTrends => _weeklyTrends;
  Map<String, dynamic> get monthlyTrends => _monthlyTrends;
  Map<String, dynamic> get departmentPerformance => _departmentPerformance;
  Map<String, dynamic> get workerPerformance => _workerPerformance;
  Map<String, dynamic> get issueTypesDistribution => _issueTypesDistribution;
  Map<String, dynamic> get heatMapData => _heatMapData;

  // Date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  void updateDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  // Format dates for API
  String get formattedStartDate => _startDate.toIso8601String().split('T')[0];
  String get formattedEndDate => _endDate.toIso8601String().split('T')[0];

  // Set token
  void setToken(String? token) {
    _token = token;
  }

  // Load all analytics
  Future<void> loadAllAnalytics({String? district, String? token}) async {
    if (token != null) _token = token;
    
    if (_token == null) {
      _error = 'Authentication required';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadDailyTrends(district: district),
        loadDepartmentPerformance(district: district),
        loadWorkerPerformance(district: district),
        loadIssueTypesDistribution(district: district),
        loadHeatMapData(district: district),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDailyTrends({String? district}) async {
    if (_token == null) return;
    try {
      _dailyTrends = await ApiService.getDailyTrends(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading daily trends: $e');
      _dailyTrends = {};
    }
  }

  Future<void> loadWeeklyTrends({String? district}) async {
    if (_token == null) return;
    try {
      _weeklyTrends = await ApiService.getWeeklyTrends(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading weekly trends: $e');
      _weeklyTrends = {};
    }
  }

  Future<void> loadMonthlyTrends({String? district}) async {
    if (_token == null) return;
    try {
      _monthlyTrends = await ApiService.getMonthlyTrends(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading monthly trends: $e');
      _monthlyTrends = {};
    }
  }

  Future<void> loadDepartmentPerformance({String? district}) async {
    if (_token == null) return;
    try {
      _departmentPerformance = await ApiService.getDepartmentPerformance(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading department performance: $e');
      _departmentPerformance = {};
    }
  }

  Future<void> loadWorkerPerformance({String? district}) async {
    if (_token == null) return;
    try {
      _workerPerformance = await ApiService.getWorkerPerformance(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading worker performance: $e');
      _workerPerformance = {};
    }
  }

  Future<void> loadIssueTypesDistribution({String? district}) async {
    if (_token == null) return;
    try {
      _issueTypesDistribution = await ApiService.getIssueTypesDistribution(
        token: _token!,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading issue types distribution: $e');
      _issueTypesDistribution = {};
    }
  }

  Future<void> loadHeatMapData({String? district}) async {
    if (_token == null) return;
    try {
      _heatMapData = await ApiService.getHeatMapData(
        token: _token!,
        district: district,
      );
    } catch (e) {
      debugPrint('Error loading heat map data: $e');
      // Set empty data instead of failing - heatmap is optional
      _heatMapData = {'heat_points': [], 'total_clusters': 0};
    }
  }

  Future<Map<String, dynamic>> exportAnalyticsCSV(
    String reportType, {
    String? district,
  }) async {
    if (_token == null) {
      throw Exception('Authentication required');
    }
    try {
      return await ApiService.exportAnalyticsCSV(
        token: _token!,
        reportType: reportType,
        startDate: formattedStartDate,
        endDate: formattedEndDate,
        district: district,
      );
    } catch (e) {
      throw Exception('Failed to export analytics data: $e');
    }
  }

  // Helpers
  List<Map<String, dynamic>> getDailyTrendsData() {
    if (!_dailyTrends.containsKey('daily_trends')) return [];
    return List<Map<String, dynamic>>.from(_dailyTrends['daily_trends']);
  }

  List<Map<String, dynamic>> getDepartmentPerformanceData() {
    if (!_departmentPerformance.containsKey('departments')) return [];
    return List<Map<String, dynamic>>.from(
        _departmentPerformance['departments']);
  }

  List<Map<String, dynamic>> getWorkerPerformanceData() {
    if (!_workerPerformance.containsKey('workers')) return [];
    return List<Map<String, dynamic>>.from(_workerPerformance['workers']);
  }

  List<Map<String, dynamic>> getIssueTypesDistributionData() {
    if (!_issueTypesDistribution.containsKey('issue_types')) return [];
    return List<Map<String, dynamic>>.from(
        _issueTypesDistribution['issue_types']);
  }

  void clearData() {
    _dailyTrends = {};
    _weeklyTrends = {};
    _monthlyTrends = {};
    _departmentPerformance = {};
    _workerPerformance = {};
    _issueTypesDistribution = {};
    _heatMapData = {};
    _error = null;
    notifyListeners();
  }
}
