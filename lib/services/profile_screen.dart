import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          user = res;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Shortcuts ──────────────────────────────────────────────────────────────
  ColorScheme get _cs => Theme.of(context).colorScheme;
  Color get _primary => _cs.primary;
  Color get _onSurface => _cs.onSurface;
  Color get _surface => _cs.surface;
  Color get _subtleText => _cs.onSurface.withValues(alpha: 0.55);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading profile…'),
      );
    }

    final formattedDate = user?.createdAt != null
        ? DateFormat('MMMM yyyy').format(DateTime.parse(user!.createdAt!))
        : '—';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Hero card ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    height: 85,
                    width: 85,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: user?.fullName.isNotEmpty == true
                          ? Text(
                              user!.fullName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            )
                          : Icon(Icons.person, size: 40, color: _primary),
                    ),
                  ),

                  const SizedBox(width: 18),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + edit
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                user?.fullName ?? '',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _onSurface,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showEditNameDialog(context),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _primary),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.edit,
                                    size: 18, color: _primary),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.role ?? '',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        _contactRow(Icons.call_outlined, user?.phone ?? ''),
                        const SizedBox(height: 10),
                        _contactRow(Icons.mail_outline, user?.email ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Personal info ─────────────────────────────────────────────────
            _profileCard(
              title: 'Personal Information',
              children: [
                _profileTile(Icons.person_outline, 'Full Name',
                    user?.fullName ?? ''),
                _profileTile(Icons.call_outlined, 'Phone Number',
                    user?.phone ?? ''),
                _profileTile(Icons.mail_outline, 'Email Address',
                    user?.email ?? ''),
                _profileTile(
                    Icons.calendar_today_outlined, 'Member Since',
                    formattedDate,
                    isLast: true),
              ],
            ),

            const SizedBox(height: 20),

            // ── Account ────────────────────────────────────────────────────────
            _profileCard(
              title: 'Account',
              children: [
                _navTile(Icons.lock_outline, 'Change Password',
                    onTap: () {}),
                _navTile(
                  Icons.logout,
                  'Logout',
                  color: Colors.red,
                  isLast: true,
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Security note ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: _primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: _primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your data is safe and secure with us.',
                      style: TextStyle(
                          color: _primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _subtleText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: _onSurface),
          ),
        ),
      ],
    );
  }

  // ── Card & tile builders ───────────────────────────────────────────────────

  Widget _profileCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: _onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _onSurface),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _profileTile(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: _onSurface.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Icon(icon, color: _subtleText, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: _onSurface)),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _onSurface),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    IconData icon,
    String title, {
    Color? color,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    final c = color ?? _onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: _onSurface.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 15, color: c)),
            ),
            Icon(Icons.chevron_right,
                color: c.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Edit name dialog ───────────────────────────────────────────────────────

  void _showEditNameDialog(BuildContext ctx) {
    final primary = Theme.of(ctx).colorScheme.primary;
    final controller =
        TextEditingController(text: user?.fullName ?? '');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Update Name',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter new name',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Save Changes',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
