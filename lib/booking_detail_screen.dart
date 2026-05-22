import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';
import 'salon_detail_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Map<String, dynamic> _booking;
  bool _cancelling = false;
  late bool _localHasReview;
  Timer? _otpTimer;
  int _otpSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _localHasReview = _booking['hasReview'] == true;
    _startOtpCountdown();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  // OTP expires 1 hour after scheduledAt
  void _startOtpCountdown() {
    if (_booking['bookingOtp'] == null) return;
    final scheduled = DateTime.tryParse(
        _booking['scheduledAt'] as String? ?? '');
    if (scheduled == null) return;
    final expiresAt = scheduled.add(const Duration(hours: 1));
    _updateOtpSecondsLeft(expiresAt);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateOtpSecondsLeft(expiresAt);
    });
  }

  void _updateOtpSecondsLeft(DateTime expiresAt) {
    final left = expiresAt.difference(DateTime.now()).inSeconds;
    setState(() => _otpSecondsLeft = left < 0 ? 0 : left);
  }

  String get _otpCountdownLabel {
    if (_otpSecondsLeft <= 0) return 'OTP expired';
    final m = _otpSecondsLeft ~/ 60;
    final s = _otpSecondsLeft % 60;
    return 'Expires in $m:${s.toString().padLeft(2, '0')}';
  }

  bool get _isConfirmed => _booking['status'] == 'confirmed';
  bool get _canModify => _booking['canModify'] == true;
  bool get _isCancelled => _booking['status'] == 'cancelled';
  bool get _isPast => _booking['isUpcoming'] != true;

  String get _statusLabel {
    switch (_booking['status'] as String?) {
      case 'pending':      return 'Pending Acceptance';
      case 'confirmed':    return 'Confirmed';
      case 'rejected':     return 'Rejected';
      case 'in_progress':  return 'In Progress';
      case 'completed':    return 'Completed';
      case 'cancelled':    return 'Cancelled';
      default: return 'Unknown';
    }
  }

  Color _statusColor(BuildContext context) {
    switch (_booking['status'] as String?) {
      case 'pending':      return Colors.orange.shade600;
      case 'confirmed':    return Colors.blue.shade600;
      case 'rejected':     return Colors.red.shade400;
      case 'in_progress':  return Colors.green.shade600;
      case 'completed':    return Theme.of(context).colorScheme.primary;
      case 'cancelled':    return Colors.red.shade400;
      default: return Colors.grey;
    }
  }

  String? get _bookingOtp => _booking['bookingOtp'] as String?;

  String get _dateTimeStr {
    final dt = DateTime.tryParse(_booking['scheduledAt'] as String? ?? '');
    if (dt == null) return '';
    return DateFormat('EEE, d MMM yyyy  ·  HH:mm').format(dt.toLocal());
  }

  List<dynamic> get _services => (_booking['services'] as List?) ?? [];

  static const _cancelReasons = [
    'Changed plans',
    'Wrong time selected',
    'Found another salon',
    'Other',
  ];

  Future<void> _cancelBooking() async {
    // Show reason picker first
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelReasonSheet(reasons: _cancelReasons),
    );
    if (result == null || !mounted) return; // user dismissed without selecting

    setState(() => _cancelling = true);
    try {
      await ApiService.cancelBooking(
        _booking['id'] as String,
        reason: result,
      );
      if (mounted) {
        setState(() {
          _booking['status'] = 'cancelled';
          _booking['canModify'] = false;
          _cancelling = false;
        });
        AppSnackbar.success(context, 'Booking cancelled.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.error(context, 'Failed to cancel. Please try again.');
      }
    }
  }

  Future<void> _openDirections() async {
    final address = (_booking['address'] as String? ?? '').trim();
    if (address.isEmpty) return;
    HapticFeedback.lightImpact();
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reschedule() async {
    // Step 1: explain what will happen and get confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reschedule Booking',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Your current booking will be cancelled and you\'ll be taken to '
          'the salon page to pick a new time and services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep It', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Reschedule'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: cancel the current booking
    setState(() => _cancelling = true);
    try {
      await ApiService.cancelBooking(_booking['id'] as String,
          reason: 'Reschedule');
      if (!mounted) return;
      setState(() {
        _booking['status'] = 'cancelled';
        _booking['canModify'] = false;
        _cancelling = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.error(context, e.message);
      }
      return;
    }

    // Step 3: open salon detail so the user can pick a new time + services
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalonDetailScreen(
          salonId:     _booking['salonId']   as String,
          salonName:   _booking['salonName'] as String? ?? 'Salon',
          address:     _booking['address']   as String? ?? '',
          initialDate: DateTime.now(),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final statusColor = _statusColor(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Booking Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(
                  _isCancelled
                      ? Icons.cancel_outlined
                      : _isConfirmed
                          ? Icons.check_circle_outline
                          : Icons.done_all_rounded,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(_statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                if (_canModify) ...[
                  const Spacer(),
                  Text('Modifiable',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                ],
              ]),
            ),

            // ── Booking OTP (shown only for confirmed upcoming bookings) ────
            if (_bookingOtp != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.vpn_key_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text('Your Booking OTP',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _bookingOtp!.split('').map((digit) => Container(
                      width: 52, height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(digit,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Show this OTP to the salon professional\nto begin your appointment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _otpSecondsLeft <= 300
                          ? Colors.red.shade600
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _otpSecondsLeft <= 0
                            ? Icons.timer_off_outlined
                            : Icons.timer_outlined,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _otpCountdownLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),

            // ── Salon & time ────────────────────────────────────────────────
            _card(
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
                      child: Text(
                        _booking['salonName'] as String? ?? 'Salon',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  if ((_booking['address'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _booking['address'] as String,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openDirections,
                        child: Tooltip(
                          message: 'Get Directions',
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.directions_outlined,
                                size: 16, color: Colors.blue.shade700),
                          ),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(_dateTimeStr,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      '~${_booking['totalDuration']} min total',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Services ────────────────────────────────────────────────────
            const Text('Services',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _card(
              child: Column(children: [
                ..._services.asMap().entries.map((e) {
                  final i = e.key;
                  final svc = e.value as Map<String, dynamic>;
                  final name = (svc['serviceName'] ?? svc['name'] ?? '') as String;
                  final price = (svc['price'] as num?)?.toDouble() ?? 0;
                  final duration = (svc['duration'] as num?)?.toInt() ?? 30;
                  return Column(children: [
                    if (i > 0) Divider(height: 16, color: Colors.grey.shade100),
                    Row(children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: primary, shape: BoxShape.circle),
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
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ]);
                }),
                Divider(height: 20, color: Colors.grey.shade200),
                Row(children: [
                  const Text('Total',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    '₹${((_booking['totalAmount'] as num?) ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ]),
              ]),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            if (_canModify && !_isCancelled) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: const Text('Reschedule / Change Services'),
                  onPressed: _cancelling ? null : _reschedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: _cancelling
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cancel Booking'),
                  onPressed: _cancelling ? null : _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],

            // ── Rate & Review ────────────────────────────────────────────────
            if (_isPast && !_isCancelled) ...[
              const SizedBox(height: 24),
              _localHasReview
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.star_rounded,
                            color: primary, size: 18),
                        const SizedBox(width: 8),
                        Text('You have reviewed this salon',
                            style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openReviewSheet,
                          child: Text('Edit',
                              style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline)),
                        ),
                      ]),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Rate & Review'),
                        onPressed: _openReviewSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
            ],

            // ── Re-Book shortcut ─────────────────────────────────────────
            if (_isPast) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Book Again at this Salon'),
                  onPressed: () {
                    final dt = DateTime.tryParse(
                        _booking['scheduledAt'] as String? ?? '');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalonDetailScreen(
                          salonId:   _booking['salonId'] as String,
                          salonName: _booking['salonName'] as String? ?? 'Salon',
                          address:   _booking['address'] as String? ?? '',
                          initialDate: dt != null && dt.isAfter(DateTime.now())
                              ? dt
                              : DateTime.now(),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openReviewSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        salonId: _booking['salonId'] as String,
        salonName: _booking['salonName'] as String? ?? 'Salon',
        bookingId: _booking['id'] as String,
      ),
    );
    if (submitted == true && mounted) {
      setState(() => _localHasReview = true);
    }
  }

  Widget _card({required Widget child}) {
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
}

// ─── Review bottom sheet ──────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final String salonId;
  final String salonName;
  final String bookingId;

  const _ReviewSheet({
    required this.salonId,
    required this.salonName,
    required this.bookingId,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppSnackbar.warning(context, 'Please select a star rating.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.submitReview(
        salonId:   widget.salonId,
        rating:    _rating,
        comment:   _commentCtrl.text.trim(),
        bookingId: widget.bookingId,
      );
      if (mounted) {
        AppSnackbar.success(context, 'Review submitted. Thank you!');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.error(context, 'Failed to submit review. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final mq       = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final maxH      = mq.size.height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, keyboardH + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        // Keeps content reachable when keyboard is up
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Text('Rate ${widget.salonName}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Share your experience with other customers.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

          const SizedBox(height: 20),

          // ── Star selector ─────────────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(filled),
                        size: 44,
                        color: filled ? Colors.amber.shade500 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_rating > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
                style: TextStyle(
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Comment ───────────────────────────────────────────────────
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Write about your experience (optional)…',
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: primary.withValues(alpha: 0.5))),
              contentPadding: const EdgeInsets.all(14),
              counterStyle:
                  TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),

          const SizedBox(height: 16),

          // ── Submit ────────────────────────────────────────────────────
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
                disabledBackgroundColor: primary.withValues(alpha: 0.5),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Review',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        ),    // Column
      ),      // SingleChildScrollView
      ),      // Container
    );        // ConstrainedBox
  }
}

// ── Cancellation reason bottom sheet ──────────────────────────────────────────

class _CancelReasonSheet extends StatefulWidget {
  final List<String> reasons;
  const _CancelReasonSheet({required this.reasons});

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Why are you cancelling?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Your feedback helps salons improve.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ...widget.reasons.map((r) => GestureDetector(
            onTap: () => setState(() => _selected = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _selected == r
                    ? primary.withValues(alpha: 0.07)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selected == r ? primary : Colors.grey.shade200,
                  width: _selected == r ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  _selected == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: _selected == r ? primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(r,
                    style: TextStyle(
                      fontSize: 14,
                      color: _selected == r ? primary : Colors.black87,
                      fontWeight: _selected == r
                          ? FontWeight.w600
                          : FontWeight.normal,
                    )),
              ]),
            ),
          )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: const Text('Confirm Cancellation',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
