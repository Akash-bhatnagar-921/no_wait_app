import 'package:flutter/material.dart';
import 'package:no_wait_app/main.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bookingNotifications = true;
  bool _promotionalNotifications = false;
  bool _smsAlerts = true;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 48 : 16,
          vertical: 20,
        ),
        child: Column(
          children: [
            // ── Notifications ──────────────────────────────────────────────
            _sectionCard(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              children: [
                _toggleTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Booking Reminders',
                  subtitle: 'Get notified before your appointments',
                  value: _bookingNotifications,
                  onChanged: (v) =>
                      setState(() => _bookingNotifications = v),
                ),
                _divider(),
                _toggleTile(
                  icon: Icons.local_offer_outlined,
                  title: 'Offers & Promotions',
                  subtitle: 'Receive deals from nearby salons',
                  value: _promotionalNotifications,
                  onChanged: (v) =>
                      setState(() => _promotionalNotifications = v),
                ),
                _divider(),
                _toggleTile(
                  icon: Icons.sms_outlined,
                  title: 'SMS Alerts',
                  subtitle: 'Receive booking confirmations via SMS',
                  value: _smsAlerts,
                  onChanged: (v) =>
                      setState(() => _smsAlerts = v),
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Account ────────────────────────────────────────────────────
            _sectionCard(
              title: 'Account',
              icon: Icons.person_outline,
              children: [
                _navTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () {},
                ),
                _divider(),
                _navTile(
                  icon: Icons.phone_outlined,
                  title: 'Update Phone Number',
                  onTap: () {},
                ),
                _divider(),
                _navTile(
                  icon: Icons.mail_outline,
                  title: 'Update Email Address',
                  onTap: () {},
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Support ────────────────────────────────────────────────────
            _sectionCard(
              title: 'Support',
              icon: Icons.support_agent_outlined,
              children: [
                _navTile(
                  icon: Icons.help_outline,
                  title: 'Help & FAQ',
                  onTap: () {},
                ),
                _divider(),
                _navTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'Contact Support',
                  subtitle: '+91-9999999999',
                  onTap: () => AppSnackbar.info(
                    context,
                    'Call us @ +91-9999999999',
                    actionLabel: '✕',
                  ),
                ),
                _divider(),
                _navTile(
                  icon: Icons.star_outline,
                  title: 'Rate the App',
                  onTap: () {},
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Danger zone ────────────────────────────────────────────────
            _sectionCard(
              title: 'Account Actions',
              icon: Icons.warning_amber_outlined,
              children: [
                _navTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  titleColor: Colors.orange.shade700,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final confirmed = await _confirmDialog(
                      context,
                      icon: Icons.logout,
                      iconColor: Colors.orange.shade700,
                      title: 'Logout',
                      body: 'Are you sure you want to log out of your account?',
                      confirmLabel: 'Yes, Logout',
                      confirmColor: Colors.orange.shade700,
                    );
                    if (confirmed != true) return;
                    await ApiService.logout();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const RoleSelectionScreen()),
                      (route) => false,
                    );
                  },
                ),
                _divider(),
                _navTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  titleColor: Colors.red,
                  onTap: () => _handleDeleteAccount(),
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              'Baari v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleDeleteAccount() async {
    // Capture all context-dependent objects BEFORE any await
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await _confirmDialog(
      context,
      icon: Icons.delete_forever_outlined,
      iconColor: Colors.red,
      title: 'Delete Account',
      body: 'This action is permanent and cannot be undone.\n\n'
          'All your data — bookings, profile, and history — will be '
          'erased immediately.',
      confirmLabel: 'Yes, Delete',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingWidget(message: 'Deleting account…'),
    );

    try {
      await ApiService.deleteAccount();
      await ApiService.logout();
      navigator.pop(); // close loader
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      navigator.pop(); // close loader
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Failed to delete account';
      AppSnackbar.errorM(messenger, msg);
    }
  }

  /// Generic confirmation dialog — returns true when user confirms.
  Future<bool?> _confirmDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding:
            const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(body,
            style: const TextStyle(
                color: Colors.black54, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 12 : 0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: 14, horizontal: isLast ? 0 : 0),
        child: Row(
          children: [
            Icon(icon,
                color: titleColor ?? Colors.black54, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: titleColor ?? Colors.black),
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: titleColor?.withValues(alpha: 0.5) ??
                    Colors.grey.shade400,
                size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: Colors.grey.shade100,
        indent: 34,
      );
}
