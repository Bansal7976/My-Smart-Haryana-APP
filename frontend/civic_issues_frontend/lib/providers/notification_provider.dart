import 'package:flutter/material.dart';

/// Notification Provider - Firebase Push Notifications Only
/// WebSocket support has been removed
class NotificationProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  /// Add notification (called by Firebase service)
  void addNotification(Map<String, dynamic> data) {
    debugPrint('📬 New notification: ${data['title']}');

    // Add to notifications list
    _notifications.insert(0, {
      ...data,
      'read': false,
      'receivedAt': DateTime.now(),
    });

    // Increment unread count
    _unreadCount++;

    // Keep only last 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }

    notifyListeners();
  }

  /// Mark notification as read
  void markAsRead(int index) {
    if (index < _notifications.length && !_notifications[index]['read']) {
      _notifications[index]['read'] = true;
      _unreadCount--;
      notifyListeners();
    }
  }

  /// Mark all as read
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification['read'] = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
