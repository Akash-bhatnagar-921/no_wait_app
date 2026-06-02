import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'find_salons_screen.dart';
import 'map_screen.dart';
import 'my_bookings_screen.dart';
import 'salon_detail_screen.dart';
import 'subscriptions_screen.dart';
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
  bool _loading = true;
  bool _hasError = false;
  List<dynamic> _trendingSalons = [];
  List<dynamic> _popularServices = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() { _loading = true; _hasError = false; });
    try {
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
      final plan          = sub['plan']?.toString() ?? '';

      final today = DateTime.now();
      final validDate = (savedDate != null &&
              !savedDate.isBefore(DateTime(today.year, today.month, today.day)))
          ? savedDate
          : null;

      // Fetch trending in parallel — failure is non-fatal
      final trendingData = await ApiService.getTrendingSalons(
        lat: loc?.lat,
        lng: loc?.lng,
      ).catchError((_) => <String, dynamic>{'topSalons': [], 'popularServices': []});

      if (mounted) {
        setState(() {
          _location            = loc;
          _date                = validDate;
          _activeBooking       = activeBooking;
          _monthlyBookingCount = monthlyCount;
          _subscriptionPlan    = plan;
          _trendingSalons      = (trendingData['topSalons'] as List?) ?? [];
          _popularServices     = (trendingData['popularServices'] as List?) ?? [];
          _loading             = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
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
        'Your chair is already reserved! Cancel it first to explore new salons.',
      );
      return;
    }
    if (_location == null) {
      AppSnackbar.warning(context, 'Where should we look? Set your location first.');
      return;
    }
    if (_subscriptionPlan == 'free' && _monthlyBookingCount >= 2) {
      _showBookingLimitDialog();
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

  void _showBookingLimitDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('You\'re on a roll — upgrade to keep going',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'You\'ve used both free bookings this month.\n\nUpgrade to Basic or Pro for unlimited bookings — your barber\'s ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SubscriptionsScreen()),
              );
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _locationLabel =>
      _location?.name ?? 'Tap to set your neighbourhood';

  String get _dateLabel {
    if (_date == null) return 'Pick a date, lock your chair';
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
        child: _loading
            ? _buildSkeleton()
            : _hasError
                ? _errorView()
                : Center(
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

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _ShimmerBox(width: double.infinity,
              height: MediaQuery.of(context).size.width * 1.25),
        ),
        const SizedBox(height: 20),
        const _ShimmerBox(width: double.infinity, height: 22),
        const SizedBox(height: 8),
        const _ShimmerBox(width: 200, height: 14),
        const SizedBox(height: 24),
        const _ShimmerBox(width: double.infinity, height: 66, radius: 14),
        const SizedBox(height: 14),
        const _ShimmerBox(width: double.infinity, height: 66, radius: 14),
        const SizedBox(height: 30),
        const _ShimmerBox(width: double.infinity, height: 55, radius: 14),
      ]),
    );
  }

  Widget _errorView() {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Could not load data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                onPressed: _loadSaved,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
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
            'Time for a fresh look?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Pick your spot, show up fresh. No waiting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 25),

        // Location card
        _card(
          icon: Icons.location_on,
          title: 'Where are you?',
          subtitle: _locationLabel,
          hasValue: _location != null,
          onTap: _openMap,
        ),

        // Date card
        _card(
          icon: Icons.calendar_today,
          title: 'When do you want to go?',
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
                          'Your barber is waiting at ${_activeBooking!['salonName']}.',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'You\'ve already got a chair reserved. Cancel it to book somewhere new.',
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
                const Text('Find Your Next Look',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        // ── Trending Near You ──────────────────────────────────────
        if (_trendingSalons.isNotEmpty || _popularServices.isNotEmpty) ...[
          const SizedBox(height: 32),
          _TrendingSection(
            salons: _trendingSalons,
            services: _popularServices,
            date: _date ?? DateTime.now(),
          ),
        ],
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

// ── Trending Near You section ─────────────────────────────────────────────────

class _TrendingSection extends StatelessWidget {
  final List<dynamic> salons;
  final List<dynamic> services;
  final DateTime date;

  const _TrendingSection({
    required this.salons,
    required this.services,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.local_fire_department_rounded,
              color: Colors.deepOrange.shade400, size: 18),
          const SizedBox(width: 6),
          const Text('Trending Near You',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text('Most-booked salons this week',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 14),

        // Popular services chips
        if (services.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: services.map((s) {
                final svc = s as Map<String, dynamic>;
                final name = svc['service'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Salon cards horizontal scroll
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: salons.length,
            itemBuilder: (_, i) {
              final s = salons[i] as Map<String, dynamic>;
              final name   = s['name'] as String? ?? '';
              final city   = s['city'] as String? ?? '';
              final rating = (s['rating'] as num?)?.toDouble() ?? 0;
              final bookings = s['weeklyBookings'] as int? ?? 0;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalonDetailScreen(
                      salonId:     s['id'] as String,
                      salonName:   name,
                      city:        city,
                      rating:      rating,
                      initialDate: date,
                    ),
                  ),
                ),
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                        child: _SalonCardImage(
                          imageUrl: s['image'] as String?,
                          primary: primary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.star_rounded,
                                  size: 12,
                                  color: Colors.amber.shade600),
                              const SizedBox(width: 2),
                              Text(rating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                              const Spacer(),
                              if (bookings > 0) ...[
                                Icon(Icons.trending_up,
                                    size: 11,
                                    color: Colors.green.shade600),
                                const SizedBox(width: 2),
                                Text('$bookings this week',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade600)),
                              ],
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shimmer skeleton box ──────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(
            Colors.grey.shade200,
            Colors.grey.shade100,
            _anim.value,
          ),
        ),
      ),
    );
  }
}

class _SalonCardImage extends StatelessWidget {
  final String? imageUrl;
  final Color primary;
  const _SalonCardImage({required this.imageUrl, required this.primary});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        '${ApiService.baseUrl}$imageUrl',
        width: double.infinity,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, e, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: double.infinity,
        height: 72,
        color: primary.withValues(alpha: 0.08),
        child: Icon(Icons.content_cut,
            color: primary.withValues(alpha: 0.4), size: 28),
      );
}
