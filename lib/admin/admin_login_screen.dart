import 'package:flutter/material.dart';
import 'package:no_wait_app/admin/admin_home_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/widgets/app_snackbar.dart';

const Color _kPrimary = Color(0xFF1565C0);

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _loading   = false;
  bool _submitted = false;

  String? get _phoneError {
    if (!_submitted) return null;
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) return 'Phone number is required';
    if (v.length < 10) return 'Enter a valid phone number';
    return null;
  }

  String? get _passwordError {
    if (!_submitted) return null;
    if (_passwordCtrl.text.isEmpty) return 'Password is required';
    return null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _submitted = true);
    if (_phoneError != null || _passwordError != null) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.adminLogin(
        _phoneCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await ApiService.saveToken(res['access_token'] as String);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AdminHomeScreen(
          adminName: (res['admin'] as Map?)?['fullName'] as String? ?? 'Admin',
        )),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Branding ────────────────────────────────────────────
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                  ).let((w) => Center(child: w)),
                  const SizedBox(height: 24),
                  const Text(
                    'Baari Admin Panel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D1B4B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Internal use only',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 40),

                  // ── Phone ───────────────────────────────────────────────
                  _field(
                    label: 'Admin Phone',
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) { if (_submitted) setState(() {}); },
                      decoration: _inputDeco('9876543210'),
                    ),
                    error: _phoneError,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ────────────────────────────────────────────
                  _field(
                    label: 'Password',
                    child: TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onChanged: (_) { if (_submitted) setState(() {}); },
                      onSubmitted: (_) => _login(),
                      decoration: _inputDeco('••••••••').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    error: _passwordError,
                  ),
                  const SizedBox(height: 32),

                  // ── Sign In button ───────────────────────────────────────
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Disclaimer ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unauthorized access to this system is strictly prohibited and may result in legal action.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child, String? error}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: error != null ? Colors.red.shade400 : Colors.grey.shade300),
          color: Colors.white,
        ),
        child: child,
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.error_outline, size: 13, color: Colors.red.shade600),
          const SizedBox(width: 4),
          Text(error, style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
        ]),
      ],
    ]);
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    border: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    isDense: true,
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
