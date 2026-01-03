import 'package:flutter/material.dart';
import '../services/firebase_notification_service.dart';

/// Firebase Notification Listener - Notification Tray Only
/// WebSocket support has been removed - all notifications via Firebase
class RealtimeNotificationListener extends StatefulWidget {
  final Widget child;

  const RealtimeNotificationListener({super.key, required this.child});

  @override
  State<RealtimeNotificationListener> createState() =>
      _RealtimeNotificationListenerState();
}

class _RealtimeNotificationListenerState
    extends State<RealtimeNotificationListener> {
  final FirebaseNotificationService _firebaseService =
      FirebaseNotificationService();

  @override
  void initState() {
    super.initState();
    _initializeFirebaseNotifications();
  }

  Future<void> _initializeFirebaseNotifications() async {
    // Initialize Firebase notifications
    await _firebaseService.initialize();
    debugPrint('✅ Firebase notifications initialized');
  }

  @override
  Widget build(BuildContext context) {
    // Just return the child - Firebase handles notifications in background
    // Notifications will appear in system tray automatically
    return widget.child;
  }
}
