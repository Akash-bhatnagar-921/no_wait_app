import 'package:flutter/material.dart';

class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final filtered = _query.isEmpty
        ? _sections
        : _sections
            .map((s) => _Section(
                  s.title,
                  s.items
                      .where((i) =>
                          i.q.toLowerCase().contains(_query) ||
                          i.a.toLowerCase().contains(_query))
                      .toList(),
                ))
            .where((s) => s.items.isNotEmpty)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(isTablet ? 40 : 16, 12, isTablet ? 40 : 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Search questions…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary.withValues(alpha: 0.5))),
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No results for "$_query"',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                        isTablet ? 40 : 16, 4, isTablet ? 40 : 16, 24),
                    children: [
                      for (final section in filtered) ...[
                        _SectionHeader(title: section.title),
                        ...section.items.map((item) => _FaqTile(item: item)),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      _ContactCard(primary: primary),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem(this.q, this.a);
}

class _Section {
  final String title;
  final List<_FaqItem> items;
  const _Section(this.title, this.items);
}

const _sections = [
  _Section('Getting Started', [
    _FaqItem(
      'How do I create an account?',
      'Tap "Continue as Customer" on the home screen, enter your phone number, and verify the OTP sent to your mobile. Fill in your name and email to complete registration.',
    ),
    _FaqItem(
      'How do I find salons near me?',
      'From the home screen, tap the Location card to set your area, pick a date, then tap "Find Salons". Baari will show you approved salons within 5 km of your chosen location.',
    ),
    _FaqItem(
      'Is Baari available in my city?',
      'Baari is currently expanding across India. If no salons appear in your area, new salons are being added regularly. Check back soon or try a nearby locality.',
    ),
  ]),
  _Section('Bookings', [
    _FaqItem(
      'How do I book an appointment?',
      'Find a salon → tap its card → select the services you want → tap "Choose Time Slot" → pick a date and available time → review the summary and tap "Confirm Booking".',
    ),
    _FaqItem(
      'Can I book multiple services in one appointment?',
      'Yes! Select as many services as you like. The total amount and estimated duration are shown before you confirm.',
    ),
    _FaqItem(
      'Can I modify my booking after confirming?',
      'You can change the selected services up to 20 minutes before your appointment time. Open the booking in "My Bookings" → "Modify Services". Time slots cannot be changed after booking.',
    ),
    _FaqItem(
      'How do I cancel a booking?',
      'Go to My Bookings → tap the booking → tap "Cancel Booking". Cancellations are allowed up to 20 minutes before the appointment time.',
    ),
    _FaqItem(
      'Why can\'t I cancel or modify my booking?',
      'The 20-minute cutoff has passed. Once you\'re within 20 minutes of your appointment, modifications and cancellations are no longer available.',
    ),
    _FaqItem(
      'How many bookings can I make on the Free plan?',
      'The Free plan allows up to 2 bookings per calendar month. Upgrade to Basic or Pro for unlimited bookings.',
    ),
    _FaqItem(
      'Will I get a reminder before my appointment?',
      'Yes. Open the "My Bookings" tab when your appointment is approaching — a reminder banner appears 30 minutes before your slot.',
    ),
  ]),
  _Section('Payments & Pricing', [
    _FaqItem(
      'How does payment work?',
      'Baari currently uses a demo payment flow — no real transactions occur. Pay at the salon after your service. We will introduce online payments in a future update.',
    ),
    _FaqItem(
      'Are the prices shown final?',
      'Prices displayed are set by the salon and are indicative. The final amount may vary slightly based on the salon\'s current rate card.',
    ),
    _FaqItem(
      'What is included in the Basic plan (₹99/month)?',
      'Basic gives you unlimited bookings, priority slot access, booking reminders, and email support — ideal for regular salon visitors.',
    ),
    _FaqItem(
      'What extra benefits does the Pro plan (₹199/month) offer?',
      'Pro includes everything in Basic plus exclusive salon deals, loyalty reward points, dedicated Baari support, and early access to new features.',
    ),
    _FaqItem(
      'What happens when my subscription expires?',
      'Your plan automatically reverts to Free at the end of the billing period. You can renew anytime from the Subscriptions screen.',
    ),
  ]),
  _Section('Salons & Reviews', [
    _FaqItem(
      'How do I rate a salon?',
      'After your appointment, go to My Bookings → Past → tap the booking → tap "Rate & Review". Give 1–5 stars and optionally leave a comment.',
    ),
    _FaqItem(
      'Can I edit my review?',
      'Yes. Submit a new review for the same salon — it overwrites your previous rating and comment.',
    ),
    _FaqItem(
      'Why is a salon I visited not showing in search?',
      'Salons must be approved by the Baari team and have at least one priced service to appear in search. The salon may also have marked itself as "Closed" for the day.',
    ),
    _FaqItem(
      'How do I save a salon for later?',
      'Tap the heart icon on any salon card to add it to your Wishlist. View saved salons from the drawer menu → Wishlist.',
    ),
  ]),
  _Section('Account & Privacy', [
    _FaqItem(
      'How do I log out?',
      'Go to Settings → Account Actions → Logout, or use the Logout option in My Profile.',
    ),
    _FaqItem(
      'How do I delete my account?',
      'Go to Settings → Account Actions → Delete Account. This is permanent and removes all your data immediately.',
    ),
    _FaqItem(
      'Is my personal data safe?',
      'Baari uses industry-standard encryption for all data in transit. We never share your personal information with third parties without consent.',
    ),
    _FaqItem(
      'How do I update my name or email?',
      'Tap the edit (pencil) icon next to your name in My Profile to update your display name.',
    ),
  ]),
  _Section('For Professionals', [
    _FaqItem(
      'How do I register my salon on Baari?',
      'Tap "Join as Professional" on the welcome screen and complete the salon registration form. Your salon will go live after Baari team approval (within 24 hours).',
    ),
    _FaqItem(
      'How do I set up services and pricing?',
      'In your professional dashboard → Profile tab → tap "Configure Services & Pricing". Enable services, add prices and durations, then save.',
    ),
    _FaqItem(
      'How do I mark my salon as open or closed for the day?',
      'On your dashboard home, use the Open/Closed toggle in the salon info card.',
    ),
    _FaqItem(
      'How do I update my salon\'s location?',
      'Go to Profile tab → Location row → tap Add/Update → pick your location on the map → Save. The update goes live after Baari admin approval.',
    ),
    _FaqItem(
      'Where can I see customer appointments?',
      'Tap "Appointments" in the bottom navigation bar of your professional dashboard.',
    ),
  ]),
];

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primary,
                letterSpacing: 0.3)),
      ]),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _expanded ? primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? primary.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(widget.item.q,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _expanded ? primary : Colors.black87)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20,
                        color: _expanded ? primary : Colors.grey.shade500),
                  ),
                ]),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: primary.withValues(alpha: 0.15)),
                  const SizedBox(height: 10),
                  Text(widget.item.a,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.55)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Color primary;
  const _ContactCard({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.headset_mic_outlined, color: primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Still need help?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: primary, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Contact our support team at +91-9999999999 or email support@baari.app. We\'re available Mon–Sat, 9 AM – 6 PM.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
            ),
          ]),
        ),
      ]),
    );
  }
}
