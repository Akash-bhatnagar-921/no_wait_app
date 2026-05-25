import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';
import 'home_screen.dart';
import 'my_bookings_screen.dart';

class BookingSummaryScreen extends StatefulWidget {
  final String salonId;
  final String salonName;
  final String address;
  final String city;
  final String scheduledAt; // ISO string
  final String displayTime;  // e.g. "10:30"
  final DateTime bookingDate;
  final List<dynamic> selectedServices;
  final double totalAmount;
  final int totalDuration;

  const BookingSummaryScreen({
    super.key,
    required this.salonId,
    required this.salonName,
    required this.address,
    required this.city,
    required this.scheduledAt,
    required this.displayTime,
    required this.bookingDate,
    required this.selectedServices,
    required this.totalAmount,
    required this.totalDuration,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _confirming = false;

  String get _dateStr {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final d = widget.bookingDate;
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    }
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  Future<void> _confirmBooking() async {
    setState(() => _confirming = true);
    // Guard: block if customer already has an active upcoming booking
    try {
      final active = await ApiService.getActiveBooking();
      if (active != null && mounted) {
        setState(() => _confirming = false);
        AppSnackbar.warning(
          context,
          'You already have an upcoming booking at ${active['salonName']}. Cancel it first.',
        );
        return;
      }
    } catch (_) { /* network issues — let the backend enforce */ }

    try {
      final services = widget.selectedServices.map((svc) {
        final s = svc as Map<String, dynamic>;
        return {
          'serviceId':   s['id']          as String,
          'serviceName': (s['serviceName'] ?? s['name'] ?? '') as String,
          'price':       ((s['price'] as num?) ?? 0).toDouble(),
          'duration':    ((s['duration'] as num?) ?? 30).toInt(),
        };
      }).toList();

      await ApiService.createBooking(
        salonId:     widget.salonId,
        salonName:   widget.salonName,
        scheduledAt: widget.scheduledAt,
        services:    services,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _showSuccessDialog();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
        AppSnackbar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _confirming = false);
        AppSnackbar.error(context, 'Failed to confirm booking. Please try again.');
      }
    }
  }

  void _showSuccessDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: primary, size: 36),
          ),
          const SizedBox(height: 14),
          const Text('Booking Request Sent!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'Request sent to ${widget.salonName} for $_dateStr at ${widget.displayTime}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // What happens next
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
                const Text('What happens next',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _nextStep(1, Icons.hourglass_top_outlined,
                    'Salon reviews your request', Colors.orange),
                const SizedBox(height: 8),
                _nextStep(2, Icons.vpn_key_outlined,
                    'On acceptance, a 4-digit OTP is sent to you',
                    Colors.blue),
                const SizedBox(height: 8),
                _nextStep(3, Icons.check_circle_outline,
                    'Show the OTP at the salon to begin your appointment',
                    Colors.green),
              ],
            ),
          ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Replace the entire route stack with a clean [HomeScreen → MyBookingsScreen].
                // popUntil(isFirst) was sending users to RoleSelectionScreen when they
                // arrived via signup/login flow, which looked like a logout.
                final nav = Navigator.of(context);
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
                nav.push(
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                );
              },
              child: const Text('View My Bookings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStep(int n, IconData icon, String text, Color color) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text('$n',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final locationStr = [widget.address, widget.city]
        .where((e) => e.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Booking Summary',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 32 : 16, 16,
              isTablet ? 32 : 16, 110,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Salon & appointment info ──────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.content_cut, color: primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.salonName,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              if (locationStr.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(locationStr,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 14),
                      _detailRow(Icons.calendar_today_outlined,
                          'Date', _dateStr),
                      const SizedBox(height: 8),
                      _detailRow(Icons.access_time_rounded,
                          'Time', widget.displayTime),
                      const SizedBox(height: 8),
                      _detailRow(Icons.timer_outlined,
                          'Duration', '~${widget.totalDuration} min'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Selected services ─────────────────────────────────────────
                const Text('Selected Services',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _sectionCard(
                  child: Column(
                    children: [
                      ...widget.selectedServices.asMap().entries.map((e) {
                        final i = e.key;
                        final svc = e.value as Map<String, dynamic>;
                        final name = (svc['serviceName'] ?? svc['name'] ?? '') as String;
                        final price = (svc['price'] as num?)?.toDouble() ?? 0;
                        final duration = (svc['duration'] as num?)?.toInt() ?? 30;
                        return Column(children: [
                          if (i > 0)
                            Divider(height: 1, color: Colors.grey.shade100),
                          if (i > 0) const SizedBox(height: 10),
                          Row(children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  Text('$duration min',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text('₹${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          if (i < widget.selectedServices.length - 1)
                            const SizedBox(height: 10),
                        ]);
                      }),
                      Divider(height: 20, color: Colors.grey.shade200),
                      Row(children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          '₹${widget.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Policy note ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Once accepted, services can be modified or cancelled up to 20 minutes before your appointment.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Confirm button ────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12, offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _confirming ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: primary.withValues(alpha: 0.5),
                  ),
                  child: _confirming
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Send Booking Request  ·  ₹${widget.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade500),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const Spacer(),
      Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }
}
