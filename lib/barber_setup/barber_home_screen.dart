import 'package:flutter/material.dart';

class ProfessionalHomeScreen extends StatelessWidget {
  const ProfessionalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Appointments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_rupee),
            label: "Earnings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TOP BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),

                  Column(
                    children: const [
                      Text(
                        "No Wait",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Professional",
                        style: TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ],
                  ),

                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              /// WELCOME
              const Text(
                "Welcome,",
                style: TextStyle(fontSize: 20, color: Colors.black54),
              ),

              const SizedBox(height: 10),

              Row(
                children: const [
                  Text(
                    "YTR Salon",
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(width: 10),

                  Icon(Icons.verified, color: Colors.green),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                "Manage your salon professionally.",
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),

              const SizedBox(height: 30),

              /// SALON CARD
              Container(
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(24),
                ),

                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: const Icon(
                        Icons.storefront,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),

                    const SizedBox(width: 16),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "YTR Salon",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 6),

                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),

                              SizedBox(width: 5),

                              Text(
                                "MG Road, Bangalore",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),

                          SizedBox(height: 5),

                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),

                              SizedBox(width: 5),

                              Text(
                                "9876543210",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                      ),

                      onPressed: () {},

                      child: const Text("View"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// OVERVIEW
              const Text(
                "Today's Overview",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              isTablet
                  /// TABLET
                  ? SizedBox(
                      height: 170,

                      child: ListView(
                        scrollDirection: Axis.horizontal,

                        children: [
                          SizedBox(
                            width: 180,

                            child: overviewCard(
                              icon: Icons.calendar_month,
                              title: "Appointments",
                              value: "4",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: overviewCard(
                              icon: Icons.people_outline,
                              title: "Clients",
                              value: "12",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: overviewCard(
                              icon: Icons.currency_rupee,
                              title: "Earnings",
                              value: "₹3240",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: overviewCard(
                              icon: Icons.star_outline,
                              title: "Reviews",
                              value: "4.8",
                            ),
                          ),
                        ],
                      ),
                    )
                  /// MOBILE
                  : GridView.count(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      crossAxisCount: isTablet ? 4 : 2,

                      mainAxisSpacing: 15,

                      crossAxisSpacing: 15,

                      childAspectRatio: isTablet ? 1.1 : 1.2,

                      children: [
                        overviewCard(
                          icon: Icons.calendar_month,
                          title: "Appointments",
                          value: "4",
                        ),

                        overviewCard(
                          icon: Icons.people_outline,
                          title: "Clients",
                          value: "12",
                        ),

                        overviewCard(
                          icon: Icons.currency_rupee,
                          title: "Earnings",
                          value: "₹3240",
                        ),

                        overviewCard(
                          icon: Icons.star_outline,
                          title: "Reviews",
                          value: "4.8",
                        ),
                      ],
                    ),

              const SizedBox(height: 35),

              /// QUICK ACTIONS
              const Text(
                "Quick Actions",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              isTablet
                  /// TABLET
                  ? SizedBox(
                      height: 160,

                      child: ListView(
                        scrollDirection: Axis.horizontal,

                        children: [
                          SizedBox(
                            width: 180,

                            child: actionCard(
                              icon: Icons.calendar_today,
                              title: "Appointments",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: actionCard(
                              icon: Icons.people_alt_outlined,
                              title: "Manage Barbers",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: actionCard(
                              icon: Icons.content_cut,
                              title: "Services",
                            ),
                          ),

                          const SizedBox(width: 15),

                          SizedBox(
                            width: 180,

                            child: actionCard(
                              icon: Icons.settings_outlined,
                              title: "Settings",
                            ),
                          ),
                        ],
                      ),
                    )
                  /// MOBILE
                  : GridView.count(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      crossAxisCount: isTablet ? 4 : 2,

                      mainAxisSpacing: 15,

                      crossAxisSpacing: 15,

                      childAspectRatio: isTablet ? 1.1 : 1.2,

                      children: [
                        actionCard(
                          icon: Icons.calendar_today,
                          title: "Appointments",
                        ),

                        actionCard(
                          icon: Icons.people_alt_outlined,
                          title: "Manage Barbers",
                        ),

                        actionCard(icon: Icons.content_cut, title: "Services"),

                        actionCard(
                          icon: Icons.settings_outlined,
                          title: "Settings",
                        ),
                      ],
                    ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, color: Colors.green, size: 34),

          const SizedBox(height: 12),

          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget actionCard({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, color: Colors.green, size: 34),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
