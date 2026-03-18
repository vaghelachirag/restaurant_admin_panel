import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class Topbar extends StatelessWidget {
  final String title;
  final String userName;
  final VoidCallback? onLogout;

  const Topbar({
    super.key,
    required this.title,
    required this.userName,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE5E7EB)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// Page Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          Row(
            children: [

              /// Search Field
              Container(
                width: 250,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search...",
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              /// Notification
              const Icon(Icons.notifications_none, size: 26),

              const SizedBox(width: 20),

              /// User Profile
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 18),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    userName,
                    style: const TextStyle(fontSize: 14),
                  ),

                  PopupMenuButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "profile",
                        child: Text("Profile"),
                      ),
                      const PopupMenuItem(
                        value: "logout",
                        child: Text("Logout"),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == "logout" && onLogout != null) {
                        onLogout!();
                      }
                    },
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}