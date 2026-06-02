import 'package:flutter/material.dart';
import 'services/api_service.dart';

class SalonAnalyticsScreen extends StatefulWidget {
  const SalonAnalyticsScreen({super.key});

  @override
  State<SalonAnalyticsScreen> createState() => _SalonAnalyticsScreenState();
}

class _SalonAnalyticsScreenState extends State<SalonAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _period = '30d';

  static const _periods = [
    ('7d', 'Last 7 days'),
    ('30d', 'Last 30 days'),
    ('90d', 'Last 90 days'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getSalonAnalytics(period: _period);
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          _PeriodSelector(
            selected: _period,
            periods: _periods,
            primary: primary,
            onChanged: (p) { setState(() => _period = p); _load(); },
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_data == null)
            const Expanded(child: Center(child: Text('No data')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _OverviewGrid(data: _data!),
                    const SizedBox(height: 16),
                    _RetentionCard(data: _data!['customerRetention'] as Map<String, dynamic>? ?? {}),
                    const SizedBox(height: 16),
                    _WalkInCard(data: _data!['walkIns'] as Map<String, dynamic>? ?? {}),
                    const SizedBox(height: 16),
                    _PeakHoursCard(hours: _data!['peakHours'] as List<dynamic>? ?? []),
                    const SizedBox(height: 16),
                    _RevenueTrendCard(trend: _data!['revenueTrend'] as List<dynamic>? ?? []),
                    const SizedBox(height: 16),
                    _TopServicesCard(services: _data!['topServices'] as List<dynamic>? ?? []),
                    const SizedBox(height: 16),
                    _BarberPerformanceCard(barbers: _data!['barberPerformance'] as List<dynamic>? ?? []),
                    const SizedBox(height: 16),
                    _CancellationCard(reasons: _data!['cancellationReasons'] as List<dynamic>? ?? []),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final List<(String, String)> periods;
  final Color primary;
  final void Function(String) onChanged;

  const _PeriodSelector({
    required this.selected,
    required this.periods,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: periods.map((p) {
          final active = selected == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active ? primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Overview grid ─────────────────────────────────────────────────────────────

class _OverviewGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final ov = data['overview'] as Map<String, dynamic>? ?? {};
    final totalBookings = ov['totalBookings'] ?? 0;
    final totalRevenue = double.tryParse(ov['totalRevenue']?.toString() ?? '0') ?? 0;
    final completed = ov['completed'] ?? 0;
    final cancelled = ov['cancelled'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _MetricTile(
          label: 'Total Bookings',
          value: totalBookings.toString(),
          icon: Icons.calendar_today_outlined,
          color: Colors.indigo,
        ),
        _MetricTile(
          label: 'Revenue',
          value: '₹${totalRevenue.toStringAsFixed(0)}',
          icon: Icons.currency_rupee,
          color: Colors.green,
        ),
        _MetricTile(
          label: 'Completed',
          value: completed.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.teal,
        ),
        _MetricTile(
          label: 'Cancelled',
          value: cancelled.toString(),
          icon: Icons.cancel_outlined,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Retention card ────────────────────────────────────────────────────────────

class _RetentionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RetentionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final unique = data['uniqueCustomers'] ?? 0;
    final repeat = data['repeatCustomers'] ?? 0;
    final rate = data['repeatRate'] ?? 0;

    return _AnalyticsCard(
      title: 'Customer Retention',
      icon: Icons.people_outline,
      iconColor: Colors.purple,
      child: Row(
        children: [
          _retStat('Unique', unique.toString(), Colors.blue),
          _retStat('Repeat', repeat.toString(), Colors.green),
          _retStat('Return Rate', '$rate%', Colors.purple),
        ],
      ),
    );
  }

  Widget _retStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Walk-in card ──────────────────────────────────────────────────────────────

class _WalkInCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WalkInCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data['total'] ?? 0;
    final completed = data['completed'] ?? 0;
    final revenue = double.tryParse(data['revenue']?.toString() ?? '0') ?? 0;

    return _AnalyticsCard(
      title: 'Walk-in Customers',
      icon: Icons.person_add_outlined,
      iconColor: Colors.orange,
      child: Row(
        children: [
          _wi('Total', total.toString(), Colors.orange),
          _wi('Served', completed.toString(), Colors.green),
          _wi('Revenue', '₹${revenue.toStringAsFixed(0)}', Colors.teal),
        ],
      ),
    );
  }

  Widget _wi(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Peak hours ────────────────────────────────────────────────────────────────

class _PeakHoursCard extends StatelessWidget {
  final List<dynamic> hours;
  const _PeakHoursCard({required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return _AnalyticsCard(
        title: 'Peak Booking Hours',
        icon: Icons.schedule_outlined,
        iconColor: Colors.blue,
        child: _empty(),
      );
    }

    final maxBookings = hours.fold<int>(0, (m, h) {
      final v = int.tryParse((h as Map<String, dynamic>)['bookings']?.toString() ?? '0') ?? 0;
      return v > m ? v : m;
    });

    return _AnalyticsCard(
      title: 'Peak Booking Hours',
      icon: Icons.schedule_outlined,
      iconColor: Colors.blue,
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (h) {
            final entry = hours.firstWhere(
              (e) => int.tryParse((e as Map<String, dynamic>)['hour']?.toString() ?? '-1') == h,
              orElse: () => null,
            );
            final count = entry != null
                ? int.tryParse((entry as Map<String, dynamic>)['bookings']?.toString() ?? '0') ?? 0
                : 0;
            final fraction = maxBookings > 0 ? count / maxBookings : 0.0;
            final isPeak = count == maxBookings && count > 0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPeak)
                      Text('$count', style: TextStyle(fontSize: 8, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: fraction > 0 ? fraction.clamp(0.05, 1.0) : 0,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isPeak ? Colors.blue : Colors.blue.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (h % 6 == 0)
                      Text(
                        h == 0 ? '12a' : h == 12 ? '12p' : h > 12 ? '${h - 12}p' : '${h}a',
                        style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _empty() => Center(child: Text('No data yet', style: TextStyle(color: Colors.grey.shade400)));
}

// ── Revenue trend ─────────────────────────────────────────────────────────────

class _RevenueTrendCard extends StatelessWidget {
  final List<dynamic> trend;
  const _RevenueTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return _AnalyticsCard(
        title: 'Revenue Trend',
        icon: Icons.trending_up,
        iconColor: Colors.green,
        child: Center(child: Text('No completed bookings yet', style: TextStyle(color: Colors.grey.shade400))),
      );
    }

    final maxRevenue = trend.fold<double>(0, (m, t) {
      final v = double.tryParse((t as Map<String, dynamic>)['revenue']?.toString() ?? '0') ?? 0;
      return v > m ? v : m;
    });

    final totalRevenue = trend.fold<double>(0, (s, t) {
      return s + (double.tryParse((t as Map<String, dynamic>)['revenue']?.toString() ?? '0') ?? 0);
    });

    return _AnalyticsCard(
      title: 'Revenue Trend',
      icon: Icons.trending_up,
      iconColor: Colors.green,
      subtitle: 'Total ₹${totalRevenue.toStringAsFixed(0)}',
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: trend.map((t) {
            final row = t as Map<String, dynamic>;
            final rev = double.tryParse(row['revenue']?.toString() ?? '0') ?? 0;
            final fraction = maxRevenue > 0 ? rev / maxRevenue : 0.0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message: '${row['date']}: ₹${rev.toStringAsFixed(0)}',
                  child: Container(
                    height: (fraction * 90).clamp(4.0, 90.0),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.5 + fraction * 0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Top services ──────────────────────────────────────────────────────────────

class _TopServicesCard extends StatelessWidget {
  final List<dynamic> services;
  const _TopServicesCard({required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return _AnalyticsCard(
        title: 'Most Booked Services',
        icon: Icons.content_cut_outlined,
        iconColor: Colors.teal,
        child: Center(child: Text('No data yet', style: TextStyle(color: Colors.grey.shade400))),
      );
    }

    final maxBookings = int.tryParse(
          (services.first as Map<String, dynamic>)['bookings']?.toString() ?? '1',
        ) ??
        1;

    return _AnalyticsCard(
      title: 'Most Booked Services',
      icon: Icons.content_cut_outlined,
      iconColor: Colors.teal,
      child: Column(
        children: services.take(6).map((s) {
          final row = s as Map<String, dynamic>;
          final bookings = int.tryParse(row['bookings']?.toString() ?? '0') ?? 0;
          final fraction = maxBookings > 0 ? bookings / maxBookings : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['service'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('$bookings', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: Colors.teal.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cancellation reasons ──────────────────────────────────────────────────────

class _CancellationCard extends StatelessWidget {
  final List<dynamic> reasons;
  const _CancellationCard({required this.reasons});

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) {
      return _AnalyticsCard(
        title: 'Cancellation Reasons',
        icon: Icons.cancel_outlined,
        iconColor: Colors.red,
        child: Center(child: Text('No cancellations', style: TextStyle(color: Colors.grey.shade400))),
      );
    }

    return _AnalyticsCard(
      title: 'Cancellation Reasons',
      icon: Icons.cancel_outlined,
      iconColor: Colors.red,
      child: Column(
        children: reasons.map((r) {
          final row = r as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row['reason'] as String? ?? '—', style: const TextStyle(fontSize: 12)),
                ),
                Text(
                  '${row['count']}×',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final String? subtitle;

  const _AnalyticsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (subtitle != null) ...[
                const Spacer(),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Barber performance ────────────────────────────────────────────────────────

class _BarberPerformanceCard extends StatelessWidget {
  final List<dynamic> barbers;
  const _BarberPerformanceCard({required this.barbers});

  @override
  Widget build(BuildContext context) {
    if (barbers.isEmpty) {
      return _AnalyticsCard(
        title: 'Staff Performance',
        icon: Icons.content_cut_outlined,
        iconColor: Colors.deepPurple,
        child: Center(
          child: Text('No staff data yet',
              style: TextStyle(color: Colors.grey.shade400)),
        ),
      );
    }

    final maxCompleted = barbers.fold<int>(0, (m, b) {
      final v = (b as Map<String, dynamic>)['completed'] as int? ?? 0;
      return v > m ? v : m;
    });

    return _AnalyticsCard(
      title: 'Staff Performance',
      icon: Icons.content_cut_outlined,
      iconColor: Colors.deepPurple,
      child: Column(
        children: barbers.map((b) {
          final row = b as Map<String, dynamic>;
          final name      = row['name'] as String? ?? 'Unknown';
          final completed = row['completed'] as int? ?? 0;
          final total     = row['total'] as int? ?? 0;
          final revenue   = (row['revenue'] as num?)?.toDouble() ?? 0;
          final fraction  = maxCompleted > 0 ? completed / maxCompleted : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Text('₹${revenue.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700)),
                  const SizedBox(width: 8),
                  Text('$completed/$total',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.deepPurple.shade50,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple.shade400),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
