import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/issue_provider.dart';
import 'providers/analytics_provider.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';

// Utils & Widgets
import 'utils/app_theme.dart';
import 'widgets/notification_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 FIX: Initialize Firebase before running app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => IssueProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: Consumer2<AuthProvider, LanguageProvider>(
        builder: (context, authProvider, languageProvider, child) {
          return MaterialApp(
            title: 'Smart Haryana',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Loading indicator while checking authentication
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If authenticated → wrap dashboard with real-time notifications
    if (authProvider.isAuthenticated) {
      return const RealtimeNotificationListener(
        child: DashboardScreen(),
      );
    } else {
      return const LoginScreen();
    }
  }
}
