import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:no_wait_app/services/api_service.dart';

const Color _p = Color(0xFF1565C0);

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key});

  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  final _searchCtrl = TextEditingController();
  String _status = '';
  List<dynamic> _bookings = [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _page = 1; _bookings = []; });
    }
    try {
      final res = await ApiService.adminGetBookings(
        page: _page, search: _searchCtrl.text.trim(), status: _status,
      );
      if (mounted) {
        setState(() {
          final fetched = res['bookings'] as List<dynamic>? ?? [];
          _bookings = reset ? fetched : [..._bookings, ...fetched];
          _total = (res['total'] as num?)?.toInt() ?? 0;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _loadingMore = false; });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _bookings.length >= _total) { return; }
    setState(() { _page++; _loadingMore = true; });
    _load();
  }

  void _showDetail(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookingDetailSheet(booking: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    const statuses = {
      '': 'All', 'pending': 'Pending', 'confirmed': 'Confirmed',
      'completed': 'Completed', 'cancelled': 'Cancelled',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _p,
        title: const Text('Bookings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _load(reset: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search salon, customer, phone…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load(reset: true);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ...statuses.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _status == e.key ? Colors.white : Colors.black87)),
                      selected: _status == e.key,
                      onSelected: (_) {
                        setState(() => _status = e.key);
                        _load(reset: true);
                      },
                      selectedColor: _p,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _status == e.key ? _p : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )),
                  Text('$_total total',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _p))
          : _bookings.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No bookings found',
                      style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    color: _p,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == _bookings.length) {
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      color: _p, strokeWidth: 2)));
                        }
                        return _bookingCard(
                            _bookings[i] as Map<String, dynamic>);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final status = b['status'] as String? ?? '';
    final color  = _statusColor(status);
    final dt     = _fmtDt(b['scheduledAt']);
    final amount = double.tryParse(b['totalAmount']?.toString() ?? '0') ?? 0.0;

    return GestureDetector(
      onTap: () => _showDetail(b),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.calendar_month_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(b['salonName'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis),
            Text(
              '${b['customerName'] ?? b['customerPhone'] ?? ''}  ·  $dt',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            _statusChip(status, color),
          ]),
        ]),
      ),
    );
  }

  Widget _statusChip(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6)),
    child: Text(status,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );

  Color _statusColor(String s) => switch (s) {
    'completed'   => Colors.green.shade600,
    'confirmed'   => Colors.blue.shade600,
    'in_progress' => Colors.purple.shade600,
    'pending'     => Colors.orange.shade600,
    'cancelled'   => Colors.grey.shade500,
    _             => Colors.red.shade400,
  };

  String _fmtDt(dynamic v) {
    if (v == null) { return '—'; }
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM, h:mm a').format(dt.toLocal()) : '—';
  }
}

// ── Booking detail sheet ──────────────────────────────────────────────────────

class _BookingDetailSheet extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingDetailSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status  = booking['status'] as String? ?? '';
    final color   = _statusColor(status);
    final amount  = double.tryParse(booking['totalAmount']?.toString() ?? '0') ?? 0.0;
    final fee     = double.tryParse(booking['convenienceFee']?.toString() ?? '0') ?? 0.0;
    final dur     = (booking['totalDuration'] as num?)?.toInt() ?? 0;
    final services = booking['services'] as List<dynamic>? ?? [];

    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(children: [
                Expanded(child: Text(booking['salonName'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ]),
              const Divider(height: 24),
              _row(Icons.person_outline, 'Customer',
                  booking['customerName'] as String? ?? '—'),
              _row(Icons.phone, 'Phone',
                  booking['customerPhone'] as String? ?? '—'),
              _row(Icons.calendar_today_outlined, 'Scheduled',
                  _fmtDt(booking['scheduledAt'])),
              _row(Icons.timer_outlined, 'Duration', '$dur min'),
              _row(Icons.currency_rupee, 'Amount', '₹${amount.toStringAsFixed(2)}'),
              if (fee > 0)
                _row(Icons.percent, 'Convenience Fee (3%)', '₹${fee.toStringAsFixed(2)}'),
              if ((booking['bookingOtp'] as String?) != null)
                _row(Icons.password_outlined, 'OTP',
                    booking['bookingOtp'] as String),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Services',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...services.map((s) {
                  final sm = s as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sm['serviceName'] as String? ?? '',
                          style: const TextStyle(fontSize: 13))),
                      Text('₹${sm['price'] ?? 0}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  );
                }),
              ],
              const SizedBox(height: 20),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Color _statusColor(String s) => switch (s) {
    'completed'   => Colors.green.shade600,
    'confirmed'   => Colors.blue.shade600,
    'in_progress' => Colors.purple.shade600,
    'pending'     => Colors.orange.shade600,
    'cancelled'   => Colors.grey.shade500,
    _             => Colors.red.shade400,
  };

  String _fmtDt(dynamic v) {
    if (v == null) { return '—'; }
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal()) : '—';
  }
}
