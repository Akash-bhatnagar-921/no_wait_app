import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'models/user_profile_model.dart';
import 'services/api_service.dart';
import 'widgets/app_snackbar.dart';

// ── Plan data ─────────────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String title;
  final int priceRs;
  final IconData icon;
  final List<_Feature> features;
  final bool highlighted;
  final Color color;
  const _Plan({
    required this.id,
    required this.title,
    required this.priceRs,
    required this.icon,
    required this.features,
    required this.color,
    this.highlighted = false,
  });
}

class _Feature {
  final String text;
  final IconData icon;
  const _Feature(this.text, this.icon);
}

const _plans = [
  _Plan(
    id: 'free',
    title: 'Free',
    priceRs: 0,
    color: Color(0xFF9E9E9E),
    icon: Icons.person_outline,
    features: [
      _Feature('Browse all nearby salons', Icons.search),
      _Feature('Up to 2 bookings per month', Icons.event_available_outlined),
      _Feature('Basic search & filters', Icons.filter_list),
      _Feature('Wishlist up to 10 salons', Icons.favorite_border),
    ],
  ),
  _Plan(
    id: 'basic',
    title: 'Basic',
    priceRs: 99,
    color: Color(0xFF6FCF97),
    icon: Icons.star_outline,
    features: [
      _Feature('Unlimited bookings every month', Icons.all_inclusive),
      _Feature('Priority slot access', Icons.flash_on_outlined),
      _Feature('Booking reminders & alerts', Icons.notifications_outlined),
      _Feature('Unlimited wishlist', Icons.favorite_border),
      _Feature('Email support (24–48 hr response)', Icons.mail_outline),
    ],
  ),
  _Plan(
    id: 'pro',
    title: 'Pro',
    priceRs: 199,
    color: Color(0xFF2D9248),
    highlighted: true,
    icon: Icons.workspace_premium_outlined,
    features: [
      _Feature('Everything in Basic', Icons.check_circle_outline),
      _Feature('Exclusive deals from top salons', Icons.local_offer_outlined),
      _Feature('Loyalty reward points on bookings', Icons.card_giftcard_outlined),
      _Feature('Dedicated priority support', Icons.headset_mic_outlined),
      _Feature('Early access to new features', Icons.new_releases_outlined),
      _Feature('Special birthday & festive offers', Icons.celebration_outlined),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _currentPlan = 'free';
  DateTime? _expiresAt;
  bool _loading = true;
  bool _cancelling = false;
  int _monthlyUsed = 0;
  String _userPhone = '';
  String _userEmail = '';
  String _userName  = '';
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getSubscription(),
      ApiService.getMonthlyBookingCount(),
      ApiService.getProfile(),
      ApiService.getUserInvoices().catchError((_) => <dynamic>[]),
    ]);
    if (mounted) {
      final sub      = results[0] as Map<String, dynamic>;
      final count    = results[1] as int;
      final profile  = results[2] as UserProfileModel?;
      final invoices = results[3] as List<dynamic>;
      setState(() {
        _currentPlan  = sub['plan']?.toString() ?? 'free';
        final exp     = sub['expiresAt'];
        _expiresAt    = exp != null ? DateTime.tryParse(exp.toString()) : null;
        _monthlyUsed  = count;
        _userPhone    = profile?.phone ?? '';
        _userEmail    = profile?.email ?? '';
        _userName     = profile?.fullName ?? '';
        _invoices     = invoices;
        _loading      = false;
      });
    }
  }

  bool get _isOnPaidPlan => _currentPlan != 'free';

  String get _expiryLabel {
    if (_expiresAt == null) return '';
    final now = DateTime.now();
    final diff = _expiresAt!.difference(now).inDays;
    if (diff <= 0) return 'Expires today';
    if (diff == 1) return 'Expires tomorrow';
    return 'Expires ${DateFormat('d MMM yyyy').format(_expiresAt!)}';
  }

  Future<void> _subscribe(_Plan plan) async {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: isTablet
          ? const BoxConstraints(maxWidth: 540)
          : const BoxConstraints(),
      builder: (_) => _PaymentSheet(
        plan: plan,
        phone: _userPhone,
        email: _userEmail,
      ),
    );
    if (ok == true && mounted) {
      // Refresh to get updated expiresAt from backend
      await _loadSubscription();
      if (mounted) AppSnackbar.success(context, '${plan.title} plan activated!');
    }
  }

  Future<void> _cancelPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Subscription',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Your ${_currentPlan[0].toUpperCase()}${_currentPlan.substring(1)} plan will revert to Free immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ApiService.cancelSubscription();
      if (mounted) {
        setState(() {
          _currentPlan = 'free';
          _expiresAt = null;
          _cancelling = false;
        });
        AppSnackbar.info(context, 'Subscription cancelled. You are now on the Free plan.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cancelling = false);
        AppSnackbar.error(context, 'Failed to cancel. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Subscriptions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48 : 18, vertical: 24),
              child: Column(children: [
                // ── Header ────────────────────────────────────────────────
                const Text('Choose Your Plan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text(
                  'Unlock more bookings and exclusive benefits.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),

                // ── Active plan badge ─────────────────────────────────────
                if (_isOnPaidPlan) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.verified_outlined, color: primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active: ${_currentPlan[0].toUpperCase()}${_currentPlan.substring(1)} Plan',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  fontSize: 13),
                            ),
                            if (_expiryLabel.isNotEmpty)
                              Text(_expiryLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (_cancelling)
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        GestureDetector(
                          onTap: _cancelPlan,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Plan cards ────────────────────────────────────────────
                ..._plans.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                        plan: p,
                        isCurrent: p.id == _currentPlan,
                        onSubscribe: () => _subscribe(p),
                      ),
                    )),

                // ── Free plan note ────────────────────────────────────────
                if (_currentPlan == 'free') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Free Plan  ·  $_monthlyUsed / 2 bookings used this month',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_monthlyUsed / 2).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.amber.shade100,
                            color: _monthlyUsed >= 2
                                ? Colors.red.shade400
                                : Colors.amber.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _monthlyUsed >= 2
                              ? 'Limit reached. Upgrade to continue booking this month.'
                              : '${2 - _monthlyUsed} booking${2 - _monthlyUsed == 1 ? '' : 's'} remaining. Upgrade to Basic or Pro for unlimited bookings.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Billing History ───────────────────────────────────────
                if (_invoices.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Billing History',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800)),
                  ),
                  const SizedBox(height: 10),
                  ..._invoices.map((inv) => _InvoiceRow(
                    invoice: inv as Map<String, dynamic>,
                    userName: _userName,
                    userPhone: _userPhone,
                    userEmail: _userEmail,
                  )),
                  const SizedBox(height: 16),
                ],
              ]),
            ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isCurrent;
  final VoidCallback onSubscribe;
  const _PlanCard(
      {required this.plan,
      required this.isCurrent,
      required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final hl = plan.highlighted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hl ? plan.color : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: hl
                ? plan.color
                : isCurrent
                    ? plan.color.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
            width: isCurrent ? 1.5 : 1),
        boxShadow: hl
            ? [
                BoxShadow(
                    color: plan.color.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title row ────────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(plan.icon,
                size: 22,
                color: hl ? Colors.white : plan.color),
            const SizedBox(width: 8),
            Text(plan.title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: hl ? Colors.white : Colors.black)),
          ]),
          if (hl)
            _badge('POPULAR', Colors.white.withValues(alpha: 0.25), Colors.white)
          else if (isCurrent)
            _badge('CURRENT',
                plan.color.withValues(alpha: 0.12), plan.color),
        ]),
        const SizedBox(height: 8),

        // ── Price ────────────────────────────────────────────────────────
        RichText(
          text: TextSpan(
            style: TextStyle(color: hl ? Colors.white : Colors.black),
            children: [
              TextSpan(
                  text: plan.priceRs == 0 ? '₹0' : '₹${plan.priceRs}',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              TextSpan(
                  text: plan.priceRs == 0 ? ' forever' : ' / month',
                  style: TextStyle(
                      fontSize: 14,
                      color: hl ? Colors.white70 : Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(
            color: hl
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.shade200),
        const SizedBox(height: 12),

        // ── Features ─────────────────────────────────────────────────────
        ...plan.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: hl
                        ? Colors.white.withValues(alpha: 0.15)
                        : plan.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f.icon,
                      size: 15,
                      color: hl ? Colors.white : plan.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.text,
                      style: TextStyle(
                          fontSize: 13,
                          color: hl ? Colors.white : Colors.black87)),
                ),
              ]),
            )),
        const SizedBox(height: 14),

        // ── CTA button ───────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hl
                  ? Colors.white
                  : isCurrent
                      ? Colors.grey.shade100
                      : plan.color,
              foregroundColor: hl
                  ? plan.color
                  : isCurrent
                      ? Colors.grey
                      : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (isCurrent || plan.priceRs == 0) ? null : onSubscribe,
            child: Text(
              isCurrent
                  ? 'Current Plan'
                  : plan.priceRs == 0
                      ? 'Free'
                      : 'Get ${plan.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );
}

// ── Invoice row ───────────────────────────────────────────────────────────────

class _InvoiceRow extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final String userName;
  final String userPhone;
  final String userEmail;
  const _InvoiceRow({
    required this.invoice,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  });

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  bool _generating = false;

  String _planLabel(String plan) {
    switch (plan.toLowerCase()) {
      case 'basic':                 return 'Basic Plan';
      case 'pro':                   return 'Pro Plan';
      case 'professional_starter':  return 'Professional Starter';
      case 'professional_growth':   return 'Professional Growth';
      case 'professional_premium':  return 'Professional Premium';
      default:                      return plan;
    }
  }

  String _fmtAmount(dynamic paise) {
    final v = (paise is num ? paise : num.tryParse(paise?.toString() ?? '')) ?? 0;
    return '₹${(v / 100).toStringAsFixed(2)}';
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('d MMM yyyy').format(dt.toLocal()) : '';
  }

  Future<void> _downloadPdf() async {
    setState(() => _generating = true);
    try {
      final bytes = Uint8List.fromList(await _buildPdf());
      final inv   = widget.invoice;
      final num   = inv['invoiceNumber'] as String? ?? 'invoice';
      await Printing.sharePdf(bytes: bytes, filename: '$num.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate PDF. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final inv   = widget.invoice;
    final num   = inv['invoiceNumber']  as String? ?? '';
    final plan  = _planLabel(inv['plan'] as String? ?? '');
    final date  = _fmtDate(inv['createdAt']);
    final total = inv['totalAmount']    as int?    ?? 0;
    final base  = inv['baseAmount']     as int?    ?? 0;
    final tax   = inv['taxAmount']      as int?    ?? 0;
    final cgst  = (tax / 2).round();
    final sgst  = tax - cgst;
    final pid   = inv['paymentId']      as String? ?? '';
    final mode  = inv['paymentMode']    as String? ?? 'razorpay';

    final name  = (inv['customerName']  as String?)?.isNotEmpty == true
        ? inv['customerName'] as String
        : widget.userName;
    final phone = (inv['customerPhone'] as String?)?.isNotEmpty == true
        ? inv['customerPhone'] as String
        : widget.userPhone;
    final email = (inv['customerEmail'] as String?)?.isNotEmpty == true
        ? inv['customerEmail'] as String
        : widget.userEmail;

    final pdf = pw.Document();

    const green  = PdfColor.fromInt(0xFF2D9248);
    const grey5  = PdfColor.fromInt(0xFF757575);
    const grey8  = PdfColor.fromInt(0xFF212121);
    const border = PdfColor.fromInt(0xFFE0E0E0);
    const bgLight = PdfColor.fromInt(0xFFF5F5F5);

    pw.TextStyle heading(double sz, {PdfColor color = grey8, bool bold = false}) =>
        pw.TextStyle(fontSize: sz, color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('BAARI', style: pw.TextStyle(
                    fontSize: 28, fontWeight: pw.FontWeight.bold, color: green)),
                pw.SizedBox(height: 4),
                pw.Text('Baari Technologies Pvt. Ltd.',
                    style: heading(9, color: grey5)),
                pw.Text('Mumbai, Maharashtra, India',
                    style: heading(9, color: grey5)),
                pw.Text('support@baari.app',
                    style: heading(9, color: grey5)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('TAX INVOICE',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                        color: grey8)),
                pw.SizedBox(height: 6),
                pw.Text(num, style: heading(10, bold: true)),
                pw.Text('Date: $date', style: heading(9, color: grey5)),
              ]),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: border, thickness: 0.5),
          pw.SizedBox(height: 16),

          // ── Bill To ──────────────────────────────────────────────────────
          pw.Text('BILL TO', style: heading(8, color: grey5, bold: true)),
          pw.SizedBox(height: 6),
          if (name.isNotEmpty) pw.Text(name, style: heading(12, bold: true)),
          if (phone.isNotEmpty) pw.Text(phone, style: heading(10, color: grey5)),
          if (email.isNotEmpty) pw.Text(email, style: heading(10, color: grey5)),

          pw.SizedBox(height: 20),

          // ── Line items header ────────────────────────────────────────────
          pw.Container(
            color: bgLight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('DESCRIPTION',
                  style: heading(9, color: grey5, bold: true))),
              pw.Expanded(flex: 2, child: pw.Text('AMOUNT',
                  style: heading(9, color: grey5, bold: true),
                  textAlign: pw.TextAlign.right)),
            ]),
          ),

          // ── Line item ────────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border(
                bottom: pw.BorderSide(color: border, width: 0.5))),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(plan, style: heading(11, bold: true)),
                  pw.Text('Monthly subscription · Valid 30 days',
                      style: heading(9, color: grey5)),
                ],
              )),
              pw.Expanded(flex: 2, child: pw.Text(_fmtAmount(base),
                  style: heading(11), textAlign: pw.TextAlign.right)),
            ]),
          ),

          pw.SizedBox(height: 12),

          // ── Totals ───────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 200,
              child: pw.Column(children: [
                _summaryRow('Subtotal',     _fmtAmount(base), grey5, heading),
                _summaryRow('CGST @ 9%',    _fmtAmount(cgst), grey5, heading),
                _summaryRow('SGST @ 9%',    _fmtAmount(sgst), grey5, heading),
                pw.SizedBox(height: 4),
                pw.Divider(color: border, thickness: 0.5),
                pw.SizedBox(height: 4),
                _summaryRow('Total',        _fmtAmount(total), green, heading, bold: true),
              ]),
            ),
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: border, thickness: 0.5),
          pw.SizedBox(height: 12),

          // ── Payment info ─────────────────────────────────────────────────
          pw.Text('PAYMENT DETAILS', style: heading(8, color: grey5, bold: true)),
          pw.SizedBox(height: 6),
          if (pid.isNotEmpty) ...[
            pw.Text('Payment Reference: $pid', style: heading(9, color: grey5)),
          ],
          pw.Text('Payment Method: ${mode == 'razorpay' ? 'Razorpay (Online)' : mode}',
              style: heading(9, color: grey5)),

          pw.Spacer(),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Divider(color: border, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Thank you for choosing Baari! This is a computer-generated invoice.',
              style: heading(8, color: grey5),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  static pw.Widget _summaryRow(
    String label,
    String value,
    PdfColor color,
    pw.TextStyle Function(double, {PdfColor color, bool bold}) heading, {
    bool bold = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: heading(10, color: color, bold: bold)),
            pw.Text(value, style: heading(10, color: color, bold: bold)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inv     = widget.invoice;
    final num     = inv['invoiceNumber'] as String? ?? '';
    final plan    = _planLabel(inv['plan'] as String? ?? '');
    final total   = inv['totalAmount']   as int?    ?? 0;
    final date    = _fmtDate(inv['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2D9248).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_long_outlined,
              color: Color(0xFF2D9248), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text('$num  ·  $date',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        Text(_fmtAmount(total),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 10),
        _generating
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D9248)))
            : IconButton(
                icon: const Icon(Icons.download_outlined, size: 22),
                color: const Color(0xFF2D9248),
                tooltip: 'Download Invoice',
                onPressed: _downloadPdf,
              ),
      ]),
    );
  }
}

// ── Payment sheet — Razorpay checkout ────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final _Plan plan;
  final String phone;
  final String email;
  const _PaymentSheet({required this.plan, this.phone = '', this.email = ''});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

enum _PayState { loading, ready, success, error }

class _PaymentSheetState extends State<_PaymentSheet> {
  late final Razorpay _razorpay;
  _PayState _state = _PayState.loading;
  String _errorMsg  = '';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _openCheckout();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Open Razorpay checkout ────────────────────────────────────────────────

  Future<void> _openCheckout() async {
    setState(() { _state = _PayState.loading; _errorMsg = ''; });
    try {
      final order = await ApiService.createSubscriptionOrder(widget.plan.id);
      if (!mounted) return;
      _razorpay.open({
        'key':         order['keyId'],
        'amount':      order['amount'],
        'currency':    order['currency'] ?? 'INR',
        'order_id':    order['orderId'],
        'name':        'Baari',
        'description': '${widget.plan.title} Plan · ₹${widget.plan.priceRs}/month',
        'prefill':     {'contact': widget.phone, 'email': widget.email},
        'theme':       {'color': '#2D9248'},
      });
      if (mounted) setState(() => _state = _PayState.ready);
    } on ApiException catch (e) {
      if (mounted) setState(() { _state = _PayState.error; _errorMsg = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _state    = _PayState.error;
          _errorMsg = 'Could not start payment. Please try again.';
        });
      }
    }
  }

  // ── Razorpay callbacks ────────────────────────────────────────────────────

  void _onSuccess(PaymentSuccessResponse r) async {
    setState(() => _state = _PayState.loading);
    try {
      await ApiService.createSubscription(
        widget.plan.id,
        paymentId: r.paymentId,
        orderId:   r.orderId,
        signature: r.signature,
      );
      if (!mounted) return;
      setState(() => _state = _PayState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _state    = _PayState.error;
          _errorMsg = e.message;
        });
      }
    }
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    // Code 0 = user dismissed the Razorpay screen ("Yes, exit") — close quietly.
    if (r.code == 0) {
      Navigator.pop(context, false);
      return;
    }
    final msg = r.message ?? '';
    setState(() {
      _state    = _PayState.error;
      _errorMsg = (msg.isEmpty || msg == 'undefined')
          ? 'Payment was not completed. Please try again.'
          : msg;
    });
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Wallet payment initiated — treat like error since we can't verify it here
    if (mounted) {
      setState(() {
        _state    = _PayState.error;
        _errorMsg = 'External wallet payment is not supported yet. Use card or UPI.';
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final hPad = isTablet ? 48.0 : 24.0;
    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.70),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 36),
      child: switch (_state) {
        _PayState.loading    => _buildLoading(),
        _PayState.ready      => _buildReady(),
        _PayState.success    => _buildSuccess(),
        _PayState.error      => _buildError(isTablet),
      },
    );
  }

  Widget _buildLoading() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dragHandle(),
      const SizedBox(height: 32),
      const CircularProgressIndicator(color: Color(0xFF2D9248)),
      const SizedBox(height: 20),
      const Text('Opening secure payment…',
          style: TextStyle(color: Colors.grey, fontSize: 14)),
      const SizedBox(height: 32),
    ],
  );

  Widget _buildReady() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dragHandle(),
      const SizedBox(height: 24),
      const Icon(Icons.lock_outline, color: Color(0xFF2D9248), size: 36),
      const SizedBox(height: 12),
      Text('Pay ₹${widget.plan.priceRs} / month',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('Razorpay checkout opened above.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 24),
    ],
  );

  Widget _buildSuccess() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dragHandle(),
      const SizedBox(height: 24),
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF6FCF97).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Color(0xFF2D9248), size: 32),
      ),
      const SizedBox(height: 14),
      Text('${widget.plan.title} Plan Activated!',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('₹${widget.plan.priceRs} / month · Valid for 30 days',
          style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 24),
    ],
  );

  Widget _buildError([bool isTablet = false]) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dragHandle(),
      const SizedBox(height: 24),
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.error_outline, color: Colors.red.shade500, size: 30),
      ),
      const SizedBox(height: 14),
      const Text('Payment Failed',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        _errorMsg,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 24),
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 380 : double.infinity),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _openCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D9248),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),        // Row
        ),           // ConstrainedBox
      ),             // Center
      const SizedBox(height: 8),
    ],
  );

  Widget _dragHandle() => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2)),
    ),
  );
}
