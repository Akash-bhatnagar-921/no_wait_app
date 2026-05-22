import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'salon_detail_screen.dart';
import 'widgets/error_retry.dart';
import 'widgets/loading_widget.dart';
import 'booking_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  bool _hasError = false;

  // Track id→status across reloads to detect pending→confirmed transitions
  Map<String, String> _prevStatuses = {};
  List<Map<String, dynamic>> _newlyConfirmed = [];

  List<Map<String, dynamic>> get _upcoming =>
      _bookings.where((b) => b['isUpcoming'] == true).toList();
  List<Map<String, dynamic>> get _past =>
      _bookings.where((b) => b['isUpcoming'] != true).toList();

  // Recently rejected bookings (past 24 h) — alert the user to re-book
  List<Map<String, dynamic>> get _recentlyRejected {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _bookings.where((b) {
      if (b['status'] != 'rejected') return false;
      final dt = DateTime.tryParse(b['updatedAt'] as String? ??
          b['createdAt'] as String? ?? '');
      return dt != null && dt.isAfter(cutoff);
    }).toList();
  }

  // Pending bookings waiting for professional acceptance
  List<Map<String, dynamic>> get _pendingBookings =>
      _upcoming.where((b) => b['status'] == 'pending').toList();

  // Bookings that start within the next 30 minutes
  List<Map<String, dynamic>> get _soonBookings {
    final now = DateTime.now();
    return _upcoming.where((b) {
      final dt = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
      if (dt == null) return false;
      final mins = dt.difference(now).inMinutes;
      return mins >= 0 && mins <= 30;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadBookings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  // Auto-refresh when the user returns to the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final raw = await ApiService.getMyBookings();
      if (!mounted) return;

      final newBookings = raw.cast<Map<String, dynamic>>();

      // Detect any booking that was 'pending' before and is now 'confirmed'
      final confirmed = newBookings.where((b) {
        final id     = b['id'] as String;
        final status = b['status'] as String? ?? '';
        return status == 'confirmed' &&
            _prevStatuses[id] == 'pending';
      }).toList();

      // Build new status snapshot for the next comparison
      final nextStatuses = Map<String, String>.fromEntries(
        newBookings.map((b) =>
            MapEntry(b['id'] as String, b['status'] as String? ?? '')),
      );

      setState(() {
        _bookings       = newBookings;
        _newlyConfirmed = confirmed;
        _prevStatuses   = nextStatuses;
        _loading        = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  /// Dismiss the newly-confirmed banner (user has seen it)
  void _dismissConfirmed() => setState(() => _newlyConfirmed = []);

  int get _pendingCount => _pendingBookings.length;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
          tabs: [
            // ── Upcoming tab — badge shows pending count ──────────────
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Upcoming'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Past'),
          ],
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading bookings…')
          : _hasError
              ? ErrorRetry(onRetry: _loadBookings)
              : Column(
              children: [
                // ── Newly confirmed banner (green, dismissible) ─────────
                if (_newlyConfirmed.isNotEmpty)
                  _DismissibleBanner(
                    bookings: _newlyConfirmed,
                    onDismiss: _dismissConfirmed,
                  ),

                // ── 20-min reminder banner ──────────────────────────────
                if (_soonBookings.isNotEmpty)
                  _ReminderBanner(bookings: _soonBookings),

                // ── Pending acceptance banner ───────────────────────────
                if (_pendingBookings.isNotEmpty && _newlyConfirmed.isEmpty)
                  _StatusBanner(
                    icon: Icons.hourglass_top_outlined,
                    color: Colors.orange.shade600,
                    message:
                        '${_pendingBookings.length} booking${_pendingBookings.length == 1 ? '' : 's'} awaiting salon acceptance.',
                  ),

                // ── Rejected booking banner ─────────────────────────────
                if (_recentlyRejected.isNotEmpty)
                  _StatusBanner(
                    icon: Icons.cancel_outlined,
                    color: Colors.red.shade500,
                    message:
                        '${_recentlyRejected.length == 1 ? 'A booking was' : '${_recentlyRejected.length} bookings were'} rejected. Tap to re-book.',
                    onTap: () => _tabController.animateTo(1),
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _BookingList(
                        bookings: _upcoming,
                        emptyTitle: 'No upcoming bookings',
                        emptySubtitle:
                            'Book your next salon appointment\nand it will appear here.',
                        showFindButton: true,
                        isTablet: isTablet,
                        onRefresh: _loadBookings,
                        statusOptions: const [
                          null, 'pending', 'confirmed', 'in_progress'
                        ],
                      ),
                      _BookingList(
                        bookings: _past,
                        emptyTitle: 'No past bookings',
                        emptySubtitle:
                            'Your completed appointments\nwill appear here.',
                        showFindButton: false,
                        isTablet: isTablet,
                        onRefresh: _loadBookings,
                        statusOptions: const [
                          null, 'completed', 'rejected', 'cancelled'
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Reminder banner ──────────────────────────────────────────────────────────

// ─── Newly-confirmed banner (green, dismissible) ─────────────────────────────

class _DismissibleBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onDismiss;
  const _DismissibleBanner({
    required this.bookings,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final count    = bookings.length;
    final name     = bookings.first['salonName'] as String? ?? 'a salon';
    final message  = count == 1
        ? '✓ Your booking at $name has been accepted! Your OTP is ready.'
        : '✓ $count bookings have been accepted! Your OTPs are ready.';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_outline,
            color: Colors.green.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: Icon(Icons.close, size: 16, color: Colors.green.shade600),
        ),
      ]),
    );
  }
}

// ─── Reminder banner ──────────────────────────────────────────────────────────

class _ReminderBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _ReminderBanner({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final b = bookings.first;
    final name = b['salonName'] as String? ?? 'your salon';
    final dt = DateTime.tryParse(b['scheduledAt'] as String? ?? '');
    final timeStr = dt != null ? DateFormat('HH:mm').format(dt.toLocal()) : '';
    final mins = dt != null ? dt.difference(DateTime.now()).inMinutes : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active_outlined,
            color: Colors.orange.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reminder: $name at $timeStr — in $mins min',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Generic status banner ────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onTap;
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: color, size: 18),
        ]),
      ),
    );
  }
}

// ─── Booking list tab ─────────────────────────────────────────────────────────

class _BookingList extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showFindButton;
  final bool isTablet;
  final Future<void> Function() onRefresh;
  // Status chips available for this tab (null entry = "All")
  final List<String?> statusOptions;

  const _BookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.showFindButton,
    required this.isTablet,
    required this.onRefresh,
    required this.statusOptions,
  });

  @override
  State<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<_BookingList> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    return widget.bookings.where((b) {
      final name = (b['salonName'] as String? ?? '').toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _statusFilter == null || b['status'] == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = _filtered;
    final hasFilter = _searchQuery.isNotEmpty || _statusFilter != null;

    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by salon name…',
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
                  borderSide:
                      BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: primary.withValues(alpha: 0.5))),
            ),
          ),
        ),

        // ── Status filter chips ───────────────────────────────────────
        if (widget.statusOptions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: widget.statusOptions.map((s) {
                final label = s == null
                    ? 'All'
                    : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
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
                                    color:
                                        primary.withValues(alpha: 0.2),
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

        Divider(height: 1, color: Colors.grey.shade100),

        // ── List / empty state ────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(context, hasFilter: hasFilter)
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isTablet ? 32 : 16,
                      vertical: 14,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _BookingCard(booking: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, {required bool hasFilter}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: widget.isTablet ? 480 : double.infinity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFilter
                      ? Icons.search_off_outlined
                      : Icons.calendar_today_outlined,
                  size: 46, color: primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hasFilter ? 'No matching bookings' : widget.emptyTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                hasFilter
                    ? 'Try a different name or status filter.'
                    : widget.emptySubtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.grey, height: 1.5),
              ),
              if (widget.showFindButton && !hasFilter) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Find Salons',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':     return Colors.orange.shade600;
      case 'confirmed':   return Colors.blue.shade600;
      case 'in_progress': return Colors.green.shade600;
      case 'completed':   return Colors.blueGrey.shade500;
      case 'rejected':    return Colors.red.shade400;
      case 'cancelled':   return Colors.red.shade400;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':     return 'Awaiting Acceptance';
      case 'confirmed':   return 'Confirmed';
      case 'in_progress': return 'In Progress';
      case 'completed':   return 'Completed';
      case 'rejected':    return 'Rejected';
      case 'cancelled':   return 'Cancelled';
      default: return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final status = booking['status'] as String?;
    final statusColor = _statusColor(status);
    final name = booking['salonName'] as String? ?? 'Salon';
    final address = booking['address'] as String? ?? '';
    final dt = DateTime.tryParse(booking['scheduledAt'] as String? ?? '');
    final dateStr = dt != null
        ? DateFormat('EEE, d MMM yyyy  ·  HH:mm').format(dt.toLocal())
        : '';
    final amount = (booking['totalAmount'] as num?)?.toDouble() ?? 0;
    final duration = (booking['totalDuration'] as num?)?.toInt() ?? 0;
    final services = (booking['services'] as List?) ?? [];
    final canModify = booking['canModify'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(booking: booking),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + status
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.content_cut, color: primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (address.isNotEmpty)
                  Text(address,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ]),

          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),

          // Date/time + duration
          Row(children: [
            Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 5),
            Expanded(
              child: Text(dateStr,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('~$duration min',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),

          // Services preview
          if (services.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              services.map((s) {
                final svc = s as Map<String, dynamic>;
                return svc['serviceName'] ?? svc['name'] ?? '';
              }).join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 8),

          // Amount row + action tags
          Row(children: [
            Text('₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primary)),
            const Spacer(),
            if (canModify)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Modify available',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500)),
              ),
            // ── Book Again (past bookings only) ──────────────────────
            if (status == 'completed' ||
                status == 'rejected' ||
                status == 'cancelled')
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalonDetailScreen(
                      salonId:   booking['salonId']   as String,
                      salonName: booking['salonName'] as String? ?? 'Salon',
                      address:   booking['address']   as String? ?? '',
                      initialDate: DateTime.now(),
                    ),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh, size: 11, color: primary),
                    const SizedBox(width: 4),
                    Text('Book Again',
                        style: TextStyle(
                            fontSize: 10,
                            color: primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
