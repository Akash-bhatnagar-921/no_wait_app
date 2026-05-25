import 'package:flutter/material.dart';
import 'package:no_wait_app/admin/tabs/admin_dashboard_tab.dart';
import 'package:no_wait_app/admin/tabs/admin_users_tab.dart';
import 'package:no_wait_app/admin/tabs/admin_salons_tab.dart';
import 'package:no_wait_app/admin/tabs/admin_bookings_tab.dart';
import 'package:no_wait_app/admin/tabs/admin_more_tab.dart';

const Color kAdminPrimary = Color(0xFF1565C0);

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  const AdminHomeScreen({super.key, required this.adminName});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardTab(adminName: widget.adminName),
      const AdminUsersTab(),
      const AdminSalonsTab(),
      const AdminBookingsTab(),
      AdminMoreTab(adminName: widget.adminName),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: kAdminPrimary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: kAdminPrimary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: kAdminPrimary),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store, color: kAdminPrimary),
            label: 'Salons',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: kAdminPrimary),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz, color: kAdminPrimary),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
