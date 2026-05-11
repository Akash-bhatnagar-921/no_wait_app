import 'package:flutter/material.dart';
import 'step3_screen.dart';
import 'models/salon_onboarding_model.dart';

class Step2Screen extends StatefulWidget {
  final SalonOnboardingModel salonData;

  const Step2Screen({super.key, required this.salonData});

  @override
  State<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<Step2Screen> {
  final descController = TextEditingController();
  @override
  void initState() {
    super.initState();

    selectedServices = widget.salonData.services;
    selectedAmenities = widget.salonData.amenities;

    descController.text = widget.salonData.description;
  }

  List<String> selectedServices = [];
  List<String> selectedAmenities = [];

  final List<String> services = [
    "Haircut",
    "Beard Trim",
    "Shaving",
    "Facial",
    "Hair Color",
  ];

  final List<String> amenities = [
    "Air Conditioning",
    "Wi-Fi",
    "Parking",
    "Music",
    "Waiting Lounge",
  ];

  // final TextEditingController descController = TextEditingController();

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

  // 🔥 FORM CONTENT
  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _multiSelectField(
          title: "Select Services Offered",
          hint: "Select Services",
          options: services,
          selectedItems: selectedServices,
        ),

        const SizedBox(height: 25),

        _multiSelectField(
          title: "Select Amenities",
          hint: "Select Amenities",
          options: amenities,
          selectedItems: selectedAmenities,
        ),

        const SizedBox(height: 25),

        /// 🔥 ADDITIONAL INFO
        const Text(
          "Additional Information",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 5),

        const Text(
          "Shop Description (Optional)",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: descController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Tell customers about your salon...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 40),

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

                  onPressed: () {
                    widget.salonData.services = selectedServices;
                    widget.salonData.amenities = selectedAmenities;
                    widget.salonData.description = descController.text;

                    print(widget.salonData.services);
                    print(widget.salonData.amenities);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            Step3Screen(salonData: widget.salonData),
                      ),
                    );
                  },
                  child: const Text("Next"),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔥 MULTI SELECT FIELD
  Widget _multiSelectField({
    required String title,
    required String hint,
    required List<String> options,
    required List<String> selectedItems,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        const SizedBox(height: 5),

        const Text(
          "Choose all that apply",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: () => _openBottomSheet(options, selectedItems),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedItems.isEmpty
                      ? Text(hint, style: const TextStyle(color: Colors.grey))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: selectedItems
                              .map((e) => _chipInsideField(e, selectedItems))
                              .toList(),
                        ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 CHIP
  Widget _chipInsideField(String text, List<String> list) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6FCF97).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {
              setState(() {
                list.remove(text);
              });
            },
            child: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  // 🔥 BOTTOM SHEET
  void _openBottomSheet(List<String> options, List<String> selectedList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.75, // 🔥 LIMIT
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 🔥 CONTENT BASED HEIGHT
                  children: [
                    const Text(
                      "Select Options",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    /// 🔥 AUTO SCROLL ONLY IF NEEDED
                    Flexible(
                      child: ListView(
                        shrinkWrap: true, // 🔥 IMPORTANT
                        children: options.map((e) {
                          final isSelected = selectedList.contains(e);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isSelected,
                            title: Text(e),
                            onChanged: (_) {
                              setStateModal(() {
                                isSelected
                                    ? selectedList.remove(e)
                                    : selectedList.add(e);
                              });

                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔥 STEP ITEM
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
