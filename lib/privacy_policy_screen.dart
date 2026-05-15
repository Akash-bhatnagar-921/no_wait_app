import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _PolicyContent(),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last updated: May 2026',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),

        _section(
          'Introduction',
          'Welcome to Baari ("we", "our", "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.',
        ),

        _section(
          '1. Information We Collect',
          'We collect information you provide directly to us, such as:\n'
              '• Name and contact details (phone number, email address)\n'
              '• Location information when you use our services\n'
              '• Booking history and appointment preferences\n'
              '• Device information and usage data',
        ),

        _section(
          '2. How We Use Your Information',
          'We use the information we collect to:\n'
              '• Provide and improve our services\n'
              '• Process bookings and appointments\n'
              '• Send you notifications about your bookings\n'
              '• Communicate important updates and offers\n'
              '• Ensure platform security and prevent fraud',
        ),

        _section(
          '3. Sharing of Information',
          'We do not sell or rent your personal data. We may share your information only with:\n'
              '• Salon partners, to fulfill your booking requests\n'
              '• Service providers who assist us in operating the app\n'
              '• Authorities when required by law',
        ),

        _section(
          '4. Data Security',
          'We implement industry-standard security measures to protect your data. Your OTP codes are hashed and expire within 5 minutes. Professional login codes are encrypted using HMAC-SHA256.',
        ),

        _section(
          '5. Data Retention',
          'We retain your personal data only as long as necessary to provide our services or as required by law. You may request deletion of your account and associated data at any time by contacting support.',
        ),

        _section(
          '6. Your Rights',
          'You have the right to:\n'
              '• Access the personal data we hold about you\n'
              '• Request correction of inaccurate data\n'
              '• Request deletion of your data\n'
              '• Withdraw consent where applicable',
        ),

        _section(
          '7. Children\'s Privacy',
          'Our services are not directed to individuals under the age of 13. We do not knowingly collect personal information from children.',
        ),

        _section(
          '8. Changes to This Policy',
          'We may update this Privacy Policy from time to time. We will notify you of any significant changes through the app or via the contact information on file.',
        ),

        _section(
          '9. Contact Us',
          'If you have questions about this Privacy Policy or our data practices, please contact us:\n\n'
              'Baari Support\n'
              'Email: support@baari.in\n'
              'Phone: +91-9999999999',
        ),

        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6FCF97).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6FCF97).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  color: Color(0xFF2D9248), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your privacy matters to us. We will never sell your data.',
                  style: TextStyle(
                      color: Color(0xFF2D9248),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3B2E)),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.65),
          ),
        ],
      ),
    );
  }
}
