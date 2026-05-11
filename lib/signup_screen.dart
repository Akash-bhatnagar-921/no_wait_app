import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:no_wait_app/services/api_service.dart';
import '../widgets/loading_widget.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String selectedGender = "Male";
  bool isChecked = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔙 BACK
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 10),

                  // ✂️ LOGO
                  Center(
                    child: Image.asset(
                      "assets/logo.png", // 👈 apna scissor-comb image yahan daal
                      height: 60,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // TITLE
                  const Center(
                    child: Text(
                      "Sign up",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Center(
                    child: Text(
                      "Create your account to get started",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 25),

                  _inputField(Icons.person, "Full Name", nameController),
                  _inputField(Icons.phone, "Mobile Number", phoneController),
                  _inputField(Icons.email, "Gmail ID", emailController),
                  _inputField(Icons.cake, "Age", ageController),

                  const SizedBox(height: 20),

                  const Text(
                    "Gender",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _genderBox("Male", Icons.male),
                      _genderBox("Female", Icons.female),
                      _genderBox("Other", Icons.more_horiz),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            isChecked = val!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "I agree to the Terms & Conditions and Privacy Policy",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🔥 BUTTON
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
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        final email = emailController.text.trim();
                        final age = ageController.text.trim();
                        final parsedAge = int.tryParse(age);

                        print("Name:" + name);

                        // 🔥 BASIC VALIDATION
                        if (name.isEmpty ||
                            phone.isEmpty ||
                            email.isEmpty ||
                            age.isEmpty ||
                            !isChecked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill all fields"),
                            ),
                          );
                          return;
                        }

                        if (parsedAge == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please enter a valid age"),
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const LoadingWidget(),
                        );

                        try {
                          print("Calling REGISTER API...");

                          final res = await ApiService.register(
                            phone: phone,
                            role: "customer",
                            name: name,
                            email: email,
                            age: parsedAge,
                            gender: selectedGender,
                          );
                          print("Response: $res");
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop();

                          // 🔥 SAVE TOKEN
                          await ApiService.saveToken(res['access_token']);

                          if (!context.mounted) return;

                          // 👉 NEXT SCREEN
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Signup successful ✅"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          // 🔥 loader band
                        } catch (e) {
                          print("ERROR: $e");
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop();

                          final message = e is ApiException
                              ? e.message
                              : "Something went wrong";

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(child: Text(message)),
                                ],
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: const Text("Continue"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(
                          color: Color(0xFF6FCF97),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 INPUT FIELD
  Widget _inputField(
    IconData icon,
    String hint,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color(0xFF6FCF97)),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  // 🔥 GENDER BOX
  Widget _genderBox(String gender, IconData icon) {
    final isSelected = selectedGender == gender;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedGender = gender;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6FCF97).withOpacity(0.2)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6FCF97) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF6FCF97) : Colors.black,
              ),
              const SizedBox(height: 5),
              Text(
                gender,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6FCF97) : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
