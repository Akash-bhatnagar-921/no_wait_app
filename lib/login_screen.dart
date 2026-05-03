import 'package:flutter/material.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: isTablet ? _tabletLayout() : _mobileLayout()),
    );
  }

  // 📱 MOBILE
  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_image(), const SizedBox(height: 25), _content()],
      ),
    );
  }

  // 📟 TABLET (split layout)
  Widget _tabletLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(padding: const EdgeInsets.all(24), child: _image()),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _content(),
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 IMAGE
  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset("assets/salon.png", fit: BoxFit.cover),
      ),
    );
  }

  // 🔥 MAIN CONTENT
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICONS (same theme as main screen)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.content_cut, size: 22),
            SizedBox(width: 10),
            Icon(
              Icons.face_retouching_natural,
              size: 22,
              color: Color(0xFF6FCF97),
            ),
            SizedBox(width: 10),
            Icon(Icons.air, size: 22),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          "Welcome Back!",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        const Text(
          "Login to continue and book your next appointment.",
          style: TextStyle(color: Colors.grey),
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

        // SEND OTP BUTTON
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpScreen(phone: phoneController.text),
                ),
              );
            },
            child: const Text("Send OTP", style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(height: 20),

        // BACK LINK (important UX)
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
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
