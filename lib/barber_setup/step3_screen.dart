import 'package:flutter/material.dart';
import 'package:no_wait_app/home_screen.dart';
import 'models/salon_onboarding_model.dart';
import 'package:no_wait_app/services/api_service.dart';

class Step3Screen extends StatefulWidget {
  final SalonOnboardingModel salonData;

  const Step3Screen({super.key, required this.salonData});

  @override
  State<Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends State<Step3Screen> {
  @override
  void initState() {
    super.initState();

    if (widget.salonData.barbers.isNotEmpty) {
      barbers = widget.salonData.barbers;
    }
  }

  List<Map<String, dynamic>> barbers = [
    {"name": "", "experience": ""},
  ];

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

  // 🔥 MAIN FORM
  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Barbers in Your Salon",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 5),

        const Text(
          "Add all barbers working in your salon",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 20),

        /// 🔥 NUMBER OF BARBERS CONTROL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: Color(0xFF6FCF97)),

              const SizedBox(width: 10),

              const Expanded(child: Text("Number of Barbers")),

              /// ➖
              IconButton(
                splashRadius: 20,
                onPressed: () {
                  if (barbers.length > 1) {
                    setState(() {
                      barbers.removeLast();
                    });
                  }
                },
                icon: const Icon(Icons.remove),
              ),

              /// COUNT
              Text(
                "${barbers.length}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              /// ➕
              IconButton(
                splashRadius: 20,
                onPressed: () {
                  setState(() {
                    barbers.add({"name": "", "experience": ""});
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        /// 🔥 BARBER LIST
        ...List.generate(barbers.length, (index) {
          return _barberCard(index);
        }),

        const SizedBox(height: 30),

        /// 🔥 BUTTONS
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6FCF97),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    widget.salonData.barbers = barbers;

                    try {
                      print("CALLING CREATE SALON API");

                      final res = await ApiService.createSalon(
                        salonData: widget.salonData,
                      );

                      print(res);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Salon Created ✅")),
                      );

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    } catch (e) {
                      print(e);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Failed to create salon ❌"),
                        ),
                      );
                    }
                  },
                  child: const Text("Finish"),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔥 BARBER CARD
  Widget _barberCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),

              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Barber Name",
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    barbers[index]["name"] = val;
                  },
                ),
              ),

              /// 🗑 DELETE
              if (barbers.length > 1)
                IconButton(
                  splashRadius: 20,
                  onPressed: () {
                    setState(() {
                      barbers.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Years of Experience",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) {
              barbers[index]["experience"] = val;
            },
          ),
        ],
      ),
    );
  }

  // 🔥 STEP INDICATOR
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

  // 🔥 SECURE CARD
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
