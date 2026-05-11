import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import '../widgets/loading_widget.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String email;
  final int resendRemaining;
  final int expiresInSeconds;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.email,
    required this.resendRemaining,
    required this.expiresInSeconds,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  Timer? otpTimer;
  Timer? resendBlockTimer;
  late int otpSecondsRemaining;
  late int resendRemaining;
  int resendBlockedSeconds = 0;
  late String maskedEmail;

  @override
  void initState() {
    super.initState();
    otpSecondsRemaining = widget.expiresInSeconds;
    resendRemaining = widget.resendRemaining;
    maskedEmail = widget.email;
    _startOtpTimer(widget.expiresInSeconds);
  }

  @override
  void dispose() {
    otpTimer?.cancel();
    resendBlockTimer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 800 : double.infinity,
            ),
            child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  /// ðŸ“± MOBILE
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [_image(), const SizedBox(height: 20), _content(context)],
      ),
    );
  }

  /// ðŸ“Ÿ TABLET / DESKTOP
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

  /// ðŸ–¼ IMAGE
  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset("assets/salon.png", fit: BoxFit.cover),
      ),
    );
  }

  /// ðŸ”¥ CONTENT
  Widget _content(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),

        /// ICONS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.content_cut, size: 24),
            SizedBox(width: 10),
            Icon(
              Icons.face_retouching_natural,
              size: 24,
              color: Color(0xFF6FCF97),
            ),
            SizedBox(width: 10),
            Icon(Icons.air, size: 24),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          "Verify OTP",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          maskedEmail.isEmpty
              ? "Enter the code sent to your registered email"
              : "Enter the code sent to $maskedEmail",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 8),

        Text(
          "Expires in ${_formatDuration(otpSecondsRemaining)}",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 30),

        /// ðŸ”¥ OTP BOXES (FIXED RESPONSIVE WIDTH)
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 6.0;

            // ðŸ”¥ SAFE AVAILABLE WIDTH (extra buffer removed)
            final maxWidth = constraints.maxWidth;

            // minimum usable size for OTP box
            const minBoxSize = 34.0;
            const maxBoxSize = 55.0;

            // calculate raw size
            final rawSize = (maxWidth - (spacing * 5)) / 6;

            // clamp to safe range
            final boxSize = rawSize.clamp(minBoxSize, maxBoxSize);

            return FittedBox(
              fit: BoxFit.scaleDown, // ðŸ”¥ IMPORTANT FIX
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: spacing / 2,
                    ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
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
          },
        ),

        const SizedBox(height: 20),

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

        const SizedBox(height: 30),

        /// ðŸ”¥ BUTTON
        SizedBox(
          width: double.infinity,
          height: isTablet ? 60 : 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _verifyOtp,
            child: const Text("Verify & Login", style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            "Back",
            style: TextStyle(
              color: Color(0xFF6FCF97),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _verifyOtp() async {
    final otp = controllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      _showSnack("Please enter the 6 digit OTP");
      return;
    }

    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingWidget(),
    );

    try {
      final res = await ApiService.verifyLoginOtp(
        phone: widget.phone,
        otp: otp,
      );

      await ApiService.saveToken(res['access_token']);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login successful"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final message = e is ApiException ? e.message : "Login failed";
      _showSnack(message);
    }
  }

  Future<void> _resendOtp() async {
    try {
      final res = await ApiService.requestLoginOtp(phone: widget.phone);

      _clearOtp();
      _startOtpTimer(res['expiresInSeconds'] as int? ?? 300);

      setState(() {
        maskedEmail = res['email']?.toString() ?? maskedEmail;
        resendRemaining = res['resendRemaining'] as int? ?? resendRemaining;
      });

      _showSnack("New OTP sent");
    } catch (e) {
      if (e is ApiException && e.statusCode == 429) {
        final blockedUntil = DateTime.tryParse(
          e.body?['blockedUntil']?.toString() ?? '',
        );

        if (blockedUntil != null) {
          _startResendBlockTimer(blockedUntil);
        }
      }

      final message = e is ApiException
          ? e.message
          : "Failed to resend OTP";
      _showSnack(message);
    }
  }

  void _clearOtp() {
    for (final controller in controllers) {
      controller.clear();
    }
  }

  void _startOtpTimer(int seconds) {
    otpTimer?.cancel();
    setState(() {
      otpSecondsRemaining = seconds;
    });

    otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpSecondsRemaining <= 0) {
        timer.cancel();
        return;
      }

      setState(() {
        otpSecondsRemaining -= 1;
      });
    });
  }

  void _startResendBlockTimer(DateTime blockedUntil) {
    resendBlockTimer?.cancel();

    void updateRemaining() {
      final remaining = blockedUntil.difference(DateTime.now()).inSeconds;
      setState(() {
        resendBlockedSeconds = remaining > 0 ? remaining : 0;
      });
    }

    updateRemaining();
    resendBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateRemaining();

      if (resendBlockedSeconds <= 0) {
        timer.cancel();
      }
    });
  }

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final minutes = safeSeconds ~/ 60;
    final remainingSeconds = safeSeconds % 60;

    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
