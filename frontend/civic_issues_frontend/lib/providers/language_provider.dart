import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _initializeLanguage();
  }

  // Load saved language safely
  Future<void> _initializeLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language');

    if (savedLanguage != null && savedLanguage != _currentLanguage) {
      _currentLanguage = savedLanguage;
      notifyListeners();
    }
  }

  // Change language + save in preferences
  Future<void> setLanguage(String language) async {
    if (language == _currentLanguage) return; // avoid extra rebuilds

    _currentLanguage = language;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);

    notifyListeners();
  }

  // Helper to get correct text
  String getText(String english, String hindi) {
    return _currentLanguage == 'hi' ? hindi : english;
  }

  bool get isHindi => _currentLanguage == 'hi';
  bool get isEnglish => _currentLanguage == 'en';
}
