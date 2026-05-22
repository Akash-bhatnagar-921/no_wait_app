import 'dart:async';
import 'package:flutter/material.dart';
import 'package:no_wait_app/barber_setup/barber_home_screen.dart';
import 'package:no_wait_app/main.dart';
import 'package:no_wait_app/services/api_service.dart';

// Update with real support number
const String _kSupportPhone = '+91-9999999999';

class WaitingScreen extends StatefulWidget {
  final DateTime submittedAt;

  const WaitingScreen({super.key, required this.submittedAt});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  late Timer _countdownTimer;
  late Timer _pollTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Assign timers BEFORE calling _updateRemaining — that method may call
    // _countdownTimer.cancel() if the deadline has already passed, which would
    // throw LateInitializationError on a 'late' field that isn't set yet.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _updateRemaining());
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkApprovalStatus();
    });

    // Safe to call now — both timers are initialised
    _updateRemaining();
  }

  void _updateRemaining() {
    final deadline = widget.submittedAt.add(const Duration(hours: 24));
    var diff = deadline.difference(DateTime.now());
    // Cap at 24 h to absorb server/client clock skew (prevents 24:00:05 etc.)
    if (diff > const Duration(hours: 24)) diff = const Duration(hours: 24);
    _remaining = diff.isNegative ? Duration.zero : diff;
    if (diff.isNegative) _countdownTimer.cancel();
  }

  Future<void> _checkApprovalStatus() async {
    try {
      final salons = await ApiService.getMySalons();
      final approved = salons.firstWhere(
        (s) => s['status'] == 'approved',
        orElse: () => null,
      );
      if (approved != null && mounted) {
        _pollTimer.cancel();
        _countdownTimer.cancel();
        // Token from createSalon is still valid (30-day JWT).
        // Go directly to the dashboard — no need to log in again.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      // Silent — keep polling
    }
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pollTimer.cancel();
    super.dispose();
  }

  String _formatTimer() {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _showSupportSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1A1A2E),
        content: Row(
          children: [
            const Icon(Icons.phone, color: Color(0xFF6FCF97), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  children: [
                    const TextSpan(text: 'Call us @ '),
                    TextSpan(
                      text: _kSupportPhone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6FCF97),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white70,
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final timerDone = _remaining == Duration.zero;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              // minHeight ensures content is vertically centred when shorter
              // than the screen; scrolling kicks in when it's taller (tablet).
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).viewPadding.top -
                    MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTablet ? 560 : 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // ── Icon ───────────────────────────────────────────
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6FCF97).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 48,
                        color: Color(0xFF6FCF97),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Title ──────────────────────────────────────────
                    const Text(
                      'Salon Submitted!',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 14),

                    // ── Note ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Text(
                        'Please wait for 24 hrs to be get verified from our Admin Team.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: Colors.black87, height: 1.5),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Timer ──────────────────────────────────────────
                    if (!timerDone) ...[
                      const Text(
                        'Time remaining',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6FCF97).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _formatTimer(),
                          style: TextStyle(
                            fontSize: isTablet ? 42 : 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: const Color(0xFF2D9248),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Review in progress — we\'ll notify you soon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Back button ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6FCF97)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RoleSelectionScreen()),
                          (route) => false,
                        ),
                        child: const Text(
                          'Back to Login / Sign Up',
                          style: TextStyle(
                            color: Color(0xFF6FCF97),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Contact Support ────────────────────────────────
                    TextButton.icon(
                      onPressed: _showSupportSnackbar,
                      icon: const Icon(Icons.headset_mic_outlined,
                          color: Colors.grey, size: 18),
                      label: const Text(
                        'Contact Support',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
