import 'package:flutter/material.dart';
import 'package:no_wait_app/main.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/models/user_profile_model.dart';
import 'package:no_wait_app/theme/theme_manager.dart';
import 'package:no_wait_app/theme/app_theme.dart';
import '../services/profile_screen.dart';
import '../my_bookings_screen.dart';
import '../subscriptions_screen.dart';
import '../privacy_policy_screen.dart';
import '../settings_screen.dart';

/// Navigation drawer for the customer side.
///
/// Converted to StatefulWidget so the profile is fetched once in initState
/// and cached — it does NOT re-fetch on every rebuild (e.g. theme changes).
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  UserProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Rebuild drawer header when theme changes without re-fetching data
    ThemeManager.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeManager.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ApiService.getProfile();
      if (mounted) setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.current;
    final primary = ThemeManager.instance.primaryColor;

    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          UserAccountsDrawerHeader(
            decoration: _headerDecoration(theme),
            accountName: _loading
                ? const Text('Loading…',
                    style: TextStyle(color: Colors.white70))
                : Text(
                    _profile?.fullName.isNotEmpty == true
                        ? _profile!.fullName
                        : 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
            accountEmail: _loading
                ? const Text('')
                : Text(_profile?.email ?? ''),
            currentAccountPicture: _loading
                ? CircleAvatar(
                    backgroundColor: Colors.white,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primary),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: Colors.white,
                    child: _profile?.fullName.isNotEmpty == true
                        ? Text(
                            _profile!.fullName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          )
                        : Icon(Icons.person, size: 30, color: primary),
                  ),
          ),

          // ── Menu items ───────────────────────────────────────────────────
          _item(context, Icons.person, 'Profile', onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
          _item(context, Icons.book_outlined, 'My Bookings', onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
          }),
          _item(context, Icons.subscriptions_outlined, 'Subscriptions',
              onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
          }),
          _item(context, Icons.shield_outlined, 'Privacy Policy', onTap: () {
            Navigator.pop(context);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen()));
          }),
          _item(context, Icons.settings_outlined, 'Settings', onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),

          _item(
            context,
            Icons.logout,
            'Logout',
            onTap: () async {
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    final primary = ThemeManager.instance.primaryColor;
    return ListTile(
      leading: Icon(icon, color: primary),
      title: Text(title),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  static BoxDecoration _headerDecoration(GenderTheme theme) {
    switch (theme) {
      case GenderTheme.male:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFF2C2410), Color(0xFF1A1A1A)],
            stops: [0.0, 0.5, 1.0],
          ),
        );
      case GenderTheme.other:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFE53935),
              Color(0xFFFF9800),
              Color(0xFFFDD835),
              Color(0xFF43A047),
              Color(0xFF1E88E5),
              Color(0xFF8E24AA),
            ],
          ),
        );
      case GenderTheme.female:
        return const BoxDecoration(color: Color(0xFF6FCF97));
    }
  }
}
