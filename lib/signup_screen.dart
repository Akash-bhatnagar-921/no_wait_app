import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import '../widgets/loading_widget.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _gender = '';
  bool _termsAccepted = false;
  bool _submitted = false;

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl   = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? get _nameError {
    if (!_submitted) return null;
    final v = _nameCtrl.text.trim();
    if (v.isEmpty) return 'Full name is required';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) return 'Name must contain only letters';
    return null;
  }

  String? get _phoneError {
    if (!_submitted) return null;
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  String? get _emailError {
    if (!_submitted) return null;
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return 'Gmail ID is required';
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@gmail\.com$').hasMatch(v)) {
      return 'Enter a valid Gmail address (e.g. name@gmail.com)';
    }
    return null;
  }

  String? get _ageError {
    if (!_submitted) return null;
    final v = _ageCtrl.text.trim();
    if (v.isEmpty) return 'Age is required';
    final n = int.tryParse(v);
    if (n == null) return 'Age must be a number';
    if (n < 13 || n > 120) return 'Age must be between 13 and 120';
    return null;
  }

  String? get _genderError {
    if (!_submitted) return null;
    if (_gender.isEmpty) return 'Please select your gender';
    return null;
  }

  String? get _termsError {
    if (!_submitted) return null;
    if (!_termsAccepted) return 'You must agree to the Terms & Conditions';
    return null;
  }

  bool get _isValid =>
      _nameError == null &&
      _phoneError == null &&
      _emailError == null &&
      _ageError == null &&
      _genderError == null &&
      _termsError == null;

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_isValid) return;

    final parsedAge = int.parse(_ageCtrl.text.trim());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingWidget(),
    );

    try {
      final res = await ApiService.register(
        phone: _phoneCtrl.text.trim(),
        role: 'customer',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        age: parsedAge,
        gender: _gender,
        hasAcceptedTerms: _termsAccepted,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await ApiService.saveToken(res['access_token']);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup successful ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e is ApiException ? e.message : 'Something went wrong';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ]),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 500 : double.infinity),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  Center(child: Image.asset('assets/logo.png', height: 60)),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Sign up',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 5),
                  const Center(
                    child: Text('Create your account to get started',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 25),

                  // ── Full Name ───────────────────────────────────────────
                  _field(
                    label: 'Full Name',
                    icon: Icons.person,
                    controller: _nameCtrl,
                    error: _nameError,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                    ],
                    onChanged: (_) { if (_submitted) setState(() {}); },
                  ),

                  // ── Mobile Number ───────────────────────────────────────
                  _field(
                    label: 'Mobile Number',
                    icon: Icons.phone,
                    controller: _phoneCtrl,
                    error: _phoneError,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (_) { if (_submitted) setState(() {}); },
                  ),

                  // ── Gmail ID ────────────────────────────────────────────
                  _field(
                    label: 'Gmail ID',
                    icon: Icons.email,
                    controller: _emailCtrl,
                    error: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) { if (_submitted) setState(() {}); },
                  ),

                  // ── Age ─────────────────────────────────────────────────
                  _field(
                    label: 'Age',
                    icon: Icons.cake,
                    controller: _ageCtrl,
                    error: _ageError,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) { if (_submitted) setState(() {}); },
                  ),

                  // ── Gender ──────────────────────────────────────────────
                  const Text('Gender',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _genderBox('Male', Icons.male),
                    _genderBox('Female', Icons.female),
                    _genderBox('Other', Icons.more_horiz),
                  ]),
                  if (_genderError != null) ...[
                    const SizedBox(height: 6),
                    _errorText(_genderError!),
                  ],

                  const SizedBox(height: 18),

                  // ── Terms & Conditions ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (val) => setState(() => _termsAccepted = val!),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen()),
                          ),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                              children: [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms & Conditions and Privacy Policy',
                                  style: TextStyle(
                                    color: Color(0xFF6FCF97),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_termsError != null) _errorText(_termsError!),

                  const SizedBox(height: 20),

                  // ── Submit button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6FCF97),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submit,
                      child: const Text('Continue',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(
                            color: Color(0xFF6FCF97),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
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

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? error,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasError ? Colors.red.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: hasError ? Border.all(color: Colors.red.shade300) : null,
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            decoration: InputDecoration(
              icon: Icon(icon,
                  color: hasError
                      ? Colors.red.shade400
                      : const Color(0xFF6FCF97)),
              hintText: label,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          _errorText(error),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _errorText(String msg) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(children: [
          Icon(Icons.error_outline, size: 13, color: Colors.red.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );

  Widget _genderBox(String gender, IconData icon) {
    final isSelected = _gender == gender;
    final hasError = _genderError != null;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = gender),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6FCF97).withValues(alpha: 0.15)
                : hasError
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6FCF97)
                  : hasError
                      ? Colors.red.shade300
                      : Colors.transparent,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: isSelected
                    ? const Color(0xFF6FCF97)
                    : hasError
                        ? Colors.red.shade400
                        : Colors.black54),
            const SizedBox(height: 5),
            Text(gender,
                style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? const Color(0xFF6FCF97)
                        : hasError
                            ? Colors.red.shade400
                            : Colors.black87)),
          ]),
        ),
      ),
    );
  }
}
