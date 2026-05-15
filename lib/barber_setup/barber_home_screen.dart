import 'package:flutter/material.dart';
import 'package:no_wait_app/main.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';
import 'package:no_wait_app/widgets/star_rating.dart';

class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _salon;

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
    final words = _managerName.trim().split(' ');
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
      final salons = await ApiService.getMySalons();
      if (mounted) {
        setState(() {
          _salon = salons.isNotEmpty
              ? salons[0] as Map<String, dynamic>
              : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Appointments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.currency_rupee), label: 'Earnings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const AppLoadingIndicator(message: 'Loading dashboard…')
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _homePage();
      case 1:
        return _comingSoon('Appointments', Icons.calendar_month);
      case 2:
        return _comingSoon('Earnings', Icons.currency_rupee);
      case 3:
        return _profilePage();
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

          // ── Salon card ─────────────────────────────────────────────────
          _salonCard(),

          const SizedBox(height: 30),

          // ── Today's overview ───────────────────────────────────────────
          const Text("Today's Overview",
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),

          GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isTablet ? 4 : 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: isTablet ? 1.0 : 1.2,
              children: [
                overviewCard(
                    icon: Icons.calendar_month,
                    title: 'Appointments',
                    value: '4'),
                overviewCard(
                    icon: Icons.people_outline,
                    title: 'Clients',
                    value: '12'),
                overviewCard(
                    icon: Icons.currency_rupee,
                    title: 'Earnings',
                    value: '₹3240'),
                overviewCard(
                    icon: Icons.star_outline,
                    title: 'Reviews',
                    value: '4.8'),
              ],
            ),

          const SizedBox(height: 35),

          // ── Quick actions ──────────────────────────────────────────────
          const Text('Quick Actions',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),

          GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isTablet ? 4 : 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: isTablet ? 1.0 : 1.2,
              children: [
                actionCard(
                    icon: Icons.calendar_today,
                    title: 'Appointments'),
                actionCard(
                    icon: Icons.people_alt_outlined,
                    title: 'Manage Barbers'),
                actionCard(icon: Icons.content_cut, title: 'Services'),
                actionCard(
                    icon: Icons.settings_outlined, title: 'Settings'),
              ],
            ),

          const SizedBox(height: 35),

          // ── Upcoming appointments ──────────────────────────────────────
          const Text('Upcoming Appointments',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Next 4 scheduled slots for today',
              style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 16),

          isTablet
              ? GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 4.0,
                  children: [
                    _appointmentCard(
                        time: '10:00 AM',
                        clientName: 'Ravi Kumar',
                        service: 'Haircut',
                        booked: true),
                    _appointmentCard(
                        time: '11:30 AM',
                        clientName: 'Priya Sharma',
                        service: 'Beard Trim',
                        booked: true),
                    _appointmentCard(time: '2:00 PM', booked: false),
                    _appointmentCard(time: '3:30 PM', booked: false),
                  ],
                )
              : Column(
                  children: [
                    _appointmentCard(
                        time: '10:00 AM',
                        clientName: 'Ravi Kumar',
                        service: 'Haircut',
                        booked: true),
                    const SizedBox(height: 12),
                    _appointmentCard(
                        time: '11:30 AM',
                        clientName: 'Priya Sharma',
                        service: 'Beard Trim',
                        booked: true),
                    const SizedBox(height: 12),
                    _appointmentCard(time: '2:00 PM', booked: false),
                    const SizedBox(height: 12),
                    _appointmentCard(time: '3:30 PM', booked: false),
                  ],
                ),

          const SizedBox(height: 30),
        ],
      ),
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

  // ── PROFILE PAGE ───────────────────────────────────────────────────────────

  Widget _profilePage() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final workingDaysList =
        (_salon?['workingDays'] as String?)?.split(',') ?? [];

    return SingleChildScrollView(
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

                const SizedBox(height: 6),
                StarRating(
                  rating: ((_salon?['rating'] as num?)?.toDouble()) ?? 0.0,
                  reviewCount: ((_salon?['reviewCount'] as num?)?.toInt()) ?? 0,
                  starSize: 14,
                ),

                const Divider(height: 24),

                _infoRow(Icons.location_on_outlined, 'Address',
                    _salonLocation.isNotEmpty
                        ? _salonLocation
                        : 'Not provided'),

                if ((_salon?['city'] as String?)?.isNotEmpty == true)
                  _infoRow(Icons.location_city, 'City & State',
                      '${_salon!['city']}, ${_salon!['state']} — ${_salon!['pincode']}'),

                if (_contactNumber.isNotEmpty)
                  _infoRow(
                      Icons.phone, 'Contact', _contactNumber),

                if ((_salon?['email'] as String?)?.isNotEmpty == true)
                  _infoRow(Icons.email_outlined, 'Salon Email',
                      _salon!['email'] as String),

                if ((_salon?['openingTime'] as String?)?.isNotEmpty ==
                    true)
                  _infoRow(
                      Icons.access_time,
                      'Working Hours',
                      '${_salon!['openingTime']} – ${_salon!['closingTime']}'),

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
              ],
            ),
          ),

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

  // ── COMING SOON ────────────────────────────────────────────────────────────

  Widget _comingSoon(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Coming soon!',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ── APPOINTMENT CARD ──────────────────────────────────────────────────────

  Widget _appointmentCard({
    required String time,
    bool booked = false,
    String? clientName,
    String? service,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: booked ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: booked
              ? Colors.green.shade100
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: booked
                  ? Colors.green.shade50
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              booked ? Icons.person : Icons.access_time_outlined,
              color: booked ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                booked
                    ? Text('$clientName · $service',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12))
                    : const Text(
                        'Waiting for this slot to be booked',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          if (booked)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Booked',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ── OVERVIEW / ACTION CARDS ────────────────────────────────────────────────

  Widget overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.green, size: 34),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget actionCard({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.green, size: 34),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
