import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/firebase_notification_service.dart';

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

      // Connect to real-time notifications
      _connectToNotifications();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Clean up error message for display
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage =
            errorMessage.substring(11); // Remove 'Exception: ' prefix
      }
      _error = errorMessage;
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
      final loginResponse =
          await ApiService.login(userData['email'], userData['password']);
      _token = loginResponse['access_token'];
      _user = User.fromJson(loginResponse['user']);

      await _secureStorage.write(key: 'access_token', value: _token);

      // Connect to real-time notifications after registration
      _connectToNotifications();

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

  /// ✅ Safely log out user and clear secure storage
  Future<void> logout() async {
    // Disconnect from real-time notifications
    _disconnectFromNotifications();

    _user = null;
    _token = null;
    _error = null;
    await _secureStorage.delete(key: 'access_token');
    // Use SchedulerBinding to defer notifyListeners until after current frame
    // This prevents accessing deactivated widget context
    await Future.microtask(() {
      notifyListeners();
    });
  }

  /// Connect to Firebase push notifications
  void _connectToNotifications() {
    if (_token != null) {
      try {
        // Initialize Firebase and send FCM token
        _initializeFirebaseNotifications();
      } catch (e) {
        debugPrint('❌ Failed to connect to notifications: $e');
      }
    }
  }

  /// Initialize Firebase push notifications
  Future<void> _initializeFirebaseNotifications() async {
    if (_token == null) return;

    try {
      final firebaseService = FirebaseNotificationService();
      await firebaseService.initialize();

      // Send FCM token to backend
      await firebaseService.sendTokenToBackend(_token!);
      debugPrint('✅ Firebase notifications initialized and token sent to backend');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase: $e');
    }
  }

  /// Disconnect from notifications (cleanup)
  void _disconnectFromNotifications() {
    // Firebase notifications don't need explicit disconnect
    // They are managed by the system
    debugPrint('🔌 Notifications cleanup completed');
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
