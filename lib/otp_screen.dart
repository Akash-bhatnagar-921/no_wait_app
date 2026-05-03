import 'package:flutter/material.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

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
        children: [_image(), const SizedBox(height: 25), _content()],
      ),
    );
  }

  // 📟 TABLET
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

  // 🔥 CONTENT
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ICONS
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
          "Verify OTP",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          "Enter the code sent to +91 ${widget.phone}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 30),

        // 🔢 OTP INPUT BOXES
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: 45,
              child: TextField(
                controller: controllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                decoration: InputDecoration(
                  counterText: "",
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
          ),
        ),

        const SizedBox(height: 15),

        const Text(
          "Didn’t receive code? Resend",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 30),

        // VERIFY BUTTON
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text("Verify & Login", style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(height: 20),

        // BACK
        GestureDetector(
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
      ],
    );
  }
}
