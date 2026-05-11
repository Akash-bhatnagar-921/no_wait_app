import 'package:flutter/material.dart';
import 'package:no_wait_app/main.dart'; // 👈 correct screen import
import 'package:no_wait_app/services/api_service.dart';
import '../services/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          /// HEADER
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6FCF97)),
            accountName: Text(
              ApiService.loginData['user']['fullName']?.toString() ?? '',
            ),
            accountEmail: Text(
              ApiService.loginData['user']['email']?.toString() ?? '',
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 30),
            ),
          ),

          /// MENU ITEMS
          _item(
            context,
            Icons.person,
            "Profile",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          _item(context, Icons.book, "My Bookings"),
          _item(context, Icons.subscriptions, "Subscriptions"),
          _item(context, Icons.lock, "Privacy Policy"),
          _item(context, Icons.settings, "Settings"),

          // const Spacer(),

          /// 🔥 LOGOUT (FIXED)
          _item(
            context,
            Icons.logout,
            "Logout",
            onTap: () async {
              await ApiService.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MyApp()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 🔧 FIXED ITEM FUNCTION
  Widget _item(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap, // ✅ added
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6FCF97)),
      title: Text(title),
      onTap:
          onTap ??
          () {
            Navigator.pop(context);
          },
    );
  }
}
