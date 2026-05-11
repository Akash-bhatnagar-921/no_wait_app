import 'package:flutter/material.dart';
import 'step2_screen.dart';
import 'models/salon_onboarding_model.dart';

class Step1Screen extends StatefulWidget {
  const Step1Screen({super.key});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  final salonData = SalonOnboardingModel();
  // const Step1Screen({super.key});
  final salonNameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();
  final stateController = TextEditingController();
  final landmarkController = TextEditingController();
  final contactController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    salonNameController.text = salonData.salonName;
    addressController.text = salonData.address;
    cityController.text = salonData.city;
    pincodeController.text = salonData.pincode;
    stateController.text = salonData.state;
    landmarkController.text = salonData.landmark;
    contactController.text = salonData.contactNumber;
    emailController.text = salonData.shopEmail;
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

  // 📱 MOBILE
  Widget _mobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔥 LOGO
          Center(child: Image.asset("assets/logo.png", height: 50)),

          const SizedBox(height: 15),

          /// 🔥 TITLE
          const Center(
            child: Column(
              children: [
                Text("Join as", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "Professional",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          /// 🔥 STEP INDICATOR
          _mobileStepIndicator(1),

          const SizedBox(height: 25),

          /// 🔥 FORM
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
      child: Text(
        "$num",
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  // 📟 TABLET
  Widget _tabletLayout(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Row(
          children: [
            /// 🔥 LEFT SIDEBAR
            Container(
              width: 180,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Image.asset("assets/logo.png", height: 40),

                  const SizedBox(height: 20),

                  const Text(
                    "Join as",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Professional",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  /// 🔥 STEPS (STRETCH AREA)
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

                  /// 🔥 BOTTOM FIXED
                  _secureCard(),
                ],
              ),
            ),

            /// RIGHT FORM
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

  // 🔥 FORM
  Widget _form(BuildContext context) {
    // final salonNameController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Salon / Shop Details",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        _input("Shop / Salon Name", salonNameController),
        _input("Address", addressController),

        /// RESPONSIVE CITY + PINCODE
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 400) {
              return Column(
                children: [
                  _input("City", cityController),
                  _input("Pincode", pincodeController),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: _input("City", cityController)),
                  const SizedBox(width: 10),
                  Expanded(child: _input("Pincode", pincodeController)),
                ],
              );
            }
          },
        ),

        _input("State", stateController),
        _input("Landmark (Optional)", landmarkController),
        _input("Contact Number", contactController),
        _input("Shop Email (Optional)", emailController),

        const SizedBox(height: 20),

        const Text("Shop Images"),

        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          children: List.generate(
            5,
            (index) => Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: index == 0 ? const Icon(Icons.add_a_photo) : null,
            ),
          ),
        ),

        const SizedBox(height: 30),

        /// BIG BUTTON
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
              // final salonData = SalonOnboardingModel();

              salonData.salonName = salonNameController.text;
              salonData.address = addressController.text;
              salonData.city = cityController.text;
              salonData.pincode = pincodeController.text;
              salonData.state = stateController.text;
              salonData.landmark = landmarkController.text;
              salonData.contactNumber = contactController.text;
              salonData.shopEmail = emailController.text;

              print(salonData.salonName);
              print(salonData.address);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Step2Screen(salonData: salonData),
                ),
              );
            },
            child: const Text("Next"),
          ),
        ),
      ],
    );
  }

  // 🔥 INPUT
  Widget _input(String hint, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
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

  // 🔥 STEP ITEM WITH HIGHLIGHT
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

  // 🔥 BOTTOM CARD
  Widget _secureCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6FCF97).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "Secure & Trusted\nYour data is safe with us.",
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
