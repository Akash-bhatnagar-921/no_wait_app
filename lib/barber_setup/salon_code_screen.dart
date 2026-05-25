import 'package:flutter/material.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/barber_setup/barber_home_screen.dart';
import 'package:no_wait_app/widgets/loading_widget.dart';

class SalonCodeScreen extends StatefulWidget {
  final String phone;

  const SalonCodeScreen({super.key, required this.phone});

  @override
  State<SalonCodeScreen> createState() => _SalonCodeScreenState();
}

class _SalonCodeScreenState extends State<SalonCodeScreen> {
  final _codeController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _snack('Please enter your salon secret code');
      return;
    }

    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingWidget(),
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ApiService.verifySalonCode(phone: widget.phone, code: code);

      navigator.pop(); // dismiss loader
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfessionalHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // dismiss loader
      final msg = e is ApiException ? e.message : 'Invalid secret code. Try again.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
            constraints: BoxConstraints(
              maxWidth: isTablet ? 700 : double.infinity,
            ),
            child: isTablet ? _tabletLayout(context) : _mobileLayout(context),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE ──────────────────────────────────────────────────────────────
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _image(),
          const SizedBox(height: 24),
          _content(context),
        ],
      ),
    );
  }

  // ─── TABLET ──────────────────────────────────────────────────────────────
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
            padding: const EdgeInsets.all(36),
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
        child: Image.asset('assets/salon.png', fit: BoxFit.cover),
      ),
    );
  }

  // ─── CONTENT ─────────────────────────────────────────────────────────────
  Widget _content(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.content_cut, size: 22),
            SizedBox(width: 8),
            Icon(Icons.lock_outline, size: 22, color: Color(0xFF6FCF97)),
            SizedBox(width: 8),
            Icon(Icons.verified_user_outlined, size: 22),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          'Step 2 of 2',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),

        const SizedBox(height: 6),

        const Text(
          'Enter Salon Secret Code',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        const Text(
          'This is the non-expiry code sent to your registered email when your salon was approved.',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // ── Code input ────────────────────────────────────────────────────
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          obscureText: _obscure,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '••••••••••',
            hintStyle: const TextStyle(letterSpacing: 4),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // ── Verify Button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: isTablet ? 60 : 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _verify,
            child: const Text(
              'Verify & Enter Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Back',
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
