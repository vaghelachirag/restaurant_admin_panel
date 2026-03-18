import 'package:flutter/material.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Super Admin Dashboard",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}