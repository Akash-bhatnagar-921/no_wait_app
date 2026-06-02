import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, HapticFeedback, LengthLimitingTextInputFormatter, SystemNavigator;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/role_selection_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/star_rating.dart';
import 'package:no_wait_app/widgets/profile_completion_widget.dart';
import 'package:no_wait_app/map_screen.dart';
import 'package:no_wait_app/services/location_prefs.dart';
import 'professional_services_screen.dart';
import 'manage_barbers_screen.dart';
import 'package:no_wait_app/settings_screen.dart';

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _salon;
  List<Map<String, dynamic>> _allSalons = [];   // full list for switcher
  Map<String, dynamic> _salonStats = {};
  List<Map<String, dynamic>> _todayBookings = [];
  List<Map<String, dynamic>> _myReviews = [];
  bool _showClosingReminder = false;

  // ── Derived getters so the build tree stays clean ─────────────────────────
  // Manager = the authenticated user who registered/manages this salon
  Map<String, dynamic>? get _managerData =>
      _salon?['manager'] as Map<String, dynamic>?;

  String get _managerName => _managerData?['fullName'] as String? ?? '';
  String get _managerPhone => _managerData?['phone'] as String? ?? '';
  String get _managerEmail => _managerData?['email'] as String? ?? '';
  String get _salonName => _salon?['name'] as String? ?? 'Your Salon';
  String get _contactNumber =>
      (_salon?['contactNumber'] as String?) ?? _managerPhone;
  String get _salonLocation {
    final parts = [
      _salon?['address'] as String?,
      _salon?['city'] as String?,
    ].where((e) => e != null && e.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get _initials {
    // Filter out empty segments so '' or whitespace-only names return 'P'
    final words = _managerName.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'P';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        ApiService.getMySalons(),
        ApiService.getSalonBookings(),
        ApiService.getMyReviews(),
      ]);
      if (!mounted) return;
      final salons      = results[0] as List<dynamic>;
      final salonData   = results[1] as Map<String, dynamic>;
      final reviewsRaw  = results[2] as List<dynamic>;
      final allBookings = (salonData['bookings'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final stats = salonData['stats'] as Map<String, dynamic>? ?? {};
      final today = DateTime.now();
      setState(() {
        _allSalons  = salons.cast<Map<String, dynamic>>();
        // Keep the previously-selected salon if still present; otherwise default to first
        final prevId = _salon?['id'] as String?;
        _salon = prevId != null
            ? (_allSalons.firstWhere(
                    (s) => s['id'] == prevId,
                    orElse: () => _allSalons.isNotEmpty
                        ? _allSalons[0]
                        : <String, dynamic>{})
                as Map<String, dynamic>?)
            : (_allSalons.isNotEmpty ? _allSalons[0] : null);
        _salonStats = stats;
        _myReviews  = reviewsRaw.cast<Map<String, dynamic>>();
        final todayRaw = allBookings.where((b) {
          final status = b['status'] as String? ?? '';
          if (status == 'cancelled' || status == 'rejected' || status == 'completed') {
            return false;
          }
          final dt = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
          if (dt == null) return false;
          final local = dt.toLocal();
          return local.year == today.year &&
              local.month == today.month &&
              local.day == today.day;
        }).toList();
        // Sort ascending by scheduled time so "next up" is always first.
        todayRaw.sort((a, b) {
          final da = DateTime.tryParse(a['scheduledAt'] as String? ?? '');
          final db = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
        _todayBookings = todayRaw;
        _isLoading = false;
      });

      // Check if salon is still marked open 15+ min past its closing time
      _checkClosingReminder();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkClosingReminder() {
    if (_salon == null) return;
    final isOpen      = _salon!['isOpen'] as bool? ?? false;
    final closingStr  = _salon!['closingTime'] as String? ?? '';
    if (!isOpen || closingStr.isEmpty) return;

    final parts = closingStr.split(':');
    if (parts.length < 2) return;
    final now = DateTime.now();
    final closing = DateTime(
      now.year, now.month, now.day,
      int.tryParse(parts[0]) ?? 21,
      int.tryParse(parts[1]) ?? 0,
    );
    final reminder = closing.add(const Duration(minutes: 15));
    if (now.isAfter(reminder) && mounted) {
      setState(() => _showClosingReminder = true);
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange, size: 22),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your professional account?',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Cancel',
                  style: TextStyle(color: Colors.grey))),
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

    if (confirmed != true) return;

    await ApiService.logout();
    if (!mounted) return;

    AppSnackbar.infoM(messenger, 'Logged out successfully');
    Navigator.of(navigator.context, rootNavigator: true)
        .pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.calendar_month),
              if (_asInt(_salonStats['pendingCount']) > 0)
                Positioned(
                  top: -4, right: -6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${_asInt(_salonStats['pendingCount'])}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ]),
            label: 'Appointments',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.currency_rupee), label: 'Earnings'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined), label: 'Subscription'),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const AppLoadingIndicator(message: 'Loading dashboard…')
            : _buildBody(),
      ),
    ), // Scaffold
    ); // PopScope
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _homePage();
      case 1:
        return const _ProAppointmentsTab();
      case 2:
        return const _EarningsTab();
      case 3:
        return _profilePage();
      case 4:
        return _subscriptionsPage();
      default:
        return _homePage();
    }
  }

  // ── HOME PAGE ──────────────────────────────────────────────────────────────

  Widget _homePage() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ────────────────────────────────────────────────────
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Baari',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Professional',
                  style: TextStyle(color: Colors.green, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 30),

          // ── Welcome ────────────────────────────────────────────────────
          const Text('Welcome,',
              style: TextStyle(fontSize: 20, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _salonName,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your salon professionally.',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),

          const SizedBox(height: 24),

          // ── Setup checklist (shown until all items are done) ──────────
          if (_salon != null) _setupChecklist(),

          // ── Salon switcher (only shown when 2+ salons) ────────────────
          if (_allSalons.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _allSalons.map((s) {
                  final selected = s['id'] == _salon?['id'];
                  return GestureDetector(
                    onTap: () {
                      if (!selected) setState(() => _salon = s);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.green.shade700 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected
                                ? Colors.green.shade700
                                : Colors.grey.shade300),
                        boxShadow: selected
                            ? [BoxShadow(
                                color: Colors.green.withValues(alpha: 0.25),
                                blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        s['name'] as String? ?? 'Salon',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Salon card ─────────────────────────────────────────────────
          _salonCard(),

          // ── Pending approval notice (shown until admin approves) ───────
          if ((_salon?['status'] as String?) == 'pending') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your salon is pending admin approval. '
                    'It will not appear in customer searches until approved. '
                    'Pull down on Profile to check for updates.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          // ── Closing-time reminder banner ───────────────────────────────
          if (_showClosingReminder) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                Icon(Icons.store_outlined,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Don't forget to mark your salon Closed for the day!",
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showClosingReminder = false),
                  child: Icon(Icons.close, size: 16,
                      color: Colors.orange.shade600),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 30),

          // ── Today's overview ───────────────────────────────────────────
          const Text("Today's Overview",
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),

          // ── Today at a Glance ─────────────────────────────────────────
          if (_salonStats.isNotEmpty) ...[
            Row(children: [
              _statChip(
                Icons.calendar_today_outlined,
                '${_asInt(_salonStats['todayBookings'])}',
                'Active Today',
                Colors.blue.shade600,
              ),
              const SizedBox(width: 12),
              _statChip(
                Icons.check_circle_outline,
                '${_asInt(_salonStats['completedToday'])}',
                'Completed',
                Colors.green.shade700,
              ),
              const SizedBox(width: 12),
              _statChip(
                Icons.pending_outlined,
                '${_asInt(_salonStats['pendingCount'])}',
                'Pending',
                Colors.orange.shade600,
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _statChip(
                Icons.currency_rupee,
                '₹${_asDouble(_salonStats['todayRevenue']).toStringAsFixed(0)}',
                'Today\'s Revenue',
                Colors.purple.shade600,
              ),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Today's Overview grid ─────────────────────────────────────
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              mainAxisExtent: 150,
            ),
            children: [
              overviewCard(
                  icon: Icons.content_cut,
                  title: 'Services',
                  value: '${(_salon?['services'] as List? ?? []).length}'),
              overviewCard(
                  icon: Icons.people_outline,
                  title: 'Barbers',
                  value: '${(_salon?['barbers'] as List? ?? []).length}'),
              overviewCard(
                  icon: Icons.star_outline,
                  title: 'Rating',
                  value: _asDouble(_salon?['rating']) > 0
                      ? _asDouble(_salon?['rating']).toStringAsFixed(1)
                      : 'New'),
              overviewCard(
                  icon: Icons.rate_review_outlined,
                  title: 'Reviews',
                  value: '${_asInt(_salon?['reviewCount'])}'),
            ],
          ),

          const SizedBox(height: 35),

          // ── Quick actions grid ─────────────────────────────────────────
          const Text('Quick Actions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),

          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              mainAxisExtent: 120,
            ),
            children: [
              actionCard(
                icon: Icons.calendar_month,
                title: 'Appointments',
                subtitle: 'Switch to appointments tab',
                onTap: () => setState(() => _currentIndex = 1),
              ),
              actionCard(
                icon: Icons.people_alt_outlined,
                title: 'Manage Barbers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageBarbersScreen()),
                ).then((_) => _fetchData()),
              ),
              actionCard(
                  icon: Icons.content_cut,
                  title: 'Services',
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfessionalServicesScreen()),
                    );
                    if (updated == true) _fetchData();
                  }),
              actionCard(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 35),

          // ── Today's appointments (real data) ───────────────────────────
          Row(children: [
            const Text("Today's Appointments",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_todayBookings.length} booking${_todayBookings.length == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ]),
          const SizedBox(height: 16),

          if (_todayBookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined,
                    size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text('No appointments today',
                    style: TextStyle(color: Colors.grey.shade500)),
              ]),
            )
          else
            Builder(builder: (ctx) {
              // The first pending/confirmed booking in the future is "next up"
              final now = DateTime.now();
              final nextUpId = _todayBookings.firstWhere(
                (b) {
                  final status = b['status'] as String? ?? '';
                  final dt = DateTime.tryParse(
                      b['scheduledAt'] as String? ?? '');
                  return (status == 'pending' || status == 'confirmed') &&
                      dt != null &&
                      dt.toLocal().isAfter(now);
                },
                orElse: () => {},
              )['id'] as String?;

              return Column(
                children: _todayBookings
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _liveAppointmentCard(
                            b,
                            isNextUp: b['id'] == nextUpId,
                          ),
                        ))
                    .toList(),
              );
            }),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Setup checklist ────────────────────────────────────────────────────────

  Widget _setupChecklist() {
    final servicesOk = (_salon!['isServicesConfigured'] as bool? ?? false);

    // Use the full barbers array when available; fall back to the count field.
    final barbersList = (_salon!['barbers'] as List?) ?? [];
    final barbersOk   = barbersList.isNotEmpty || _asInt(_salon!['barberCount']) > 0;

    // Location is "done" when ANY of the following are true:
    //  • Live GPS coordinates exist (map pin approved)
    //  • A pending GPS/address update is awaiting admin approval
    //  • The salon already has a non-empty city AND state (set at registration)
    final hasPending    = _salon!['hasPendingLocation'] as bool? ?? false;
    final hasLiveCoords = _asDouble(_salon!['latitude'],  double.nan).isFinite &&
                          _asDouble(_salon!['longitude'], double.nan).isFinite;
    final hasAddress    = (_salon!['city']  as String?)?.isNotEmpty == true &&
                          (_salon!['state'] as String?)?.isNotEmpty == true;
    final locationOk    = hasLiveCoords || hasPending || hasAddress;

    // All done — hide the checklist
    if (servicesOk && barbersOk && locationOk) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.checklist_rounded,
                color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Text('Complete your profile to start receiving bookings',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800)),
          ]),
          const SizedBox(height: 12),
          _checkItem(
            done: servicesOk,
            label: 'Set service prices',
            hint: 'Customers need prices before they can book',
            onTap: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfessionalServicesScreen()),
              );
              if (updated == true) _fetchData();
            },
          ),
          const SizedBox(height: 8),
          _checkItem(
            done: barbersOk,
            label: 'Add at least one barber',
            hint: 'Slot availability is based on barber count',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageBarbersScreen()),
            ).then((_) => _fetchData()),
          ),
          const SizedBox(height: 8),
          _checkItem(
            done: locationOk,
            label: 'Set your salon location on the map',
            hint: 'Customers search nearby salons — be discoverable',
            onTap: _openLocationPicker,
          ),
        ]),
      ),
    );
  }

  Widget _checkItem({
    required bool done,
    required String label,
    required String hint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: done ? null : onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: done ? Colors.green.shade500 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: done
                    ? Colors.green.shade500
                    : Colors.blue.shade300),
          ),
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: done
                        ? Colors.grey.shade400
                        : Colors.blue.shade900,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none)),
            if (!done) ...[
              const SizedBox(height: 2),
              Text(hint,
                  style: TextStyle(
                      fontSize: 11, color: Colors.blue.shade600)),
            ],
          ]),
        ),
        if (!done)
          Icon(Icons.arrow_forward_ios,
              size: 12, color: Colors.blue.shade400),
      ]),
    );
  }

  Widget _salonCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.storefront,
                color: Colors.white, size: 35),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _salonName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                if (_salonLocation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_salonLocation,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (_contactNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(_contactNumber,
                          style:
                              const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
            ),
            onPressed: () => setState(() => _currentIndex = 3),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  // ── Open / Closed toggle ───────────────────────────────────────────────────

  Future<void> _toggleSalonOpen(bool isOpen) async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.lightImpact();
    try {
      await ApiService.updateSalonOpenStatus(isOpen);
      if (!mounted) return;
      _fetchData();
      AppSnackbar.successM(
        messenger,
        isOpen ? 'Salon is now Open for bookings' : 'Salon marked as Closed',
      );
    } catch (e) {
      AppSnackbar.errorM(messenger, 'Failed to update salon status.');
    }
  }

  // ── Location picker ────────────────────────────────────────────────────────

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<SavedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    if (result == null || !mounted) return;

    try {
      await ApiService.updateSalonLocation(
        lat:     result.lat,
        lng:     result.lng,
        address: result.name,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        'Location submitted — will go live after admin approval.',
      );
      await _fetchData(); // await so the profile page reflects new state immediately
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Failed to submit location.',
        );
      }
    }
  }

  // ── PROFILE PAGE ───────────────────────────────────────────────────────────

  Widget _profilePage() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final workingDaysList =
        (_salon?['workingDays'] as String?)?.split(',') ?? [];

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding:
          EdgeInsets.symmetric(horizontal: isTablet ? 60 : 18, vertical: 24),
      child: Column(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.green.shade100,
            child: Text(
              _initials,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ),

          const SizedBox(height: 14),

          if (_managerName.isNotEmpty)
            Text(
              _managerName,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),

          const SizedBox(height: 4),

          if (_managerPhone.isNotEmpty)
            Text(
              _managerPhone,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),

          if (_managerEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_managerEmail,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13)),
            ),

          const SizedBox(height: 16),

          // ── Profile completion ───────────────────────────────────────────
          if (_salon != null)
            ProfileCompletionWidget(
              percent: professionalCompletion(_salon!),
              label: 'Profile completion',
            ),

          // ── Services not configured warning ──────────────────────────────
          if (_salon != null &&
              (_salon!['isServicesConfigured'] as bool? ?? false) == false) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfessionalServicesScreen()),
                );
                if (updated == true) _fetchData();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set service prices to start accepting bookings.',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 13, color: Colors.orange.shade600),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Salon info card ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront,
                        color: Colors.green, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _salonName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    _statusBadge(_salon?['status'] as String? ?? ''),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Open / Closed toggle ──────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_salon?['isOpen'] as bool? ?? true)
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_salon?['isOpen'] as bool? ?? true)
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                    child: Text(
                      (_salon?['isOpen'] as bool? ?? true)
                          ? '🟢  Open'
                          : '🔴  Closed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (_salon?['isOpen'] as bool? ?? true)
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Mark as ${(_salon?['isOpen'] as bool? ?? true) ? 'Closed' : 'Open'}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _salon?['isOpen'] as bool? ?? true,
                    onChanged: _toggleSalonOpen,
                    activeThumbColor: Colors.green,
                    inactiveThumbColor: Colors.red.shade300,
                  ),
                ]),

                const SizedBox(height: 6),
                StarRating(
                  rating: _asDouble(_salon?['rating']),
                  reviewCount: _asInt(_salon?['reviewCount']),
                  starSize: 14,
                ),

                const Divider(height: 24),

                _infoRow(Icons.location_on_outlined, 'Address',
                    _salonLocation.isNotEmpty
                        ? _salonLocation
                        : 'Not provided'),

                if ((_salon?['city'] as String?)?.isNotEmpty == true)
                  Row(children: [
                    Expanded(
                      child: _infoRow(Icons.location_city, 'City & State',
                          '${_salon!['city']}, ${_salon!['state']} — ${_salon!['pincode']}'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 14),
                      label: const Text('Update on Map',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _openLocationPicker,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ]),

                // ── Map location ─────────────────────────────────────────────
                _locationRow(),

                if (_contactNumber.isNotEmpty)
                  _infoRow(
                      Icons.phone, 'Contact', _contactNumber),

                if ((_salon?['email'] as String?)?.isNotEmpty == true)
                  _infoRow(Icons.email_outlined, 'Salon Email',
                      _salon!['email'] as String),

                // ── Working hours (editable) ──────────────────────────────
                Row(children: [
                  Expanded(
                    child: _infoRow(
                      Icons.access_time,
                      'Working Hours',
                      (_salon?['openingTime'] as String?)?.isNotEmpty == true
                          ? '${_salon!['openingTime']} – ${_salon!['closingTime']}'
                          : 'Not set',
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    onPressed: _editWorkingHours,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                ]),

                if (workingDaysList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Working Days',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: workingDaysList
                        .map((d) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.green.shade200),
                              ),
                              child: Text(d.trim(),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500)),
                            ))
                        .toList(),
                  ),
                ],

                // ── Services ─────────────────────────────────────────────────
                _buildProfileServices(),

                // ── Amenities ────────────────────────────────────────────────
                _buildProfileAmenities(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Customer Reviews ──────────────────────────────────────────────
          _buildReviewsSection(),

          const SizedBox(height: 32),

          // ── Logout button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _logout,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    ), // SingleChildScrollView
    ); // RefreshIndicator
  }

  // ── SUBSCRIPTIONS PAGE ─────────────────────────────────────────────────────

  Widget _subscriptionsPage() {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 48 : 18, vertical: 24),
      child: _ProSubscriptionCard(
        salonName: _salonName,
        phone: _managerPhone,
        email: _managerEmail,
      ),
    );
  }

  /// Map location row: shows current GPS status + pending approval badge.
  /// Tapping opens MapScreen so the professional can pick/update their location.
  Widget _locationRow() {
    final hasPending  = _salon?['hasPendingLocation'] as bool? ?? false;
    final pendingAddr = _salon?['pendingAddress'] as String?;
    final pendingCity = _salon?['pendingCity']    as String?;
    final pendingState= _salon?['pendingState']   as String?;
    final hasLive     =
        _asDouble(_salon?['latitude'],  double.nan).isFinite &&
        _asDouble(_salon?['longitude'], double.nan).isFinite;

    // Build a human-readable pending label — prefer city/state if available
    final pendingLabel = (pendingCity?.isNotEmpty == true &&
            pendingState?.isNotEmpty == true)
        ? '$pendingCity, $pendingState'
        : (pendingAddr?.isNotEmpty == true ? pendingAddr! : null);

    // Build the approved location label from the live salon data
    final liveCity  = _salon?['city']  as String? ?? '';
    final liveState = _salon?['state'] as String? ?? '';
    final liveLabel = [liveCity, liveState]
        .where((s) => s.isNotEmpty)
        .join(', ');

    if (hasPending) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.hourglass_top_rounded,
                size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location update pending admin approval',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800)),
                  const SizedBox(height: 2),
                  Text('Usually approved within 24 hours.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700)),
                  if (pendingLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(pendingLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ]),
        ),
      );
    }

    // Approved / no pending — show current status + update button
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(
          hasLive ? Icons.location_on : Icons.location_off_outlined,
          size: 16,
          color: hasLive ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasLive
                ? 'Location Added${liveLabel.isNotEmpty ? ' — $liveLabel' : ''}'
                : 'No map location — set it for better visibility',
            style: TextStyle(
                fontSize: 12,
                color: hasLive ? Colors.black87 : Colors.grey),
          ),
        ),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              hasLive ? 'Update' : 'Add',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Profile: Services list ────────────────────────────────────────────────

  Widget _buildProfileServices() {
    final services = (_salon?['services'] as List?) ?? [];
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            const Icon(Icons.content_cut, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Services',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfessionalServicesScreen()),
                );
                if (updated == true) _fetchData();
              },
              child: Text(
                'Edit',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: services.map((s) {
            final svc   = s as Map<String, dynamic>;
            final name  = svc['name'] as String? ?? '';
            final price = (svc['price'] as num?)?.toStringAsFixed(0) ?? '0';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '$name  ₹$price',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Profile: Amenities list ───────────────────────────────────────────────

  Widget _buildProfileAmenities() {
    final amenities = (_salon?['amenities'] as List?) ?? [];
    if (amenities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            const Icon(Icons.star_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Amenities',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenities.map((a) {
            final name = a is String ? a : (a as Map?)?['name']?.toString() ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                name,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  // ── LIVE APPOINTMENT CARD (real data + Accept/Reject/OTP) ────────────────

  Widget _liveAppointmentCard(Map<String, dynamic> b, {bool isNextUp = false}) {
    final status   = b['status'] as String? ?? '';
    final customer = b['customerName'] as String? ?? 'Customer';
    final dt       = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
    final timeStr  = dt != null ? DateFormat('HH:mm').format(dt.toLocal()) : '';
    final services = (b['services'] as List?) ?? [];
    final amount   = _asDouble(b['totalAmount']);
    final id       = b['id'] as String;

    // Compute minutes until appointment (for "Next up" chip)
    final minsUntil = dt != null
        ? dt.toLocal().difference(DateTime.now()).inMinutes
        : -1;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending':     statusColor = Colors.orange.shade600; statusLabel = 'Pending';     break;
      case 'confirmed':   statusColor = Colors.blue.shade600;   statusLabel = 'Confirmed';   break;
      case 'in_progress': statusColor = Colors.green.shade600;  statusLabel = 'In Progress'; break;
      case 'completed':   statusColor = Colors.grey.shade500;   statusLabel = 'Completed';   break;
      case 'rejected':    statusColor = Colors.red.shade400;    statusLabel = 'Rejected';    break;
      case 'cancelled':   statusColor = Colors.red.shade400;    statusLabel = 'Cancelled';   break;
      case 'expired':     statusColor = Colors.brown.shade400;  statusLabel = 'Expired';     break;
      default:            statusColor = Colors.grey;            statusLabel = status;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── "Next up" chip ───────────────────────────────────────────
        if (isNextUp && minsUntil >= 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.access_time, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                minsUntil == 0
                    ? 'Next up — now'
                    : 'Next up in $minsUntil min',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ),
        ],
        // ── Header: customer + status ────────────────────────────────
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.person_outline, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 11, color: statusColor,
                    fontWeight: FontWeight.w600)),
          ),
        ]),

        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 8),

        // ── Time + services ──────────────────────────────────────────
        Row(children: [
          Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(timeStr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              services.map((s) {
                final svc = s as Map<String, dynamic>;
                return svc['serviceName'] ?? svc['name'] ?? '';
              }).join(' · '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                  color: Colors.green)),
        ]),

        // ── Action buttons ───────────────────────────────────────────
        if (status == 'pending') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Accept'),
                onPressed: () => _acceptBooking(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                onPressed: () => _rejectBooking(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade500,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ] else if (status == 'confirmed') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.vpn_key_outlined, size: 16),
              label: const Text('Enter Customer OTP to Start'),
              onPressed: () => _enterOtpDialog(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ] else if (status == 'in_progress') ...[
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text('In Progress',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark Complete'),
                onPressed: () => _completeBooking(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Accept booking ────────────────────────────────────────────────────────

  Future<void> _acceptBooking(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.acceptBooking(bookingId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'Booking accepted. OTP sent to customer.');
      _fetchData();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to accept booking.');
    }
  }

  // ── Reject booking ────────────────────────────────────────────────────────

  Future<void> _rejectBooking(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject Booking', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to reject this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.rejectBooking(bookingId);
      if (!mounted) return;
      AppSnackbar.infoM(messenger, 'Booking rejected.');
      _fetchData();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to reject booking.');
    }
  }

  // ── Customer Reviews section (profile tab) ───────────────────────────────

  Widget _buildReviewsSection() {
    final primary      = Theme.of(context).colorScheme.primary;
    final avgRating    = _asDouble(_salon?['rating']);
    final reviewCount  = _asInt(_salon?['reviewCount']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text('Customer Reviews',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (reviewCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(avgRating.toStringAsFixed(1),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.amber.shade800)),
                  const SizedBox(width: 4),
                  Text('($reviewCount)',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade700)),
                ]),
              ),
          ]),

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 12),

          // ── Empty state ───────────────────────────────────────────────
          if (_myReviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.rate_review_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('No reviews yet',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('Customer reviews will appear here after visits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
                ]),
              ),
            )
          // ── Review list ───────────────────────────────────────────────
          else ...[
            ..._myReviews.take(5).map((r) {
              final rating   = _asInt(r['rating']);
              final comment  = r['comment']      as String? ?? '';
              final reviewer = r['reviewerName'] as String? ?? 'Customer';
              final dt = DateTime.tryParse(
                  r['createdAt'] as String? ?? '');
              final dateStr = dt != null
                  ? DateFormat('d MMM yyyy').format(dt.toLocal())
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Stars
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: Colors.amber.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(reviewer,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ]),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(comment,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              );
            }),

            // "Show more" button when there are more than 5
            if (_myReviews.length > 5) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  icon: Icon(Icons.expand_more,
                      size: 18, color: primary),
                  label: Text(
                    'View all ${_myReviews.length} reviews',
                    style: TextStyle(
                        color: primary, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => _showAllReviews(),
                  style: TextButton.styleFrom(
                      foregroundColor: primary),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Text('All Reviews',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_myReviews.length}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _myReviews.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r        = _myReviews[i];
                final rating   = _asInt(r['rating']);
                final comment  = r['comment'] as String? ?? '';
                final reviewer =
                    r['reviewerName'] as String? ?? 'Customer';
                final dt = DateTime.tryParse(
                    r['createdAt'] as String? ?? '');
                final dateStr = dt != null
                    ? DateFormat('d MMM yyyy').format(dt.toLocal())
                    : '';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (j) => Icon(
                              j < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: Colors.amber.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(reviewer,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                      ]),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(comment,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.5)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Edit working hours ────────────────────────────────────────────────────

  Future<void> _editWorkingHours() async {
    final openCtrl = TextEditingController(
        text: _salon?['openingTime'] as String? ?? '09:00');
    final closeCtrl = TextEditingController(
        text: _salon?['closingTime'] as String? ?? '21:00');
    final currentDays =
        ((_salon?['workingDays'] as String?) ?? '').split(',')
        .map((d) => d.trim()).toSet();
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = Set<String>.from(currentDays);
    bool saving = false;
    final primary = Theme.of(context).colorScheme.primary;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Working Hours',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: openCtrl,
                  decoration: InputDecoration(
                    labelText: 'Opening (HH:MM)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: closeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Closing (HH:MM)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Working Days',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: allDays.map((d) {
                final on = selected.contains(d);
                return GestureDetector(
                  onTap: () => setInner(() {
                    on ? selected.remove(d) : selected.add(d);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: on ? primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 12,
                            color: on ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving ? null : () async {
                setInner(() => saving = true);
                final nav = Navigator.of(ctx);
                try {
                  await ApiService.updateWorkingHours(
                    openingTime: openCtrl.text.trim(),
                    closingTime:  closeCtrl.text.trim(),
                    workingDays:  selected.join(','),
                  );
                  nav.pop();
                  if (!mounted) return;
                  AppSnackbar.successM(
                      messenger, 'Working hours updated.');
                  _fetchData();
                } on ApiException catch (e) {
                  setInner(() => saving = false);
                  AppSnackbar.errorM(messenger, e.message);
                } catch (_) {
                  setInner(() => saving = false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    openCtrl.dispose();
    closeCtrl.dispose();
  }

  // ── Complete booking ──────────────────────────────────────────────────────

  Future<void> _completeBooking(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.completeBooking(bookingId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'Booking marked as completed.');
      _fetchData();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to complete booking.');
    }
  }

  // ── OTP entry dialog ──────────────────────────────────────────────────────

  Future<void> _enterOtpDialog(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final verified  = await showDialog<bool>(
      context: context,
      builder: (_) => _OtpVerifyDialog(bookingId: bookingId),
    );
    if (verified == true && mounted) {
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'OTP verified! Appointment started.');
      _fetchData();
    }
  }

  // ── OVERVIEW / ACTION CARDS ────────────────────────────────────────────────

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.green, size: 30),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget actionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green, size: 30),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Professional Appointments Tab ───────────────────────────────────────────

class _ProAppointmentsTab extends StatefulWidget {
  const _ProAppointmentsTab();

  @override
  State<_ProAppointmentsTab> createState() => _ProAppointmentsTabState();
}

// Filter options: 0=Today, 1=Week, 2=Month, 3=All
enum _ApptFilter { today, week, month, all }

class _ProAppointmentsTabState extends State<_ProAppointmentsTab> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  _ApptFilter _filter = _ApptFilter.today;
  String? _statusFilter;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getSalonBookings();
    if (mounted) {
      final list = (data['bookings'] as List? ?? []);
      setState(() {
        _bookings = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'pending':     return 'Pending';
      case 'confirmed':   return 'Confirmed';
      case 'in_progress': return 'In Progress';
      case 'completed':   return 'Completed';
      case 'rejected':    return 'Rejected';
      case 'cancelled':   return 'Cancelled';
      default: return s ?? '';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'pending':     return Colors.orange.shade600;
      case 'confirmed':   return Colors.blue.shade600;
      case 'in_progress': return Colors.green.shade600;
      case 'completed':   return Colors.blueGrey.shade500;
      case 'rejected':    return Colors.red.shade400;
      case 'cancelled':   return Colors.red.shade400;
      default: return Colors.grey;
    }
  }

  // ── Action handlers ──────────────────────────────────────────────────────

  Future<void> _accept(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.acceptBooking(bookingId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'Booking accepted. OTP sent to customer.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to accept booking.');
    }
  }

  Future<void> _reject(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject Booking',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to reject this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.rejectBooking(bookingId);
      if (!mounted) return;
      AppSnackbar.infoM(messenger, 'Booking rejected.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to reject booking.');
    }
  }

  Future<void> _enterOtp(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final verified  = await showDialog<bool>(
      context: context,
      builder: (_) => _OtpVerifyDialog(bookingId: bookingId),
    );
    if (verified == true && mounted) {
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'OTP verified! Appointment started.');
      _load();
    }
  }


  Future<void> _complete(String bookingId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.completeBooking(bookingId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'Booking marked as completed.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to complete booking.');
    }
  }

  Future<void> _completeWalkIn(String walkInId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.updateWalkIn(walkInId, {'status': 'completed'});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.successM(messenger, 'Offline appointment marked as completed.');
      _load();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.errorM(messenger, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.errorM(messenger, 'Failed to complete appointment.');
    }
  }

  List<Map<String, dynamic>> get _visibleBookings {
    final now  = DateTime.now();
    final tod  = DateTime(now.year, now.month, now.day);
    final wk   = now.subtract(const Duration(days: 7));
    final mth  = DateTime(now.year, now.month, 1);
    return _bookings.where((b) {
      final dt = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
      if (dt == null) return false;
      final local = dt.toLocal();

      final inRange = switch (_filter) {
        _ApptFilter.today => local.year == tod.year &&
            local.month == tod.month && local.day == tod.day,
        _ApptFilter.week  => local.isAfter(wk),
        _ApptFilter.month => local.isAfter(mth),
        _ApptFilter.all   => true,
      };
      if (!inRange) return false;

      if (_statusFilter != null && b['status'] != _statusFilter) return false;

      if (_searchQuery.isNotEmpty) {
        final name = (b['customerName'] as String? ?? '').toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  void _showOfflineBookingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflineBookingSheet(
        onCreated: () {
          _load();
          final messenger = ScaffoldMessenger.of(context);
          AppSnackbar.successM(
              messenger, 'Offline booking created — slot is now blocked.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const AppLoadingIndicator(message: 'Loading appointments…');
    }

    final visible = _visibleBookings;

    return Column(
      children: [
        // ── Header: title + offline booking button ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Appointments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _showOfflineBookingSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Offline Booking',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  backgroundColor: primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // ── Time-range filter chips ────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              _filterChip('Today',    _ApptFilter.today,  primary),
              const SizedBox(width: 8),
              _filterChip('Week',     _ApptFilter.week,   primary),
              const SizedBox(width: 8),
              _filterChip('Month',    _ApptFilter.month,  primary),
              const SizedBox(width: 8),
              _filterChip('All Time', _ApptFilter.all,    primary),
            ],
          ),
        ),

        // ── Customer name search ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by customer name…',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: primary.withValues(alpha: 0.5))),
            ),
          ),
        ),

        // ── Status filter chips ────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              null,
              'pending',
              'confirmed',
              'in_progress',
              'completed',
              'rejected',
            ].map((s) {
              final label = s == null
                  ? 'All'
                  : s[0].toUpperCase() +
                      s.substring(1).replaceAll('_', ' ');
              final active = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? primary
                              : Colors.grey.shade300),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: primary.withValues(alpha: 0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── List ───────────────────────────────────────────────────────
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _bookings.isEmpty
                            ? 'No appointments yet'
                            : 'No appointments in this period',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (_bookings.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Try a different time range above.',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => _buildCard(visible[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _ApptFilter value, Color primary) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? primary : Colors.grey.shade300),
          boxShadow: active
              ? [BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey.shade700,
            )),
      ),
    );
  }


  Widget _buildCard(Map<String, dynamic> b) {
    final status      = b['status'] as String?;
    final statusColor = _statusColor(status);
    final id          = b['id'] as String;
    final isWalkIn    = b['type'] == 'walk_in';
    final customer    = b['customerName'] as String? ?? 'Customer';
    final dt          = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
    final timeStr     = dt != null
        ? DateFormat('HH:mm  ·  d MMM').format(dt.toLocal())
        : '';
    final amount   = _asDouble(b['totalAmount']);
    final duration = _asInt(b['totalDuration']);
    final services = (b['services'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: avatar + name/phone + status badge ───────────────────
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              if (isWalkIn)
                Row(children: [
                  Icon(Icons.person_add_alt_1_outlined,
                      size: 11, color: Colors.deepPurple.shade400),
                  const SizedBox(width: 3),
                  Text('Offline booking',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.deepPurple.shade400,
                          fontWeight: FontWeight.w500)),
                ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statusLabel(status),
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600)),
          ),
        ]),

        const SizedBox(height: 10),
        Divider(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 8),

        // ── Time + duration ──────────────────────────────────────────────
        Row(children: [
          Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(timeStr,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('~$duration min',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500)),
        ]),

        // ── Services preview ─────────────────────────────────────────────
        if (services.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            services.map((s) {
              final svc = s as Map<String, dynamic>;
              return svc['serviceName'] ?? svc['name'] ?? '';
            }).join(' · '),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 6),
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),

        // ── Action buttons based on status ───────────────────────────────
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check, size: 15),
                label: const Text('Accept'),
                onPressed: () => _accept(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Reject'),
                onPressed: () => _reject(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade500,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ] else if (status == 'confirmed') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isWalkIn
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Complete'),
                    onPressed: () => _completeWalkIn(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.vpn_key_outlined, size: 16),
                    label: const Text('Enter Customer OTP to Start'),
                    onPressed: () => _enterOtp(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ),
        ] else if (status == 'in_progress') ...[
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined,
                    size: 14, color: Colors.green.shade700),
                const SizedBox(width: 5),
                Text('In Progress',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(
                    Icons.check_circle_outline, size: 16),
                label: const Text('Mark Complete'),
                onPressed: () => isWalkIn ? _completeWalkIn(id) : _complete(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─── Earnings Tab ─────────────────────────────────────────────────────────────

class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  Map<String, dynamic> _stats   = {};
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getEarnings();
    if (mounted) {
      setState(() {
        _stats    = (data['stats']    as Map<String, dynamic>?) ?? {};
        _bookings = ((data['bookings'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        _loading  = false;
      });
    }
  }

  double _rev(String key) =>
      _asDouble((_stats[key] as Map?)?['revenue']);

  int _cnt(String key) =>
      _asInt((_stats[key] as Map?)?['count']);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingIndicator(message: 'Loading earnings…');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── All-time headline ────────────────────────────────────────
          _headlineCard(),
          const SizedBox(height: 16),

          // ── Period summary cards ─────────────────────────────────────
          _periodRow(),
          const SizedBox(height: 24),

          // ── Recent completed bookings ────────────────────────────────
          Row(children: [
            const Text('Completed Bookings',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_bookings.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),

          if (_bookings.isEmpty)
            _emptyBookings()
          else
            ..._buildGroupedBookings(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── All-time headline ───────────────────────────────────────────────────────

  Widget _headlineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.currency_rupee,
              color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          const Text('Total Revenue',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        Text(
          '₹${_rev('allTime').toStringAsFixed(0)}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${_cnt('allTime')} completed appointment${_cnt('allTime') == 1 ? '' : 's'}',
          style: const TextStyle(
              color: Colors.white70, fontSize: 12),
        ),
      ]),
    );
  }

  // ── Period cards row ────────────────────────────────────────────────────────

  Widget _periodRow() {
    return Row(children: [
      _periodCard('Today',      _rev('today'),  _cnt('today'),  Colors.blue.shade600),
      const SizedBox(width: 10),
      _periodCard('This Week',  _rev('week'),   _cnt('week'),   Colors.purple.shade500),
      const SizedBox(width: 10),
      _periodCard('This Month', _rev('month'),  _cnt('month'),  Colors.orange.shade600),
    ]);
  }

  Widget _periodCard(
      String label, double revenue, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('₹${revenue.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text('$count job${count == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _emptyBookings() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No completed appointments yet',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text(
            'Completed bookings and their revenue\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade400),
          ),
        ]),
      ),
    );
  }

  // ── Date-grouped bookings ───────────────────────────────────────────────────

  List<Widget> _buildGroupedBookings() {
    // Group bookings by local calendar date
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final b in _bookings) {
      final dt = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
      final key = dt != null
          ? DateFormat('yyyy-MM-dd').format(dt.toLocal())
          : 'unknown';
      groups.putIfAbsent(key, () => []).add(b);
    }

    // Sort keys descending (most recent first)
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    for (final key in sortedKeys) {
      final dayBookings = groups[key]!;
      final dayRevenue  = dayBookings.fold<double>(
          0, (s, b) => s + _asDouble(b['totalAmount']));

      // Friendly date label
      String label;
      if (key == today) {
        label = 'Today';
      } else if (key == yesterday) {
        label = 'Yesterday';
      } else if (key == 'unknown') {
        label = 'Unknown Date';
      } else {
        final dt = DateTime.tryParse(key);
        label = dt != null ? DateFormat('EEE, d MMM yyyy').format(dt) : key;
      }

      // Section header
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const Spacer(),
          Text('₹${dayRevenue.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700)),
        ]),
      ));

      for (final b in dayBookings) {
        widgets.add(_buildBookingRow(b));
      }
    }
    return widgets;
  }

  // ── Single booking row ──────────────────────────────────────────────────────

  Widget _buildBookingRow(Map<String, dynamic> b) {
    final customer = b['customerName']  as String? ?? 'Customer';
    final amount   = _asDouble(b['totalAmount']);
    final duration = _asInt(b['totalDuration']);
    final services = (b['services']     as List?) ?? [];
    final dt       = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
    final dateStr  = dt != null
        ? DateFormat('d MMM  ·  HH:mm').format(dt.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_outline,
              color: Colors.green.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                services.isEmpty
                    ? '$duration min'
                    : services
                        .map((s) {
                          final svc = s as Map<String, dynamic>;
                          return svc['serviceName'] ?? svc['name'] ?? '';
                        })
                        .join(' · '),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(dateStr,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        ),
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),
      ]),
    );
  }
}

// ── Professional plan data ────────────────────────────────────────────────────

class _ProFeature {
  final String text;
  final IconData icon;
  const _ProFeature(this.text, this.icon);
}

class _ProPlan {
  final String id;
  final String title;
  final int priceRs;
  final IconData icon;
  final List<_ProFeature> features;
  final bool highlighted;
  final Color color;
  const _ProPlan({
    required this.id,
    required this.title,
    required this.priceRs,
    required this.icon,
    required this.features,
    required this.color,
    this.highlighted = false,
  });
}

const _proPlans = [
  _ProPlan(
    id: 'free',
    title: 'Free',
    priceRs: 0,
    color: Color(0xFF9E9E9E),
    icon: Icons.storefront_outlined,
    features: [
      _ProFeature('1 barber listed', Icons.person_outline),
      _ProFeature('Up to 50 bookings/month', Icons.event_available_outlined),
      _ProFeature('Standard listing visibility', Icons.visibility_outlined),
      _ProFeature('Basic booking management', Icons.calendar_today_outlined),
    ],
  ),
  _ProPlan(
    id: 'professional_starter',
    title: 'Starter',
    priceRs: 299,
    color: Color(0xFF2196F3),
    icon: Icons.star_outline,
    features: [
      _ProFeature('Up to 3 barbers', Icons.people_outline),
      _ProFeature('Unlimited bookings', Icons.all_inclusive),
      _ProFeature('Basic analytics & reports', Icons.bar_chart_outlined),
      _ProFeature('Booking reminders & alerts', Icons.notifications_outlined),
      _ProFeature('Email support (24–48 hr)', Icons.mail_outline),
    ],
  ),
  _ProPlan(
    id: 'professional_growth',
    title: 'Growth',
    priceRs: 599,
    color: Color(0xFF9C27B0),
    icon: Icons.trending_up_outlined,
    features: [
      _ProFeature('Up to 10 barbers', Icons.people_outline),
      _ProFeature('Priority listing placement', Icons.flash_on_outlined),
      _ProFeature('Advanced analytics & insights', Icons.analytics_outlined),
      _ProFeature('Priority customer support', Icons.headset_mic_outlined),
      _ProFeature('Custom booking reminders', Icons.notifications_active_outlined),
    ],
  ),
  _ProPlan(
    id: 'professional_premium',
    title: 'Premium',
    priceRs: 999,
    color: Color(0xFFFF8F00),
    highlighted: true,
    icon: Icons.workspace_premium_outlined,
    features: [
      _ProFeature('Everything in Growth', Icons.check_circle_outline),
      _ProFeature('Unlimited barbers', Icons.people_outline),
      _ProFeature('Featured salon badge', Icons.verified_outlined),
      _ProFeature('Full analytics + revenue reports', Icons.assessment_outlined),
      _ProFeature('Dedicated priority support', Icons.support_agent_outlined),
      _ProFeature('Early access to new features', Icons.new_releases_outlined),
    ],
  ),
];

// ── Professional Subscription Card ───────────────────────────────────────────

class _ProSubscriptionCard extends StatefulWidget {
  final String salonName;
  final String phone;
  final String email;
  const _ProSubscriptionCard({
    required this.salonName,
    this.phone = '',
    this.email = '',
  });

  @override
  State<_ProSubscriptionCard> createState() => _ProSubscriptionCardState();
}

class _ProSubscriptionCardState extends State<_ProSubscriptionCard> {
  Map<String, dynamic>? _sub;
  bool _loading    = true;
  bool _cancelling = false;
  int  _monthlyBookingCount = 0;

  static const _kFreeMonthlyLimit = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getProfessionalSubscription(),
      ApiService.getProfessionalMonthlyBookingCount(),
    ]);
    if (mounted) {
      setState(() {
        _sub = results[0] as Map<String, dynamic>?;
        _monthlyBookingCount = results[1] as int;
        _loading = false;
      });
    }
  }

  String _planLabel(String? plan) {
    switch (plan) {
      case 'professional_starter': return 'Starter';
      case 'professional_growth':  return 'Growth';
      case 'professional_premium': return 'Premium';
      default: return 'Free';
    }
  }

  bool get _isOnPaidPlan {
    final plan = _sub?['plan'] as String? ?? 'free';
    return plan.startsWith('professional_');
  }

  String get _expiryLabel {
    final exp = _sub?['expiresAt'] as String?;
    if (exp == null) return '';
    final dt = DateTime.tryParse(exp);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    if (diff <= 0) return 'Expires today';
    if (diff == 1) return 'Expires tomorrow';
    return 'Expires ${DateFormat('d MMM yyyy').format(dt)}';
  }

  Future<void> _subscribe(_ProPlan plan) async {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: isTablet
          ? const BoxConstraints(maxWidth: 540)
          : const BoxConstraints(),
      builder: (_) => _ProPaymentSheet(
        planKey: plan.id,
        planLabel: plan.title,
        phone: widget.phone,
        email: widget.email,
      ),
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) AppSnackbar.success(context, '${plan.title} plan activated!');
    }
  }

  Future<void> _cancelPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Subscription',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Your ${_planLabel(_sub?['plan'] as String?)} plan will revert to Free immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ApiService.cancelSubscription();
      if (mounted) {
        AppSnackbar.info(context, 'Subscription cancelled. You are now on the Free plan.');
        await _load();
        if (mounted) setState(() => _cancelling = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.error(context, 'Failed to cancel. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPlan = _sub?['plan'] as String? ?? 'free';
    const primary = Color(0xFFFF8F00);

    return Column(children: [
      // ── Header ───────────────────────────────────────────────────────────
      const Text('Choose Your Plan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      const Text(
        'Grow your salon business with the right tools.',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),

      // ── Active plan badge ─────────────────────────────────────────────────
      if (_isOnPaidPlan) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.verified_outlined, color: primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active: ${_planLabel(currentPlan)} Plan',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primary,
                        fontSize: 13),
                  ),
                  if (_expiryLabel.isNotEmpty)
                    Text(_expiryLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (_cancelling)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              GestureDetector(
                onTap: _cancelPlan,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ],

      // ── Monthly booking usage (free plan only) ───────────────────────────
      if (!_isOnPaidPlan) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Monthly Bookings (Free Plan)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(
                  '$_monthlyBookingCount / $_kFreeMonthlyLimit',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _monthlyBookingCount >= _kFreeMonthlyLimit
                          ? Colors.red.shade600
                          : Colors.black87),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_monthlyBookingCount / _kFreeMonthlyLimit)
                      .clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _monthlyBookingCount >= _kFreeMonthlyLimit
                        ? Colors.red.shade400
                        : const Color(0xFFFF8F00),
                  ),
                ),
              ),
              if (_monthlyBookingCount >= _kFreeMonthlyLimit) ...[
                const SizedBox(height: 6),
                Text(
                  'Booking limit reached. Upgrade to accept more this month.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.red.shade600),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  '${_kFreeMonthlyLimit - _monthlyBookingCount} bookings remaining this month.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],

      const SizedBox(height: 20),

      // ── Plan cards ────────────────────────────────────────────────────────
      ..._proPlans.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ProPlanCard(
              plan: p,
              isCurrent: p.id == currentPlan,
              onSubscribe: () => _subscribe(p),
            ),
          )),

      const SizedBox(height: 8),
    ]);
  }
}

// ── Professional Plan Card ────────────────────────────────────────────────────

class _ProPlanCard extends StatelessWidget {
  final _ProPlan plan;
  final bool isCurrent;
  final VoidCallback onSubscribe;
  const _ProPlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final hl = plan.highlighted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hl ? plan.color : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hl
              ? plan.color
              : isCurrent
                  ? plan.color.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: hl
            ? [
                BoxShadow(
                    color: plan.color.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title row ──────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(plan.icon,
                size: 22,
                color: hl ? Colors.white : plan.color),
            const SizedBox(width: 8),
            Text(plan.title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: hl ? Colors.white : Colors.black)),
          ]),
          if (hl)
            _badge('POPULAR', Colors.white.withValues(alpha: 0.25), Colors.white)
          else if (isCurrent)
            _badge('CURRENT', plan.color.withValues(alpha: 0.12), plan.color),
        ]),
        const SizedBox(height: 8),

        // ── Price ──────────────────────────────────────────────────────
        RichText(
          text: TextSpan(
            style: TextStyle(color: hl ? Colors.white : Colors.black),
            children: [
              TextSpan(
                  text: plan.priceRs == 0 ? '₹0' : '₹${plan.priceRs}',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              TextSpan(
                  text: plan.priceRs == 0 ? ' forever' : ' / month',
                  style: TextStyle(
                      fontSize: 14,
                      color: hl ? Colors.white70 : Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(
            color: hl
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.shade200),
        const SizedBox(height: 12),

        // ── Features ───────────────────────────────────────────────────
        ...plan.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hl
                        ? Colors.white.withValues(alpha: 0.15)
                        : plan.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f.icon,
                      size: 15,
                      color: hl ? Colors.white : plan.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.text,
                      style: TextStyle(
                          fontSize: 13,
                          color: hl ? Colors.white : Colors.black87)),
                ),
              ]),
            )),
        const SizedBox(height: 14),

        // ── CTA button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hl
                  ? Colors.white
                  : isCurrent
                      ? Colors.grey.shade100
                      : plan.color,
              foregroundColor: hl
                  ? plan.color
                  : isCurrent
                      ? Colors.grey
                      : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (isCurrent || plan.priceRs == 0) ? null : onSubscribe,
            child: Text(
              isCurrent
                  ? 'Current Plan'
                  : plan.priceRs == 0
                      ? 'Free'
                      : 'Get ${plan.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );
}

// ── Professional plan payment sheet ──────────────────────────────────────────

class _ProPaymentSheet extends StatefulWidget {
  final String planKey;
  final String planLabel;
  final String phone;
  final String email;
  const _ProPaymentSheet({
    required this.planKey,
    required this.planLabel,
    this.phone = '',
    this.email = '',
  });

  @override
  State<_ProPaymentSheet> createState() => _ProPaymentSheetState();
}

enum _PayState { loading, ready, success, error }

class _ProPaymentSheetState extends State<_ProPaymentSheet> {
  late final Razorpay _razorpay;
  _PayState _state   = _PayState.loading;
  String _errorMsg   = '';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    _openCheckout();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _openCheckout() async {
    setState(() { _state = _PayState.loading; _errorMsg = ''; });
    try {
      final order = await ApiService.createSubscriptionOrder(widget.planKey);
      if (!mounted) return;
      _razorpay.open({
        'key':         order['keyId'],
        'amount':      order['amount'],
        'currency':    order['currency'] ?? 'INR',
        'order_id':    order['orderId'],
        'name':        'Baari Professional',
        'description': '${widget.planLabel} Plan — salon subscription',
        'prefill':     {'contact': widget.phone, 'email': widget.email},
        'theme':       {'color': '#2D9248'},
      });
      if (mounted) setState(() => _state = _PayState.ready);
    } on ApiException catch (e) {
      if (mounted) setState(() { _state = _PayState.error; _errorMsg = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _state    = _PayState.error;
          _errorMsg = 'Could not start payment. Please try again.';
        });
      }
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    setState(() => _state = _PayState.loading);
    try {
      await ApiService.createSubscription(
        widget.planKey,
        paymentId: r.paymentId,
        orderId:   r.orderId,
        signature: r.signature,
      );
      if (!mounted) return;
      setState(() => _state = _PayState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() { _state = _PayState.error; _errorMsg = e.message; });
    }
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    // Code 0 = user dismissed the Razorpay screen ("Yes, exit") — close quietly.
    if (r.code == 0) {
      Navigator.pop(context, false);
      return;
    }
    final msg = r.message ?? '';
    setState(() {
      _state    = _PayState.error;
      _errorMsg = (msg.isEmpty || msg == 'undefined')
          ? 'Payment was not completed. Please try again.'
          : msg;
    });
  }

  void _onWallet(ExternalWalletResponse r) {
    if (mounted) {
      setState(() {
        _state    = _PayState.error;
        _errorMsg = 'External wallet is not supported. Use card or UPI.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final hPad = isTablet ? 48.0 : 24.0;
    final primary = Colors.green.shade700;
    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.65),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        if (_state == _PayState.loading) ...[
          const CircularProgressIndicator(color: Color(0xFF2D9248)),
          const SizedBox(height: 16),
          const Text('Opening secure payment…',
              style: TextStyle(color: Colors.grey)),
        ] else if (_state == _PayState.ready) ...[
          Icon(Icons.lock_outline, color: primary, size: 36),
          const SizedBox(height: 12),
          Text('${widget.planLabel} Plan',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Razorpay checkout opened above.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ] else if (_state == _PayState.success) ...[
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text('${widget.planLabel} Plan Activated!',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
        ] else ...[
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 36),
          const SizedBox(height: 12),
          const Text('Payment Failed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 380 : double.infinity),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Shared OTP entry dialog ───────────────────────────────────────────────────
//
// Fixes two bugs in the old AlertDialog approach:
//  1. Overflow on tablets — uses Dialog + Padding(viewInsets) + SingleChildScrollView
//  2. Broken auto-advance — uses explicit FocusNodes instead of FocusScope.nextFocus(),
//     which was getting intercepted by the AlertDialog's own FocusTrap

class _OtpVerifyDialog extends StatefulWidget {
  final String bookingId;
  const _OtpVerifyDialog({required this.bookingId});

  @override
  State<_OtpVerifyDialog> createState() => _OtpVerifyDialogState();
}

class _OtpVerifyDialogState extends State<_OtpVerifyDialog> {
  final _nodes = List.generate(4, (_) => FocusNode());
  final _ctrls = List.generate(4, (_) => TextEditingController());
  bool _loading = false;

  @override
  void dispose() {
    for (final f in _nodes) { f.dispose(); }
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < 4) {
      AppSnackbar.warning(context, 'Please enter all 4 digits.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.verifyBookingOtp(widget.bookingId, otp);
      if (!mounted) return;
      Navigator.of(context).pop(true); // signal success to caller
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.error(context, 'Failed to verify OTP. Please try again.');
      }
    }
  }

  Widget _otpBox(int i) {
    return Container(
      width: 58, height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Colors.blue.shade600, width: 2),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 3) {
            _nodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _nodes[i - 1].requestFocus();
          }
          // Auto-submit when last box filled
          if (i == 3 && v.isNotEmpty && _otp.length == 4 && !_loading) {
            _verify();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Colors.blue.shade600;

    // Dialog already incorporates MediaQuery.viewInsets into its own insetPadding,
    // so the dialog automatically rises above the keyboard — no inner Padding needed.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              // Drag handle cosmetic
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Enter Customer OTP',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Ask the customer for their 4-digit booking OTP.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // ── 4-box OTP row ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, _otpBox),
              ),

              const SizedBox(height: 28),

              // ── Buttons ──────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor:
                          Colors.blue.shade200,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : const Text('Verify & Start',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
    );
  }
}

// ── Offline / Walk-in booking sheet ──────────────────────────────────────────

class _OfflineBookingSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _OfflineBookingSheet({required this.onCreated});

  @override
  State<_OfflineBookingSheet> createState() => _OfflineBookingSheetState();
}

class _OfflineBookingSheetState extends State<_OfflineBookingSheet> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime  _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<dynamic> _services = [];
  final Map<String, Map<String, dynamic>> _selectedServices = {};
  bool _loadingServices = false;
  bool _submitting = false;
  String? _salonContactNumber;

  // Phone auto-fill state
  Timer? _phoneLookupTimer;
  bool _lookingUpPhone = false;
  bool _nameAutoFilled = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
    // Default to next round-hour so the slot is always in the future
    final now = DateTime.now();
    _selectedTime = TimeOfDay(
        hour: (now.minute > 5 ? now.hour + 1 : now.hour).clamp(0, 23),
        minute: 0);
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneLookupTimer?.cancel();
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      if (_nameAutoFilled) {
        setState(() { _nameAutoFilled = false; });
      }
      _phoneLookupTimer?.cancel();
      return;
    }
    _phoneLookupTimer?.cancel();
    _phoneLookupTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _lookingUpPhone = true);
      try {
        final result = await ApiService.lookupUserByPhone(digits);
        if (!mounted) return;
        if (result != null) {
          final name = result['name'] as String? ?? '';
          if (name.isNotEmpty) {
            _nameCtrl.text = name;
            setState(() { _nameAutoFilled = true; _lookingUpPhone = false; });
            return;
          }
        }
        setState(() { _nameAutoFilled = false; _lookingUpPhone = false; });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() { _nameAutoFilled = false; _lookingUpPhone = false; });
        // Show the server's reason (professional account / own salon phone)
        AppSnackbar.error(context, e.message);
      } catch (_) {
        if (mounted) setState(() { _nameAutoFilled = false; _lookingUpPhone = false; });
      }
    });
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final config = await ApiService.getMySalonConfig();
      final raw = config['services'] as List? ?? [];
      setState(() {
        _services = raw;
        _salonContactNumber = config['contactNumber'] as String?;
        _loadingServices = false;
      });
    } catch (_) {
      setState(() => _loadingServices = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  void _toggleService(Map<String, dynamic> svc) {
    final id = svc['id'] as String? ?? svc['serviceId'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() {
      if (_selectedServices.containsKey(id)) {
        _selectedServices.remove(id);
      } else {
        _selectedServices[id] = svc;
      }
    });
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (phone.isEmpty) {
      AppSnackbar.error(context, 'Phone number is required');
      return;
    }
    if (name.isEmpty) {
      AppSnackbar.error(context, 'Customer name is required');
      return;
    }
    if (_selectedServices.isEmpty) {
      AppSnackbar.error(context, 'Please select at least one service');
      return;
    }
    if (_salonContactNumber != null &&
        phone.replaceAll(RegExp(r'\D'), '') ==
            _salonContactNumber!.replaceAll(RegExp(r'\D'), '')) {
      AppSnackbar.error(
          context, "You can't create a booking under your own salon's phone number");
      return;
    }
    setState(() => _submitting = true);
    try {
      final scheduled = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );
      final services = _selectedServices.values.map((s) => {
        'serviceId': s['id'] ?? s['serviceId'],
        'serviceName': s['serviceName'] as String? ?? s['name'] as String? ?? '',
        'price': (s['price'] as num? ?? 0).toDouble(),
        'duration': (s['duration'] as num? ?? 30).toInt(),
      }).toList();

      await ApiService.addWalkIn({
        'customerName': name,
        'customerPhone': phone,
        'services': services,
        'scheduledAt': scheduled.toIso8601String(),
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not create booking. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Icon(Icons.person_add_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('New Offline Booking',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Expanded(
            child: _loadingServices
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This slot will be instantly blocked in the app. '
                                'App users will not be able to book it.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade800),
                              ),
                            ),
                          ]),
                        ),

                        _label('Phone Number *'),
                        _fieldPhone(primary),
                        const SizedBox(height: 16),

                        _labelWithBadge('Customer Name *', _nameAutoFilled, _lookingUpPhone),
                        _field(_nameCtrl, 'e.g. Rahul Sharma',
                            TextInputType.name, primary),
                        const SizedBox(height: 16),

                        _label('Date & Time *'),
                        Row(children: [
                          Expanded(
                            child: _pickerTile(
                              icon: Icons.calendar_today_outlined,
                              text: DateFormat('d MMM yyyy')
                                  .format(_selectedDate),
                              onTap: _pickDate,
                              primary: primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _pickerTile(
                              icon: Icons.access_time_outlined,
                              text: _selectedTime.format(context),
                              onTap: _pickTime,
                              primary: primary,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        if (_services.isNotEmpty) ...[
                          _label('Services *'),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _services.map((s) {
                              final svc = s as Map<String, dynamic>;
                              final id = svc['id'] as String? ??
                                  svc['serviceId'] as String? ?? '';
                              final name = svc['serviceName'] as String? ??
                                  svc['name'] as String? ?? '';
                              final price =
                                  (svc['price'] as num?)?.toInt() ?? 0;
                              final sel = _selectedServices.containsKey(id);
                              return GestureDetector(
                                onTap: () => _toggleService(svc),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? primary
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? primary
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '$name · ₹$price',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: sel
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _label('Notes (optional)'),
                        _field(
                          _notesCtrl,
                          'e.g. Regular customer, prefers fade',
                          TextInputType.text,
                          primary,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text(
                                    'Block Slot & Save Booking',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _labelWithBadge(String text, bool autoFilled, bool loading) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (loading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: primary),
            ),
          ] else if (autoFilled) ...[
            const SizedBox(width: 6),
            Icon(Icons.auto_awesome, size: 13, color: primary),
            const SizedBox(width: 3),
            Text('auto-filled',
                style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  // Phone field with a small spinner suffix while looking up
  Widget _fieldPhone(Color primary) {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      maxLines: 1,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'e.g. 9876543210',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        suffixIcon: _lookingUpPhone
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.8, color: primary),
                ),
              )
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      TextInputType kbType, Color primary,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: kbType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: primary.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primary),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
