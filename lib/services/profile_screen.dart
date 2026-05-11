import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import 'package:no_wait_app/services/api_service.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? user;

  bool isLoading = true;

  Future<void> fetchProfile() async {
    try {
      print("callig Get Profile API");
      final res = await ApiService.getProfile();

      if (res == null) {
        print("TOKEN NULL");
        setState(() {
          isLoading = false;
        });

        return;
      }

      setState(() {
        user = res;
        isLoading = false;
      });
      print("APi finished");
    } catch (e) {
      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    String formattedDate = user?.createdAt != null
        ? DateFormat("dd MMM yyyy").format(DateTime.parse(user!.createdAt!))
        : "No date";
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        centerTitle: true,
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// TOP CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FAF7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// DEFAULT ICON
                  Container(
                    height: 85,
                    width: 85,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF1B8A4B),
                    ),
                  ),

                  const SizedBox(width: 18),

                  /// RIGHT SECTION
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// NAME + EDIT
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                user?.fullName ?? '',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B3B2E),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: () {
                                showEditNameDialog(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF34A853),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Color(0xFF34A853),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        /// ROLE
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5E8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.role ?? '',
                            style: TextStyle(
                              color: Color(0xFF1B8A4B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        /// PHONE
                        Row(
                          children: [
                            Icon(
                              Icons.call_outlined,
                              size: 20,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 10),
                            Text(
                              user?.phone ?? '',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// EMAIL
                        Row(
                          children: [
                            Icon(
                              Icons.mail_outline,
                              size: 20,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                user?.email ?? '',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// PERSONAL INFO CARD
            profileCard(
              title: "Personal Information",
              children: [
                profileTile(
                  Icons.person_outline,
                  "Full Name",
                  user?.fullName ?? '',
                ),

                profileTile(
                  Icons.call_outlined,
                  "Phone Number",
                  user?.phone ?? '',
                ),

                profileTile(
                  Icons.mail_outline,
                  "Email Address",
                  user?.email ?? '',
                ),

                // String createdAt = "2026-05-05T17:18:33.410Z";
                profileTile(
                  Icons.calendar_today_outlined,
                  "Member Since",
                  formattedDate,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// ACCOUNT CARD
            profileCard(
              title: "Account",
              children: [
                settingsTile(Icons.lock_outline, "Change Password"),

                settingsTile(
                  Icons.logout,
                  "Logout",
                  color: Colors.red,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// SECURITY BOX
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FBF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Color(0xFF1B8A4B)),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      "Your data is safe and secure with us.",
                      style: TextStyle(
                        color: Color(0xFF1B8A4B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CARD
  static Widget profileCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          ...children,
        ],
      ),
    );
  }

  /// PROFILE TILE
  static Widget profileTile(
    IconData icon,
    String title,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),

          const SizedBox(width: 16),

          Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),

          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// SETTINGS TILE
  static Widget settingsTile(
    IconData icon,
    String title, {
    Color color = Colors.black,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),

          const SizedBox(width: 16),

          Expanded(
            child: Text(title, style: TextStyle(fontSize: 17, color: color)),
          ),

          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }

  /// EDIT NAME DIALOG
  static void showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: "Rohit Sharma");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Update Name",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Enter new name",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34A853),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
