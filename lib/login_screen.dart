import 'package:flutter/material.dart';
import 'otp_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'widgets/loading_widget.dart';
import 'widgets/app_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isDesktop = size.width >= 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
            ),
            child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  /// 📱 MOBILE
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [_image(), const SizedBox(height: 20), _content(context)],
      ),
    );
  }

  /// 📟 TABLET / DESKTOP
  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(padding: const EdgeInsets.all(20), child: _image()),
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

  /// 🖼 IMAGE
  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset("assets/salon.png", fit: BoxFit.cover),
      ),
    );
  }

  /// 🔥 CONTENT
  Widget _content(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        const Center(
          child: Text(
            "Welcome Back!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 8),

        const Center(
          child: Text(
            "Login to continue and book your next appointment.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          "Mobile Number",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixText: "+91 ",
            hintText: "Enter your mobile number",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          "We’ll send you an OTP to verify your number",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 30),

        /// 🔥 BUTTON
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
            onPressed: () async {
              final phone = phoneController.text.trim();

              if (phone.isEmpty) {
                AppSnackbar.warning(context, 'Please enter your mobile number');
                return;
              }
              if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                AppSnackbar.warning(context, 'Enter a valid 10-digit mobile number');
                return;
              }

              FocusScope.of(context).unfocus();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const LoadingWidget(message: 'Sending OTP…'),
              );

              try {
                final res = await ApiService.requestLoginOtp(phone: phone);

                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pop();

                final role = res['role']?.toString() ?? 'customer';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtpScreen(
                      phone: phone,
                      email: res['email']?.toString() ?? '',
                      resendRemaining: res['resendRemaining'] as int? ?? 3,
                      expiresInSeconds: res['expiresInSeconds'] as int? ?? 300,
                      role: role,
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                final message =
                    e is ApiException ? e.message : 'Failed to send OTP';
                AppSnackbar.error(context, message);
              }
            },
            child: const Text("Send OTP", style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(height: 20),

        /// 🔥 BACK
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              "Back",
              style: TextStyle(
                color: Color(0xFF6FCF97),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
