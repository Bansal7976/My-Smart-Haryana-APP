import 'package:flutter/material.dart';
import 'manage_departments_screen.dart';

class AdminDepartmentsScreen extends StatelessWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Directly navigate to manage departments screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ManageDepartmentsScreen(),
        ),
      );
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Or use this simple redirect version:
/*
class AdminDepartmentsScreen extends StatelessWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ManageDepartmentsScreen();
  }
}
*/


