import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'step2_screen.dart';
import 'models/salon_onboarding_model.dart';
import 'package:no_wait_app/services/api_service.dart';

// ── Indian states & cities ────────────────────────────────────────────────────

const Map<String, List<String>> _kStateCities = {
  'Andhra Pradesh': ['Visakhapatnam','Vijayawada','Guntur','Nellore','Kurnool','Tirupati','Kakinada','Rajahmundry','Kadapa','Anantapur'],
  'Arunachal Pradesh': ['Itanagar','Naharlagun','Pasighat','Tawang'],
  'Assam': ['Guwahati','Silchar','Dibrugarh','Jorhat','Nagaon','Tinsukia','Tezpur'],
  'Bihar': ['Patna','Gaya','Bhagalpur','Muzaffarpur','Darbhanga','Purnia','Arrah','Bihar Sharif'],
  'Chhattisgarh': ['Raipur','Bhilai','Bilaspur','Durg','Korba','Rajnandgaon','Raigarh'],
  'Goa': ['Panaji','Margao','Vasco da Gama','Mapusa','Ponda','Bicholim'],
  'Gujarat': ['Ahmedabad','Surat','Vadodara','Rajkot','Bhavnagar','Jamnagar','Gandhinagar','Anand','Gandhidham','Junagadh','Mehsana'],
  'Haryana': ['Faridabad','Gurugram','Panipat','Ambala','Yamunanagar','Rohtak','Hisar','Karnal','Sonipat','Panchkula'],
  'Himachal Pradesh': ['Shimla','Dharamsala','Solan','Mandi','Kullu','Manali','Hamirpur','Una'],
  'Jharkhand': ['Ranchi','Jamshedpur','Dhanbad','Bokaro','Deoghar','Hazaribagh','Giridih'],
  'Karnataka': ['Bengaluru','Mysuru','Mangaluru','Hubballi','Dharwad','Belagavi','Kalaburagi','Tumakuru','Davangere','Shivamogga'],
  'Kerala': ['Thiruvananthapuram','Kochi','Kozhikode','Thrissur','Kollam','Malappuram','Kannur','Kottayam','Alappuzha'],
  'Madhya Pradesh': ['Bhopal','Indore','Jabalpur','Gwalior','Ujjain','Sagar','Dewas','Rewa','Satna','Ratlam'],
  'Maharashtra': ['Mumbai','Pune','Nagpur','Thane','Nashik','Aurangabad','Solapur','Kolhapur','Navi Mumbai','Pimpri-Chinchwad','Amravati','Nanded'],
  'Manipur': ['Imphal','Thoubal','Bishnupur','Churachandpur'],
  'Meghalaya': ['Shillong','Tura','Jowai','Nongpoh'],
  'Mizoram': ['Aizawl','Lunglei','Champhai','Serchhip'],
  'Nagaland': ['Kohima','Dimapur','Mokokchung','Tuensang'],
  'Odisha': ['Bhubaneswar','Cuttack','Rourkela','Brahmapur','Sambalpur','Puri','Balasore','Bargarh'],
  'Punjab': ['Ludhiana','Amritsar','Jalandhar','Patiala','Bathinda','Mohali','Pathankot','Hoshiarpur'],
  'Rajasthan': ['Jaipur','Jodhpur','Kota','Bikaner','Ajmer','Udaipur','Alwar','Bhilwara','Sikar','Sri Ganganagar'],
  'Sikkim': ['Gangtok','Namchi','Gyalshing','Mangan'],
  'Tamil Nadu': ['Chennai','Coimbatore','Madurai','Tiruchirappalli','Salem','Tirunelveli','Tirupur','Vellore','Erode','Thoothukudi'],
  'Telangana': ['Hyderabad','Warangal','Nizamabad','Karimnagar','Khammam','Secunderabad','Ramagundam'],
  'Tripura': ['Agartala','Udaipur','Dharmanagar','Ambassa'],
  'Uttar Pradesh': ['Lucknow','Kanpur','Agra','Varanasi','Meerut','Prayagraj','Ghaziabad','Noida','Bareilly','Aligarh','Moradabad','Gorakhpur','Mathura'],
  'Uttarakhand': ['Dehradun','Haridwar','Roorkee','Haldwani','Rudrapur','Rishikesh','Nainital','Kashipur'],
  'West Bengal': ['Kolkata','Howrah','Asansol','Siliguri','Durgapur','Bardhaman','Malda','Kharagpur'],
  // Union Territories
  'Andaman & Nicobar Islands': ['Port Blair'],
  'Chandigarh': ['Chandigarh'],
  'Dadra & Nagar Haveli': ['Silvassa'],
  'Daman & Diu': ['Daman','Diu'],
  'Delhi': ['New Delhi','Delhi','Dwarka','Rohini','Janakpuri','Lajpat Nagar'],
  'Jammu & Kashmir': ['Srinagar','Jammu','Anantnag','Baramulla','Sopore'],
  'Ladakh': ['Leh','Kargil'],
  'Lakshadweep': ['Kavaratti'],
  'Puducherry': ['Puducherry','Karaikal','Mahe','Yanam'],
};

// ── Input formatters ──────────────────────────────────────────────────────────

/// Allows only letters and spaces — no numbers, no special characters.
final _nameFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[a-zA-Z\s]'),
);

/// Digits only — for phone, pincode.
final _digitsOnly = FilteringTextInputFormatter.digitsOnly;

// ─────────────────────────────────────────────────────────────────────────────

class Step1Screen extends StatefulWidget {
  const Step1Screen({super.key});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  final _formKey = GlobalKey<FormState>();
  final salonData = SalonOnboardingModel();

  final salonNameController  = TextEditingController();
  final addressController    = TextEditingController();
  final pincodeController    = TextEditingController();
  final landmarkController   = TextEditingController();
  final contactController    = TextEditingController();
  final emailController      = TextEditingController();
  final ownerNameController  = TextEditingController();
  final ownerPhoneController = TextEditingController();

  // State / city dropdowns
  String? _selectedState;
  String? _selectedCity;

  // Franchise
  bool _isFranchise = false;
  String _franchiseId   = '';
  String _franchiseName = '';
  final _franchiseSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _franchiseResults = [];
  bool _searchingFranchise = false;

  bool _isCheckingPhone = false;

  List<String> get _citiesForState =>
      _selectedState != null ? (_kStateCities[_selectedState!] ?? []) : [];

  @override
  void dispose() {
    salonNameController.dispose();
    addressController.dispose();
    pincodeController.dispose();
    landmarkController.dispose();
    contactController.dispose();
    emailController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    _franchiseSearchCtrl.dispose();
    super.dispose();
  }

  // ── Franchise search ───────────────────────────────────────────────────────

  Future<void> _searchFranchise(String query) async {
    if (query.trim().isEmpty) { setState(() => _franchiseResults = []); return; }
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
      if (mounted) setState(() => _searchingFranchise = false);
    }
  }

  // ── Next ──────────────────────────────────────────────────────────────────

  Future<void> _onNext() async {
    // Trigger all inline validators
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final snack = ScaffoldMessenger.of(context);

    if (_isFranchise && _franchiseId.isEmpty && _franchiseName.isEmpty) {
      snack.showSnackBar(const SnackBar(
          content: Text('Select a franchise or type a new franchise name.')));
      return;
    }

    // Check salon phone uniqueness
    setState(() => _isCheckingPhone = true);
    try {
      final res = await ApiService.checkPhone(contactController.text.trim());
      if (res['exists'] == true) {
        if (!mounted) return;
        snack.showSnackBar(const SnackBar(
            content: Text('This phone is already registered. Please login.')));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      snack.showSnackBar(const SnackBar(content: Text('Could not verify phone. Try again.')));
      return;
    } finally {
      if (mounted) setState(() => _isCheckingPhone = false);
    }

    // Persist to model
    salonData
      ..salonName     = salonNameController.text.trim()
      ..address       = addressController.text.trim()
      ..city          = _selectedCity ?? ''
      ..state         = _selectedState ?? ''
      ..pincode       = pincodeController.text.trim()
      ..landmark      = landmarkController.text.trim()
      ..contactNumber = contactController.text.trim()
      ..shopEmail     = emailController.text.trim()
      ..ownerName     = ownerNameController.text.trim()
      ..ownerPhone    = ownerPhoneController.text.trim()
      ..isFranchise   = _isFranchise
      ..franchiseId   = _franchiseId
      ..franchiseName = _franchiseName;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Step2Screen(salonData: salonData)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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

  // ── Mobile ─────────────────────────────────────────────────────────────────

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
        final active  = stepNum == 1;
        final done    = stepNum < 1;
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

  // ── Tablet ─────────────────────────────────────────────────────────────────

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
                        _tabletStepItem("1", "Salon Details", active: true),
                        const SizedBox(height: 52),
                        _tabletStepItem("2", "Services", active: false),
                        const SizedBox(height: 52),
                        _tabletStepItem("3", "Barbers", active: false),
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

  // ── Form body ──────────────────────────────────────────────────────────────

  Widget _formBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Step heading ─────────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6FCF97).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Step 1 of 3',
              style: TextStyle(
                color: Color(0xFF2D9248),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Text("Salon / Shop Details",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Tell us about your salon so customers can find you.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),

        const SizedBox(height: 24),

        // ── Salon name ────────────────────────────────────────────────────
        _fieldLabel("Shop / Salon Name", required: true),
        _buildField(
          controller: salonNameController,
          hint: 'e.g. Raj Gents Parlour',
          inputFormatters: [_nameFormatter, LengthLimitingTextInputFormatter(100)],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Salon name is required';
            if (v.trim().length < 2) return 'Must be at least 2 characters';
            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
              return 'Only alphabets are allowed';
            }
            return null;
          },
        ),

        // ── Address ───────────────────────────────────────────────────────
        _fieldLabel("Address", required: true),
        _buildField(
          controller: addressController,
          hint: 'Shop number, street, area',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Address is required' : null,
        ),

        // ── State ─────────────────────────────────────────────────────────
        _fieldLabel("State", required: true),
        _stateDropdown(),

        // ── City ──────────────────────────────────────────────────────────
        _fieldLabel("City", required: true),
        _cityDropdown(),

        // ── Pincode ───────────────────────────────────────────────────────
        _fieldLabel("Pincode", required: true),
        _buildField(
          controller: pincodeController,
          hint: '6-digit pincode',
          keyboardType: TextInputType.number,
          inputFormatters: [_digitsOnly, LengthLimitingTextInputFormatter(6)],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Pincode is required';
            if (v.length != 6) return 'Pincode must be exactly 6 digits';
            return null;
          },
        ),

        // ── Landmark ─────────────────────────────────────────────────────
        _fieldLabel("Landmark (Optional)"),
        _buildField(
          controller: landmarkController,
          hint: 'Near school, mall, metro…',
        ),

        // ── Salon phone ───────────────────────────────────────────────────
        _fieldLabel("Salon Phone Number (Login / OTP)", required: true),
        _buildField(
          controller: contactController,
          hint: '10-digit mobile number',
          keyboardType: TextInputType.phone,
          inputFormatters: [_digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Salon phone is required';
            if (v.length != 10) return 'Must be a 10-digit number';
            return null;
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, top: 2),
          child: Text(
            'This number is used to log in to the Baari professional app.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ),

        // ── Email ─────────────────────────────────────────────────────────
        _fieldLabel("Shop Email (Optional)"),
        _buildField(
          controller: emailController,
          hint: 'shop@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null; // optional
            final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
            if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
            return null;
          },
        ),

        // ── Business Owner ────────────────────────────────────────────────
        const Divider(height: 32),
        const Text("Business Owner",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          "The person who owns this salon. One owner can register multiple salons.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 14),

        _fieldLabel("Owner Full Name", required: true),
        _buildField(
          controller: ownerNameController,
          hint: 'Full name',
          inputFormatters: [_nameFormatter, LengthLimitingTextInputFormatter(80)],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Owner name is required';
            if (v.trim().length < 2) return 'Name must be at least 2 characters';
            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
              return 'Only alphabets are allowed';
            }
            return null;
          },
        ),

        _fieldLabel("Owner Phone Number (Optional)"),
        _buildField(
          controller: ownerPhoneController,
          hint: '10-digit mobile (optional)',
          keyboardType: TextInputType.phone,
          inputFormatters: [_digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            if (v.length != 10) return 'Must be a 10-digit number';
            return null;
          },
        ),

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
                  "Owner phone is for records only — not used for app login.",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),

        // ── Franchise ─────────────────────────────────────────────────────
        const Divider(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _isFranchise,
          title: const Text(
            "Is this salon part of a franchise?",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          activeColor: const Color(0xFF6FCF97),
          onChanged: (val) {
            setState(() {
              _isFranchise = val ?? false;
              if (!_isFranchise) {
                _franchiseId = '';
                _franchiseName = '';
                _franchiseSearchCtrl.clear();
                _franchiseResults = [];
              }
            });
          },
        ),

        if (_isFranchise) ...[
          const SizedBox(height: 8),
          _franchiseSection(),
        ],

        const SizedBox(height: 32),

        // ── Next ─────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6FCF97),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor:
                  const Color(0xFF6FCF97).withValues(alpha: 0.5),
            ),
            onPressed: _isCheckingPhone ? null : _onNext,
            child: _isCheckingPhone
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("Next →",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
          children: [
            TextSpan(text: label),
            if (required)
              const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines ?? 1,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF6FCF97), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          errorStyle:
              const TextStyle(color: Colors.red, fontSize: 11, height: 1.2),
        ),
      ),
    );
  }

  Widget _stateDropdown() {
    final states = List<String>.from(_kStateCities.keys)..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        isExpanded: true,
        hint: Text('Select state',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        items: states
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: (val) {
          setState(() {
            _selectedState = val;
            _selectedCity  = null; // reset city when state changes
          });
        },
        validator: (v) => v == null ? 'Please select a state' : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: _dropdownDecoration(),
      ),
    );
  }

  Widget _cityDropdown() {
    final cities = List<String>.from(_citiesForState)..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCity,
        isExpanded: true,
        hint: Text(
          _selectedState == null
              ? 'Select state first'
              : 'Select city',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
        items: cities
            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: _selectedState == null
            ? null
            : (val) => setState(() => _selectedCity = val),
        validator: (v) => v == null ? 'Please select a city' : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: _dropdownDecoration(),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6FCF97), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      errorStyle:
          const TextStyle(color: Colors.red, fontSize: 11, height: 1.2),
    );
  }

  Widget _franchiseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_franchiseId.isNotEmpty || _franchiseName.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    _franchiseSearchCtrl.clear();
                    _franchiseResults = [];
                  }),
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        TextField(
          controller: _franchiseSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search franchise group (e.g. Image Salon)',
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
                            _franchiseId   = f['id']   as String;
                            _franchiseName = f['name'] as String;
                            _franchiseSearchCtrl.text = f['name'] as String;
                            _franchiseResults = [];
                          });
                        },
                      ))
                  .toList(),
            ),
          )
        else if (_franchiseSearchCtrl.text.trim().isNotEmpty &&
            !_searchingFranchise)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline,
                color: Color(0xFF6FCF97)),
            title: Text(
              'Create "${_franchiseSearchCtrl.text.trim()}" as new group',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () {
              final name = _franchiseSearchCtrl.text.trim();
              setState(() {
                _franchiseId   = '';
                _franchiseName = name;
                _franchiseResults = [];
              });
            },
          ),
      ],
    );
  }

  Widget _tabletStepItem(String num, String text, {required bool active}) {
    const primary = Color(0xFF6FCF97);
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: active ? primary : Colors.grey.shade300,
          child: Text(num,
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
