import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/barber_setup/barber_home_screen.dart';
import 'package:no_wait_app/barber_setup/waiting_screen.dart';
import '../widgets/loading_widget.dart';
import '../widgets/app_snackbar.dart';
import '../theme/theme_manager.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String email;
  final int resendRemaining;
  final int expiresInSeconds;

  /// 'professional' | 'customer' — set at Send-OTP time so the screen
  /// can show the salon secret-code field immediately for professionals.
  final String role;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.email,
    required this.resendRemaining,
    required this.expiresInSeconds,
    this.role = 'customer',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> controllers =
      List.generate(6, (_) => TextEditingController());

  final TextEditingController _secretCodeController = TextEditingController();
  bool _secretObscure = true;

  Timer? otpTimer;
  Timer? resendBlockTimer;
  late int otpSecondsRemaining;
  late int resendRemaining;
  int resendBlockedSeconds = 0;
  late String maskedEmail;

  bool get _isProfessional => widget.role == 'professional';

  @override
  void initState() {
    super.initState();
    otpSecondsRemaining = widget.expiresInSeconds;
    resendRemaining     = widget.resendRemaining;
    maskedEmail         = widget.email;
    _startOtpTimer(widget.expiresInSeconds);
    _startResendCooldown(60); // always block resend for 60 s on first load
  }

  @override
  void dispose() {
    otpTimer?.cancel();
    resendBlockTimer?.cancel();
    for (final c in controllers) {
      c.dispose();
    }
    _secretCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
            child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [_image(), const SizedBox(height: 20), _content(context)],
      ),
    );
  }

  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(padding: const EdgeInsets.all(24), child: _image()),
        ),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _content(context),
          ),
        ),
      ],
    );
  }

  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset("assets/salon.png", fit: BoxFit.cover),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),

        // ── Step badge for professionals ──────────────────────────────────
        if (_isProfessional)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6FCF97).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Professional Login — 2-Step Verification",
              style: TextStyle(
                  color: Color(0xFF2D9248),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),

        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.content_cut, size: 24),
            SizedBox(width: 10),
            Icon(Icons.face_retouching_natural,
                size: 24, color: Color(0xFF6FCF97)),
            SizedBox(width: 10),
            Icon(Icons.air, size: 24),
          ],
        ),

        const SizedBox(height: 20),

        Text(
          _isProfessional ? "Step 1 — Verify OTP" : "Verify OTP",
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          maskedEmail.isEmpty
              ? (_isProfessional
                  ? "Contact Baari admin for your OTP code"
                  : "Check your SMS or registered email for the code")
              : "Check your SMS or $maskedEmail for the code",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 6),

        Text(
          "Expires in ${_formatDuration(otpSecondsRemaining)}",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 28),

        // ── OTP boxes ─────────────────────────────────────────────────────
        LayoutBuilder(builder: (context, constraints) {
          const spacing = 6.0;
          const minBoxSize = 34.0;
          const maxBoxSize = 55.0;
          final rawSize = (constraints.maxWidth - (spacing * 5)) / 6;
          final boxSize = rawSize.clamp(minBoxSize, maxBoxSize);

          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: spacing / 2),
                  child: SizedBox(
                    width: boxSize,
                    height: boxSize,
                    child: TextField(
                      controller: controllers[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: boxSize * 0.5,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                    ),
                  ),
                );
              }),
            ),
          );
        }),

        const SizedBox(height: 16),

        TextButton(
          onPressed: resendBlockedSeconds > 0 ? null : _resendOtp,
          child: Text(
            resendBlockedSeconds > 0
                ? "Come after ${_formatDuration(resendBlockedSeconds)}"
                : "Didn't receive code? Resend",
            style: const TextStyle(fontSize: 12),
          ),
        ),

        if (resendRemaining >= 0 && resendBlockedSeconds == 0)
          Text(
            "Resends left: $resendRemaining",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

        // ── Step 2: Salon Secret Code (professionals only) ─────────────────
        if (_isProfessional) ...[
          const SizedBox(height: 28),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "Step 2 — Salon Secret Code",
                  style: TextStyle(
                      color: Color(0xFF2D9248),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Enter the non-expiry code sent to your email when your salon was approved.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretCodeController,
            keyboardType: TextInputType.number,
            obscureText: _secretObscure,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "••••••••••",
              hintStyle: const TextStyle(letterSpacing: 4),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _secretObscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _secretObscure = !_secretObscure),
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ── Verify button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: isTablet ? 60 : 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _verifyOtp,
            child: Text(
              _isProfessional ? "Verify & Enter Dashboard" : "Verify & Login",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            "Back",
            style: TextStyle(
                color: Color(0xFF6FCF97), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Verify ─────────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = controllers.map((c) => c.text).join();

    if (otp.length != 6) {
      AppSnackbar.warning(context, 'Please enter the 6-digit OTP');
      return;
    }

    if (_isProfessional && _secretCodeController.text.trim().isEmpty) {
      AppSnackbar.warning(context, 'Please enter your salon secret code (Step 2)');
      return;
    }

    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingWidget(message: 'Verifying…'),
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Step 1 — verify OTP
      final res = await ApiService.verifyLoginOtp(
        phone: widget.phone,
        otp: otp,
      );

      await ApiService.saveToken(res['access_token'] as String);

      final userMap = res['user'] as Map<String, dynamic>?;
      final confirmedRole = userMap?['role']?.toString() ?? '';

      // Auto-apply gender theme immediately after login
      await ThemeManager.instance
          .setThemeFromGender(userMap?['gender'] as String?);

      if (confirmedRole == 'professional') {
        // Check salon approval status
        final salons = await ApiService.getMySalons();
        navigator.pop(); // dismiss loader

        if (!mounted) return;

        final pending = salons.firstWhere(
          (s) => s['status'] == 'pending',
          orElse: () => null,
        );

        if (pending != null) {
          final createdAt = DateTime.parse(
            pending['createdAt'] as String? ??
                DateTime.now().toIso8601String(),
          );
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => WaitingScreen(submittedAt: createdAt),
            ),
          );
          return;
        }

        final approved = salons.firstWhere(
          (s) => s['status'] == 'approved',
          orElse: () => null,
        );

        if (approved == null) {
          AppSnackbar.infoM(messenger,
              'No salon found. Please contact Baari support.');
          return;
        }

        // Step 2 — verify salon secret code
        try {
          await ApiService.verifySalonCode(
            phone: widget.phone,
            code: _secretCodeController.text.trim(),
          );
        } on ApiException catch (e) {
          AppSnackbar.errorM(messenger, e.message);
          return;
        }

        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen()),
        );
        return;
      }

      // Customer → home
      navigator.pop(); // dismiss loader
      if (!mounted) return;

      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      AppSnackbar.successM(messenger, 'Login successful!');
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // dismiss loader (safety)
      final message = e is ApiException ? e.message : 'Login failed';
      AppSnackbar.error(context, message);
    }
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────────

  Future<void> _resendOtp() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiService.requestLoginOtp(phone: widget.phone);

      _clearOtp();
      _startOtpTimer(res['expiresInSeconds'] as int? ?? 300);
      _startResendCooldown(60); // lock resend for 60 s after each send

      setState(() {
        maskedEmail     = res['email']?.toString() ?? maskedEmail;
        resendRemaining = res['resendRemaining'] as int? ?? resendRemaining;
      });

      AppSnackbar.successM(messenger, 'New OTP sent');
    } catch (e) {
      if (e is ApiException && e.statusCode == 429) {
        final blockedUntil = DateTime.tryParse(
          e.body?['blockedUntil']?.toString() ?? '',
        );
        if (blockedUntil != null) _startResendBlockTimer(blockedUntil);
      }
      final message =
          e is ApiException ? e.message : 'Failed to resend OTP';
      AppSnackbar.errorM(messenger, message);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _clearOtp() {
    for (final c in controllers) {
      c.clear();
    }
  }

  void _startOtpTimer(int seconds) {
    otpTimer?.cancel();
    setState(() => otpSecondsRemaining = seconds);

    otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpSecondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => otpSecondsRemaining -= 1);
    });
  }

  void _startResendCooldown(int seconds) {
    resendBlockTimer?.cancel();
    setState(() => resendBlockedSeconds = seconds);
    resendBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => resendBlockedSeconds -= 1);
      if (resendBlockedSeconds <= 0) timer.cancel();
    });
  }

  void _startResendBlockTimer(DateTime blockedUntil) {
    resendBlockTimer?.cancel();

    void updateRemaining() {
      final remaining = blockedUntil.difference(DateTime.now()).inSeconds;
      setState(() => resendBlockedSeconds = remaining > 0 ? remaining : 0);
    }

    updateRemaining();
    resendBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateRemaining();
      if (resendBlockedSeconds <= 0) timer.cancel();
    });
  }

  String _formatDuration(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return "$m:${r.toString().padLeft(2, '0')}";
  }

}
