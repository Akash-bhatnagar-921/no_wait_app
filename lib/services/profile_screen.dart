import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile_model.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';
import 'package:no_wait_app/widgets/profile_completion_widget.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/role_selection_screen.dart';

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
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Completion bar ───────────────────────────────────────────────
            ProfileCompletionWidget(
              percent: customerCompletion(
                fullName: user?.fullName ?? '',
                email:    user?.email    ?? '',
                gender:   user?.gender,
                age:      user?.age,
              ),
              label: 'Profile completion',
            ),
            const SizedBox(height: 16),

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

                        Builder(builder: (ctx) {
                          final ph = user?.phone ?? '';
                          return _contactRow(
                            Icons.call_outlined,
                            ph,
                            onTap: ph.isNotEmpty ? () => _callPhone(ph) : null,
                          );
                        }),
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
                // ── Editable: Gender ──────────────────────────────────────────
                _editableTile(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: _genderLabel(user?.gender),
                  isEmpty: user?.gender == null || user!.gender!.isEmpty,
                  onTap: _showGenderPicker,
                ),
                // ── Editable: Age ─────────────────────────────────────────────
                _editableTile(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: user?.age != null ? '${user!.age} yrs' : '',
                  isEmpty: user?.age == null,
                  onTap: _showAgePicker,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 12),
            _profileCard(
              title: 'Account History',
              children: [
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
                _navTile(
                  Icons.logout,
                  'Logout',
                  color: Colors.orange.shade700,
                  isLast: true,
                  onTap: _handleLogout,
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
    ),   // RefreshIndicator
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _contactRow(IconData icon, String text, {VoidCallback? onTap}) {
    final isPhone = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: isPhone ? Colors.green.shade600 : _subtleText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isPhone ? Colors.green.shade700 : _onSurface,
                decoration:
                    isPhone ? TextDecoration.underline : TextDecoration.none,
                fontWeight:
                    isPhone ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (isPhone)
            Icon(Icons.call_outlined, size: 15, color: Colors.green.shade600),
        ],
      ),
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

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Logout'),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ApiService.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  // ── Gender & Age helpers ───────────────────────────────────────────────────

  String _genderLabel(String? g) {
    switch (g?.toLowerCase()) {
      case 'male':   return 'Male';
      case 'female': return 'Female';
      case 'other':  return 'Other';
      default:       return '';
    }
  }

  /// Tile that shows a value (or a prompt when empty) with a pencil edit icon.
  Widget _editableTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isEmpty,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: _onSurface.withValues(alpha: 0.08))),
        ),
        child: Row(children: [
          Icon(icon, color: _subtleText, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: _onSurface)),
          ),
          Text(
            isEmpty ? 'Tap to add' : value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
              color: isEmpty ? _subtleText : _onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.edit_outlined, size: 15, color: _subtleText),
        ]),
      ),
    );
  }

  // ── Gender picker ──────────────────────────────────────────────────────────

  Future<void> _showGenderPicker() async {
    final options = [
      ('male',   'Male',   Icons.man_outlined),
      ('female', 'Female', Icons.woman_outlined),
      ('other',  'Other',  Icons.transgender_outlined),
    ];
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Select Gender',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...options.map((o) {
              final (value, label, iconData) = o;
              final selected = user?.gender?.toLowerCase() == value;
              return ListTile(
                leading: Icon(iconData,
                    color: selected ? _primary : Colors.grey.shade600),
                title: Text(label,
                    style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color:
                            selected ? _primary : _onSurface)),
                trailing: selected
                    ? Icon(Icons.check_circle_rounded,
                        color: _primary)
                    : null,
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  final nav = Navigator.of(ctx);
                  nav.pop();
                  try {
                    await ApiService.updateProfile({'gender': value});
                    if (!mounted) return;
                    setState(() {
                      user = UserProfileModel(
                        id:        user?.id ?? '',
                        fullName:  user?.fullName ?? '',
                        phone:     user?.phone ?? '',
                        email:     user?.email ?? '',
                        role:      user?.role ?? '',
                        age:       user?.age,
                        gender:    value,
                        createdAt: user?.createdAt,
                      );
                    });
                  } catch (_) {
                    AppSnackbar.errorM(messenger, 'Failed to update gender.');
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Age picker ─────────────────────────────────────────────────────────────

  Future<void> _showAgePicker() async {
    final ctrl      = TextEditingController(
        text: user?.age != null ? '${user!.age}' : '');
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Age',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 3,
          decoration: InputDecoration(
            hintText: 'Enter your age',
            filled: true,
            fillColor: Colors.grey.shade100,
            counterText: '',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final age = int.tryParse(ctrl.text.trim());
              if (age == null || age < 1 || age > 120) return;
              final nav = Navigator.of(ctx);
              nav.pop();
              try {
                await ApiService.updateProfile({'age': age});
                if (!mounted) return;
                setState(() {
                  user = UserProfileModel(
                    id:        user?.id ?? '',
                    fullName:  user?.fullName ?? '',
                    phone:     user?.phone ?? '',
                    email:     user?.email ?? '',
                    role:      user?.role ?? '',
                    age:       age,
                    gender:    user?.gender,
                    createdAt: user?.createdAt,
                  );
                });
              } catch (_) {
                AppSnackbar.errorM(messenger, 'Failed to update age.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
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
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      final nav = Navigator.of(ctx);
                      try {
                        await ApiService.updateProfile({'fullName': name});
                        nav.pop();
                        if (!mounted) return;
                        setState(() {
                          user = UserProfileModel(
                            id:        user?.id ?? '',
                            fullName:  name,
                            phone:     user?.phone ?? '',
                            email:     user?.email ?? '',
                            role:      user?.role ?? '',
                            age:       user?.age,
                            gender:    user?.gender,
                            createdAt: user?.createdAt,
                          );
                        });
                      } catch (_) {
                        nav.pop();
                      }
                    },
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
