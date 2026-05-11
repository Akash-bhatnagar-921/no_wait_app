import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'barber_setup/step1_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isDesktop = size.width >= 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop
                  ? 900
                  : (isTablet ? 700 : double.infinity),
            ),
            child: isTablet
                ? _tabletLayout(context)
                : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  /// 📱 MOBILE
  Widget _mobileLayout(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: _image(),
                  ),

                  const SizedBox(height: 20),

                  _text(),

                  const SizedBox(height: 20),

                  _buttons(context),

                  const SizedBox(height: 10),

                  _loginLink(context),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  /// 📟 TABLET / DESKTOP
  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _image(),
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _text(),
                const SizedBox(height: 30),
                _buttons(context),
                const SizedBox(height: 10),
                _loginLink(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 🖼️ IMAGE
  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset(
          "assets/salon.png",
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// ✨ TEXT
  Widget _text() {
    return Column(
      children: const [
        Icon(Icons.content_cut, size: 28),
        SizedBox(height: 10),
        Text(
          "Look Good.\nFeel Your Best.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Book salons & barbers near you",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// 🔘 BUTTONS
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignupScreen(),
                ),
              );
            },
            child: const Text("Continue as Customer"),
          ),
        ),
        const SizedBox(height: 12),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Step1Screen(),
                ),
              );
            },
            child: const Text(
              "Join as Professional",
              style: TextStyle(color: Color(0xFF6FCF97)),
            ),
          ),
        ),
      ],
    );
  }

  /// 🔗 LOGIN LINK
  Widget _loginLink(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          "Already have an account? Login",
          style: TextStyle(
            color: Color(0xFF6FCF97),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}