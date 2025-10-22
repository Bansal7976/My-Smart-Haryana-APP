import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = false;
  String? _error;
  String? _token;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;

  AuthProvider() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null) {
        _token = token;
        final profileData = await ApiService.getUserProfile(token);
        _user = User.fromJson(profileData);
      }
    } catch (e) {
      _error = e.toString();
      await _secureStorage.delete(key: 'access_token');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);
      _token = response['access_token'];
      _user = User.fromJson(response['user']);
      
      await _secureStorage.write(key: 'access_token', value: _token);
      
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

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(userData);
      _user = User.fromJson(response);
      
      // Auto-login after registration
      final loginResponse = await ApiService.login(userData['email'], userData['password']);
      _token = loginResponse['access_token'];
      _user = User.fromJson(loginResponse['user']);
      
      await _secureStorage.write(key: 'access_token', value: _token);
      
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

  Future<void> logout() async {
    _user = null;
    _token = null;
    _error = null;
    await _secureStorage.delete(key: 'access_token');
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token != null) {
      try {
        final profileData = await ApiService.getUserProfile(_token!);
        _user = User.fromJson(profileData);
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }
}

