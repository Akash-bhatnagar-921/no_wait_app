import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/salon_onboarding_model.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:no_wait_app/barber_setup/waiting_screen.dart';

const int _kMaxBarbers = 20;
const int _kMaxExperience = 50;

class Step3Screen extends StatefulWidget {
  final SalonOnboardingModel salonData;
  const Step3Screen({super.key, required this.salonData});

  @override
  State<Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends State<Step3Screen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Each entry: { name, experience, nameCtrl, expCtrl }
  final List<Map<String, dynamic>> _barbers = [];

  @override
  void initState() {
    super.initState();
    if (widget.salonData.barbers.isNotEmpty) {
      for (final b in widget.salonData.barbers) {
        _addBarberRow(
          name:       b['name']?.toString() ?? '',
          experience: b['experience']?.toString() ?? '',
        );
      }
    } else {
      _addBarberRow(); // start with one empty row
    }
  }

  @override
  void dispose() {
    for (final b in _barbers) {
      (b['nameCtrl'] as TextEditingController).dispose();
      (b['expCtrl']  as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addBarberRow({String name = '', String experience = ''}) {
    _barbers.add({
      'name':       name,
      'experience': experience,
      'nameCtrl':   TextEditingController(text: name),
      'expCtrl':    TextEditingController(text: experience),
    });
  }

  void _removeBarberRow(int index) {
    ((_barbers[index]['nameCtrl']) as TextEditingController).dispose();
    ((_barbers[index]['expCtrl'])  as TextEditingController).dispose();
    setState(() => _barbers.removeAt(index));
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Collect barber data
    final barberData = _barbers.map((b) => {
      'name':       (b['nameCtrl'] as TextEditingController).text.trim(),
      'experience': int.tryParse(
              (b['expCtrl'] as TextEditingController).text.trim()) ?? 0,
    }).toList();

    widget.salonData.barbers = barberData;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator  = Navigator.of(context);

    try {
      final res = await ApiService.createSalon(salonData: widget.salonData);

      if (res['access_token'] != null) {
        await ApiService.saveToken(res['access_token'] as String);
      }

      final createdAt = DateTime.tryParse(
              res['createdAt'] as String? ?? '') ??
          DateTime.now();

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => WaitingScreen(submittedAt: createdAt)),
        (route) => false,
      );
    } on ApiException catch (e) {
      // Strip verbose NestJS prefixes; show only the meaningful part.
      final msg = _friendlyError(e.message);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps backend error strings to short, user-friendly messages.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('phone') && lower.contains('registered')) {
      return 'This salon phone is already registered. Please login.';
    }
    if (lower.contains('phone') || lower.contains('contact')) {
      return 'Invalid salon phone number.';
    }
    if (lower.contains('owner')) return 'Owner name is required.';
    if (lower.contains('salon name') || lower.contains('salonname')) {
      return 'Salon name is required.';
    }
    if (lower.contains('pincode')) return 'Invalid pincode.';
    if (lower.contains('email')) return 'Invalid email address.';
    if (lower.contains('address')) return 'Address is required.';
    if (lower.contains('city')) return 'City is required.';
    if (lower.contains('state')) return 'State is required.';
    // Default: strip long "property X should not exist" chains
    if (raw.length > 120) return 'Please check your inputs and try again.';
    return raw;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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

  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset("assets/logo.png", height: 50)),
          const SizedBox(height: 12),
          const Center(
            child: Text("Join as Professional",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          _mobileStepIndicator(),
          const SizedBox(height: 24),
          Form(key: _formKey, child: _formBody(context)),
        ],
      ),
    );
  }

  Widget _mobileStepIndicator() {
    const primary = Color(0xFF6FCF97);
    final labels = ['Salon Details', 'Services', 'Barbers'];
    return Row(
      children: List.generate(3, (i) {
        final stepNum = i + 1;
        final active  = stepNum == 3;
        final done    = stepNum < 3;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done ? primary : Colors.grey.shade300,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: active || done ? primary : Colors.grey.shade300,
                    child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('$stepNum',
                            style: TextStyle(
                              fontSize: 12,
                              color: active ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: active ? primary : Colors.grey.shade500,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done ? primary : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _tabletLayout(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Row(
          children: [
            Container(
              width: 190,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Image.asset("assets/logo.png", height: 40),
                  const SizedBox(height: 16),
                  const Text("Join as",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Professional",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _tabletStepItem("1", "Salon Details", done: true,  active: false),
                        const SizedBox(height: 52),
                        _tabletStepItem("2", "Services",      done: true,  active: false),
                        const SizedBox(height: 52),
                        _tabletStepItem("3", "Barbers",       done: false, active: true),
                      ],
                    ),
                  ),
                  _secureCard(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(key: _formKey, child: _formBody(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Step heading ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF6FCF97).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Step 3 of 3',
            style: TextStyle(
              color: Color(0xFF2D9248),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text("Barbers in Your Salon",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Add the barbers working at your salon (max $_kMaxBarbers).",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 20),

        // ── Counter row ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: Color(0xFF6FCF97)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Number of Barbers",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    if (_barbers.length >= _kMaxBarbers)
                      Text('Maximum $_kMaxBarbers barbers allowed.',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red)),
                  ],
                ),
              ),
              IconButton(
                splashRadius: 20,
                onPressed: _barbers.length <= 1
                    ? null
                    : () => _removeBarberRow(_barbers.length - 1),
                icon: const Icon(Icons.remove),
              ),
              Text('${_barbers.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                splashRadius: 20,
                onPressed: _barbers.length >= _kMaxBarbers
                    ? null
                    : () => setState(() => _addBarberRow()),
                icon: Icon(Icons.add,
                    color: _barbers.length >= _kMaxBarbers
                        ? Colors.grey.shade300
                        : null),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Barber cards ──────────────────────────────────────────────────
        ...List.generate(_barbers.length, _barberCard),

        const SizedBox(height: 30),

        // ── Buttons ───────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6FCF97),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor:
                      const Color(0xFF6FCF97).withValues(alpha: 0.5),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Finish",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _barberCard(int index) {
    final b        = _barbers[index];
    final nameCtrl = b['nameCtrl'] as TextEditingController;
    final expCtrl  = b['expCtrl']  as TextEditingController;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    const Color(0xFF6FCF97).withValues(alpha: 0.15),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Color(0xFF2D9248),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              const Text("Barber",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (_barbers.length > 1)
                GestureDetector(
                  onTap: () => _removeBarberRow(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade400, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Name ───────────────────────────────────────────────────────
          TextFormField(
            controller: nameCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              LengthLimitingTextInputFormatter(60),
            ],
            textCapitalization: TextCapitalization.words,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Barber name is required';
              if (v.trim().length < 2) return 'Name must be at least 2 characters';
              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                return 'Only alphabets are allowed';
              }
              return null;
            },
            decoration: _fieldDeco("Barber Name"),
          ),

          const SizedBox(height: 10),

          // ── Experience ─────────────────────────────────────────────────
          TextFormField(
            controller: expCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Experience is required';
              final years = int.tryParse(v);
              if (years == null) return 'Enter a valid number';
              if (years < 0) return 'Cannot be negative';
              if (years > _kMaxExperience) {
                return 'Experience cannot exceed $_kMaxExperience years';
              }
              return null;
            },
            decoration:
                _fieldDeco("Years of Experience (0 – $_kMaxExperience)"),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF6FCF97), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      errorStyle:
          const TextStyle(color: Colors.red, fontSize: 11),
    );
  }

  Widget _tabletStepItem(String num, String text,
      {required bool active, required bool done}) {
    const primary = Color(0xFF6FCF97);
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: active || done ? primary : Colors.grey.shade300,
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text(num,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: active ? primary : Colors.black54,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _secureCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6FCF97).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "Secure & Trusted\nYour data is safe with us.",
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
