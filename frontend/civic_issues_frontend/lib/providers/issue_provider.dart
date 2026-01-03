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
      
      // Reload user issues to show the new issue
      await loadUserIssues(token);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Parse and improve error messages for better user experience
      String errorMessage = e.toString();
      
      if (errorMessage.contains('AI-generated') || errorMessage.contains('heavily edited')) {
        _error = 'Please upload a real photo taken with your camera. Edited or AI-generated images are not allowed.';
      } else if (errorMessage.contains('already been reported') || errorMessage.contains('already exists')) {
        _error = 'This issue has already been reported. Please check existing reports or take a new photo if this is a different problem.';
      } else if (errorMessage.contains('too many reports') || errorMessage.contains('Too many requests')) {
        _error = 'You have submitted too many reports recently. Please wait a few minutes before submitting another report.';
      } else if (errorMessage.contains('suspicious activity')) {
        _error = 'Your report could not be submitted. Please contact support if you believe this is an error.';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('connection')) {
        _error = 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.contains('Failed to create issue')) {
        _error = 'Failed to submit your report. Please try again or contact support if the problem persists.';
      } else {
        // For any other errors, show a generic message
        _error = 'Unable to submit your report. Please try again later.';
      }
      
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

