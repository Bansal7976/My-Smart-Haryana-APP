import 'package:flutter/material.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/api_service.dart';

class IssueProvider with ChangeNotifier {
  List<Issue> _userIssues = [];
  List<Issue> _assignedTasks = [];
  List<Issue> _allProblems = [];
  bool _isLoading = false;
  String? _error;

  List<Issue> get userIssues => _userIssues;
  List<Issue> get assignedTasks => _assignedTasks;
  List<Issue> get allProblems => _allProblems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserIssues(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final issuesData = await ApiService.getUserIssues(token);
      _userIssues = issuesData.map((data) => Issue.fromJson(data)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignedTasks(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tasksData = await ApiService.getAssignedTasks(token);
      _assignedTasks = tasksData.map((data) => Issue.fromJson(data)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllProblems(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final problemsData = await ApiService.getAllProblems(token);
      _allProblems = problemsData.map((data) => Issue.fromJson(data)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addIssue(
    String title,
    String description,
    String problemType,
    String district,
    double latitude,
    double longitude,
    File imageFile,
    String token,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.createIssue(
        token,
        title,
        description,
        problemType,
        district,
        latitude,
        longitude,
        imageFile,
      );
      
      // Reload user issues
      await loadUserIssues(token);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTask(
    String taskId, 
    File proofImage, 
    double latitude, 
    double longitude,
    String token
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.completeTask(token, taskId, proofImage, latitude, longitude);
      
      // Reload assigned tasks
      await loadAssignedTasks(token);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Issue?> getIssueDetails(String issueId, String token) async {
    try {
      final issueData = await ApiService.getIssueDetails(token, issueId);
      return Issue.fromJson(issueData);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

