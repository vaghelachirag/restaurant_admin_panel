import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final String role;

  const Sidebar({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 40),

          menuItem(Icons.dashboard, "Dashboard"),

          if (role == "super_admin")
            menuItem(Icons.restaurant, "Restaurants"),

          if (role == "super_admin")
            menuItem(Icons.people, "Users"),

          menuItem(Icons.category, "Categories"),
          menuItem(Icons.fastfood, "Menu Items"),
        ],
      ),
    );
  }

  Widget menuItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
    );
  }
}