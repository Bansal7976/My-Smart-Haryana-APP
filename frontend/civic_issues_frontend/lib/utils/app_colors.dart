import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Navy Blue & Gold Professional Theme
  static const Color primary = Color(0xFF1A237E); // Navy Blue
  static const Color secondary = Color(0xFFFFB300); // Gold
  static const Color accent = Color(0xFF3F51B5); // Indigo
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Issue Status Colors
  static const Color pending = Color(0xFFFF9800);
  static const Color inProgress = Color(0xFF2196F3);
  static const Color completed = Color(0xFF4CAF50);
  static const Color rejected = Color(0xFFF44336);
  
  // Priority Colors
  static const Color highPriority = Color(0xFFF44336);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color lowPriority = Color(0xFF4CAF50);
  
  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  
  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0A000000);
  
  // Role-specific Colors
  static const Color clientColor = Color(0xFF4CAF50);
  static const Color workerColor = Color(0xFF2196F3);
  static const Color adminColor = Color(0xFF9C27B0);
  static const Color superAdminColor = Color(0xFFE91E63);
  
  // Gradients
  static const List<Color> primaryGradient = [primary, accent];
  static const List<Color> clientGradient = [clientColor, Color(0xFF66BB6A)];
  static const List<Color> workerGradient = [workerColor, Color(0xFF42A5F5)];
  static const List<Color> adminGradient = [adminColor, Color(0xFFBA68C8)];
  static const List<Color> superAdminGradient = [superAdminColor, Color(0xFFF06292)];
  
  // Chart Colors
  static const List<Color> chartColors = [
    primary,
    secondary,
    success,
    warning,
    error,
    info,
    Color(0xFF9C27B0),
    Color(0xFF607D8B),
  ];
  
  // Helper method to get role display name
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'client':
        return 'Citizen';
      case 'worker':
        return 'Worker';
      case 'admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role;
    }
  }
}


