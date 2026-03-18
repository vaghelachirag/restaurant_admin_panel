import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/sidebar.dart';
import '../widgets/topbar.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String role;

  const AdminLayout({
    super.key,
    required this.child,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(role: role),

          Expanded(
            child: Column(
              children: [
                const Topbar(title: "Resturant", userName: "Chirag"),
                Expanded(child: child),
              ],
            ),
          )
        ],
      ),
    );
  }
}