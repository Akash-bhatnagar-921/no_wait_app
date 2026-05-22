import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'find_salons_screen.dart';
import 'map_screen.dart';
import 'my_bookings_screen.dart';
import 'services/api_service.dart';
import 'services/location_prefs.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SavedLocation? _location;
  DateTime? _date;
  Map<String, dynamic>? _activeBooking;
  int _monthlyBookingCount = 0;
  String _subscriptionPlan = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final results = await Future.wait([
      LocationPrefs.loadLocation(),
      LocationPrefs.loadDate(),
      ApiService.getActiveBooking(),
      ApiService.getMonthlyBookingCount(),
      ApiService.getSubscription(),
    ]);

    final loc           = results[0] as SavedLocation?;
    final savedDate     = results[1] as DateTime?;
    final activeBooking = results[2] as Map<String, dynamic>?;
    final monthlyCount  = results[3] as int;
    final sub           = results[4] as Map<String, dynamic>;
    // Use '' (not 'free') as the unknown-plan sentinel so an API failure
    // never causes the free-plan banner to show for paid users.
    final plan          = sub['plan']?.toString() ?? '';

    // Discard a saved date that is already in the past
    final today = DateTime.now();
    final validDate = (savedDate != null &&
            !savedDate.isBefore(DateTime(today.year, today.month, today.day)))
        ? savedDate
        : null;

    if (mounted) {
      setState(() {
        _location            = loc;
        _date                = validDate;
        _activeBooking       = activeBooking;
        _monthlyBookingCount = monthlyCount;
        _subscriptionPlan    = plan;
      });
    }
  }

  // ── Location picker ────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final result = await Navigator.push<SavedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    if (result != null && mounted) {
      setState(() => _location = result);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null && mounted) {
      await LocationPrefs.saveDate(picked);
      setState(() => _date = picked);
    }
  }

  // ── Find Salons ────────────────────────────────────────────────────────────

  void _findSalons() {
    if (_activeBooking != null) {
      AppSnackbar.warning(
        context,
        'You already have an upcoming booking. Cancel it first to explore new salons.',
      );
      return;
    }
    if (_location == null) {
      AppSnackbar.warning(context, 'Please select a location first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindSalonsScreen(
          location: _location!,
          date: _date ?? DateTime.now(),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _locationLabel =>
      _location?.name ?? 'Use current location';

  String get _dateLabel {
    if (_date == null) return 'Choose your slot';
    final today = DateTime.now();
    if (_date!.year == today.year && _date!.month == today.month && _date!.day == today.day) {
      return 'Today';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (_date!.year == tomorrow.year && _date!.month == tomorrow.month && _date!.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('d MMM yyyy').format(_date!);
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isDesktop = size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 40),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
            ),
            child: isTablet ? _tabletLayout() : _mobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    return RefreshIndicator(
      onRefresh: _loadSaved,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [_image(), const SizedBox(height: 20), _content()],
        ),
      ),
    );
  }

  Widget _tabletLayout() {
    return Row(children: [
      Expanded(flex: 5, child: Padding(
          padding: const EdgeInsets.all(20), child: _image())),
      Expanded(flex: 5, child: RefreshIndicator(
        onRefresh: _loadSaved,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: _content(),
        ),
      )),
    ]);
  }

  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset('assets/salon.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Find the best salons near you',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Choose your location and date to skip waiting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 25),

        // Location card
        _card(
          icon: Icons.location_on,
          title: 'Location',
          subtitle: _locationLabel,
          hasValue: _location != null,
          onTap: _openMap,
        ),

        // Date card
        _card(
          icon: Icons.calendar_today,
          title: 'Select Date',
          subtitle: _dateLabel,
          hasValue: _date != null,
          onTap: _pickDate,
        ),

        const SizedBox(height: 30),

        // ── Free-plan monthly counter (only shown on free plan) ───────
        if (_subscriptionPlan == 'free' &&
            _activeBooking == null &&
            _monthlyBookingCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14,
                  color: _monthlyBookingCount >= 2
                      ? Colors.red.shade500
                      : Colors.amber.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _monthlyBookingCount >= 2
                      ? 'Free plan limit reached (2/2). Upgrade to book more.'
                      : '$_monthlyBookingCount / 2 free bookings used this month.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _monthlyBookingCount >= 2
                        ? Colors.red.shade500
                        : Colors.amber.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),

        // ── Active booking banner ──────────────────────────────────────
        if (_activeBooking != null) ...[
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            ),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You have an upcoming booking at ${_activeBooking!['salonName']}.',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cancel your existing booking before exploring new salons. Tap to view.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.amber.shade600, size: 18),
                ],
              ),
            ),
          ),
        ],

        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeBooking != null
                  ? Colors.grey.shade300
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: _activeBooking != null
                  ? Colors.grey.shade500
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _findSalons,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_activeBooking != null)
                  const Icon(Icons.block, size: 18),
                if (_activeBooking != null) const SizedBox(width: 8),
                const Text('Find Salons',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool hasValue = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasValue
              ? primary.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: hasValue
              ? Border.all(color: primary.withValues(alpha: 0.35))
              : null,
        ),
        child: Row(children: [
          Icon(icon, color: hasValue ? primary : Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasValue ? primary : Colors.black87)),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: hasValue ? primary.withValues(alpha: 0.8)
                                      : Colors.grey,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14,
              color: hasValue ? primary : Colors.grey.shade400),
        ]),
      ),
    );
  }
}
