import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: NoGlowScrollBehavior(),
      home: RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
      ),
    );
  }

  // 📱 MOBILE
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _image(),
          const SizedBox(height: 30),
          _text(),
          const SizedBox(height: 30),
          _buttons(context),
          const SizedBox(height: 20),
          _loginLink(context), // 🔥 FIXED
        ],
      ),
    );
  }

  // 📟 TABLET
  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 5, child: _image()),

        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  _text(),
                  const SizedBox(height: 40),
                  _buttons(context),
                  const SizedBox(height: 20),
                  _loginLink(context), // 🔥 FIXED
                ],
              ),
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

  // 🔥 TEXT
  Widget _text() {
    return Column(
      children: [
        // 🔥 ICON ROW
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.content_cut, size: 24),
            SizedBox(width: 10),
            Icon(
              Icons.face_retouching_natural,
              size: 24,
              color: Color(0xFF6FCF97),
            ), // comb alternative
            SizedBox(width: 10),
            Icon(Icons.air, size: 24), // dryer alternative
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          "Look Good.\nFeel Your Best.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        const Text(
          "Book salons & barbers near you",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  // 🔥 BUTTONS
  Widget _buttons(BuildContext context) {
    return Column(
      children: [
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
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (_) => const LoginScreen()),
              // );
            },
            child: const Text("Continue as Customer"),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6FCF97)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {},
            child: const Text(
              "Join as Professional",
              style: TextStyle(color: Color(0xFF6FCF97)),
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 LOGIN LINK (MISSING FIX)
  Widget _loginLink(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      child: const Text(
        "Already have an account? Login",
        style: TextStyle(color: Color(0xFF6FCF97), fontWeight: FontWeight.bold),
      ),
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // 🚫 removes glow
  }
}
