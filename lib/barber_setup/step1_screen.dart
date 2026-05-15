import 'package:flutter/material.dart';
import 'step2_screen.dart';
import 'models/salon_onboarding_model.dart';
import 'package:no_wait_app/services/api_service.dart';

class Step1Screen extends StatefulWidget {
  const Step1Screen({super.key});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  final salonData = SalonOnboardingModel();

  // Salon detail controllers
  final salonNameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();
  final stateController = TextEditingController();
  final landmarkController = TextEditingController();
  final contactController = TextEditingController();
  final emailController = TextEditingController();

  // Business owner controllers (for records only — NOT the login phone)
  final ownerNameController  = TextEditingController();
  final ownerPhoneController = TextEditingController();

  // Franchise state
  bool _isFranchise = false;
  String _franchiseId = '';
  String _franchiseName = '';
  final TextEditingController _franchiseSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _franchiseResults = [];
  bool _searchingFranchise = false;

  bool _isCheckingPhone = false;

  @override
  void dispose() {
    salonNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    stateController.dispose();
    landmarkController.dispose();
    contactController.dispose();
    emailController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    _franchiseSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchFranchise(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _franchiseResults = []);
      return;
    }
    setState(() => _searchingFranchise = true);
    try {
      final results = await ApiService.searchFranchises(query.trim());
      setState(() {
        _franchiseResults = results
            .map((e) => {'id': e['id'] as String, 'name': e['name'] as String})
            .toList();
      });
    } catch (_) {
      setState(() => _franchiseResults = []);
    } finally {
      setState(() => _searchingFranchise = false);
    }
  }

  Future<void> _onNext() async {
    final snack = ScaffoldMessenger.of(context);

    // ── Salon fields ───────────────────────────────────────────────────────
    if (salonData.salonName.isEmpty ||
        salonData.address.isEmpty ||
        salonData.city.isEmpty ||
        salonData.pincode.isEmpty ||
        salonData.state.isEmpty) {
      snack.showSnackBar(
          const SnackBar(content: Text('Please fill all required salon fields')));
      return;
    }

    // ── Salon phone (login credential) ────────────────────────────────────
    final salonPhone = contactController.text.trim();
    if (salonPhone.length != 10 || int.tryParse(salonPhone) == null) {
      snack.showSnackBar(const SnackBar(
          content: Text('Please enter a valid 10-digit salon phone number')));
      return;
    }

    // ── Business owner ────────────────────────────────────────────────────
    if (ownerNameController.text.trim().isEmpty) {
      snack.showSnackBar(
          const SnackBar(content: Text("Please enter the owner's full name")));
      return;
    }

    final ownerPhone = ownerPhoneController.text.trim();
    if (ownerPhone.isNotEmpty &&
        (ownerPhone.length != 10 || int.tryParse(ownerPhone) == null)) {
      snack.showSnackBar(const SnackBar(
          content: Text('Please enter a valid 10-digit owner phone number')));
      return;
    }

    // ── Franchise ──────────────────────────────────────────────────────────
    if (_isFranchise && _franchiseId.isEmpty && _franchiseName.isEmpty) {
      snack.showSnackBar(const SnackBar(
          content:
              Text('Please search and select a franchise, or type a new name')));
      return;
    }

    // ── Check salon phone uniqueness against User table ────────────────────
    setState(() => _isCheckingPhone = true);
    try {
      final res = await ApiService.checkPhone(salonPhone);
      if (res['exists'] == true) {
        if (!mounted) return;
        snack.showSnackBar(const SnackBar(
            content: Text(
                'This salon phone number is already registered. Please login.')));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      snack.showSnackBar(
          const SnackBar(content: Text('Could not verify phone. Try again.')));
      return;
    } finally {
      if (mounted) setState(() => _isCheckingPhone = false);
    }

    // ── Persist to model ───────────────────────────────────────────────────
    salonData.contactNumber = salonPhone;
    salonData.ownerName     = ownerNameController.text.trim();
    salonData.ownerPhone    = ownerPhone; // may be empty — that is fine
    salonData.isFranchise   = _isFranchise;
    salonData.franchiseId   = _franchiseId;
    salonData.franchiseName = _franchiseName;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Step2Screen(salonData: salonData)),
    );
  }

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

  // ─── MOBILE ─────────────────────────────────────────────────────────────────
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset("assets/logo.png", height: 50)),
          const SizedBox(height: 15),
          const Center(
            child: Column(
              children: [
                Text("Join as", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Professional",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _mobileStepIndicator(1),
          const SizedBox(height: 25),
          _form(context),
        ],
      ),
    );
  }

  Widget _mobileStepIndicator(int active) {
    return Row(
      children: [
        _circle(1, active),
        const Expanded(child: Divider()),
        _circle(2, active),
        const Expanded(child: Divider()),
        _circle(3, active),
      ],
    );
  }

  Widget _circle(int num, int active) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: num == active ? const Color(0xFF6FCF97) : Colors.grey,
      child: Text("$num",
          style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  // ─── TABLET ──────────────────────────────────────────────────────────────────
  Widget _tabletLayout(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Row(
          children: [
            Container(
              width: 180,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Image.asset("assets/logo.png", height: 40),
                  const SizedBox(height: 20),
                  const Text("Join as",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Professional",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stepItem("1", "Salon Details", true),
                        const SizedBox(height: 55),
                        _stepItem("2", "Services", false),
                        const SizedBox(height: 55),
                        _stepItem("3", "Barbers", false),
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
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _form(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FORM ────────────────────────────────────────────────────────────────────
  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Salon Details ──────────────────────────────────────────────────────
        const Text(
          "Salon / Shop Details",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _input("Shop / Salon Name", salonNameController,
            onChanged: (v) => salonData.salonName = v),
        _input("Address", addressController,
            onChanged: (v) => salonData.address = v),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Column(children: [
              _input("City", cityController,
                  onChanged: (v) => salonData.city = v),
              _input("Pincode", pincodeController,
                  onChanged: (v) => salonData.pincode = v),
            ]);
          }
          return Row(children: [
            Expanded(
                child: _input("City", cityController,
                    onChanged: (v) => salonData.city = v)),
            const SizedBox(width: 10),
            Expanded(
                child: _input("Pincode", pincodeController,
                    onChanged: (v) => salonData.pincode = v)),
          ]);
        }),
        _input("State", stateController,
            onChanged: (v) => salonData.state = v),
        _input("Landmark (Optional)", landmarkController,
            onChanged: (v) => salonData.landmark = v),
        // Salon phone = login credential — make the hint text explicit
        _input(
          "Salon Phone Number (Login / OTP)",
          contactController,
          keyboardType: TextInputType.phone,
          onChanged: (v) => salonData.contactNumber = v,
        ),
        // Small note under the phone field
        const Padding(
          padding: EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            "This number is used to log in to the Baari professional app.",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
        _input("Shop Email (Optional)", emailController,
            onChanged: (v) => salonData.shopEmail = v),

        // ── Business / Franchise Owner ─────────────────────────────────────
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          "Business Owner",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          "The person who owns this salon business. One owner can register "
          "multiple salons — their phone number can be shared across branches.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _input("Owner Full Name", ownerNameController),
        _input("Owner Phone Number (Optional)", ownerPhoneController,
            keyboardType: TextInputType.phone),
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Owner phone is for ownership records only — it is NOT used for app login.",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Franchise ─────────────────────────────────────────────────────────
        const Divider(),
        const SizedBox(height: 6),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _isFranchise,
          title: const Text(
            "Does your salon come under any franchise?",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          activeColor: const Color(0xFF6FCF97),
          onChanged: (val) {
            setState(() {
              _isFranchise = val ?? false;
              if (!_isFranchise) {
                _franchiseId = '';
                _franchiseName = '';
                _franchiseSearchController.clear();
                _franchiseResults = [];
              }
            });
          },
        ),

        if (_isFranchise) ...[
          const SizedBox(height: 8),
          _franchiseSection(),
        ],

        const SizedBox(height: 30),

        // ── Next Button ───────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isCheckingPhone ? null : _onNext,
            child: _isCheckingPhone
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text("Next"),
          ),
        ),
      ],
    );
  }

  // ─── FRANCHISE SECTION ────────────────────────────────────────────────────────
  Widget _franchiseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected franchise chip
        if (_franchiseId.isNotEmpty || _franchiseName.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6FCF97).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF6FCF97), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _franchiseName.isNotEmpty ? _franchiseName : _franchiseId,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _franchiseId = '';
                    _franchiseName = '';
                    _franchiseSearchController.clear();
                    _franchiseResults = [];
                  }),
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),

        // Search field
        TextField(
          controller: _franchiseSearchController,
          decoration: InputDecoration(
            hintText: "Search franchise group (e.g. Image Salon)",
            filled: true,
            fillColor: Colors.grey.shade100,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _searchFranchise,
        ),

        const SizedBox(height: 6),

        if (_searchingFranchise)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_franchiseResults.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _franchiseResults
                  .map((f) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.business_outlined,
                            color: Color(0xFF6FCF97)),
                        title: Text(f['name'] as String),
                        onTap: () {
                          setState(() {
                            _franchiseId = f['id'] as String;
                            _franchiseName = f['name'] as String;
                            _franchiseSearchController.text =
                                f['name'] as String;
                            _franchiseResults = [];
                          });
                        },
                      ))
                  .toList(),
            ),
          )
        else if (_franchiseSearchController.text.trim().isNotEmpty &&
            !_searchingFranchise)
          // Offer to create a new franchise group
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline,
                color: Color(0xFF6FCF97)),
            title: Text(
              'Create "${_franchiseSearchController.text.trim()}" as new group',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () {
              final name = _franchiseSearchController.text.trim();
              setState(() {
                _franchiseId = '';
                _franchiseName = name;
                _franchiseResults = [];
              });
            },
          ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────
  Widget _input(
    String hint,
    TextEditingController controller, {
    void Function(String)? onChanged,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _stepItem(String num, String text, bool active) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? const Color(0xFF6FCF97) : Colors.grey,
          child: Text(num, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF6FCF97) : Colors.black,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
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
