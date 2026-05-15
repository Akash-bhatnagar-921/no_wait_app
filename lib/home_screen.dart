import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'find_salons_screen.dart';
import 'map_screen.dart';
import 'services/location_prefs.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SavedLocation? _location;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final loc  = await LocationPrefs.loadLocation();
    final date = await LocationPrefs.loadDate();
    if (mounted) setState(() { _location = loc; _date = date; });
  }

  // ── Location picker ────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final result = await Navigator.push<SavedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    if (result != null && mounted) {
      setState(() => _location = result);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null && mounted) {
      await LocationPrefs.saveDate(picked);
      setState(() => _date = picked);
    }
  }

  // ── Find Salons ────────────────────────────────────────────────────────────

  void _findSalons() {
    if (_location == null) {
      AppSnackbar.warning(context, 'Please select a location first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindSalonsScreen(
          location: _location!,
          date: _date ?? DateTime.now(),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _locationLabel =>
      _location?.name ?? 'Use current location';

  String get _dateLabel {
    if (_date == null) return 'Choose your slot';
    final today = DateTime.now();
    if (_date!.year == today.year && _date!.month == today.month && _date!.day == today.day) {
      return 'Today';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (_date!.year == tomorrow.year && _date!.month == tomorrow.month && _date!.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('d MMM yyyy').format(_date!);
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isDesktop = size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 40),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 900 : (isTablet ? 700 : double.infinity),
            ),
            child: isTablet ? _tabletLayout() : _mobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [_image(), const SizedBox(height: 20), _content()],
      ),
    );
  }

  Widget _tabletLayout() {
    return Row(children: [
      Expanded(flex: 5, child: Padding(
          padding: const EdgeInsets.all(20), child: _image())),
      Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(32), child: _content())),
    ]);
  }

  Widget _image() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.asset('assets/salon.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Find the best salons near you',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Choose your location and date to skip waiting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 25),

        // Location card
        _card(
          icon: Icons.location_on,
          title: 'Location',
          subtitle: _locationLabel,
          hasValue: _location != null,
          onTap: _openMap,
        ),

        // Date card
        _card(
          icon: Icons.calendar_today,
          title: 'Select Date',
          subtitle: _dateLabel,
          hasValue: _date != null,
          onTap: _pickDate,
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _findSalons,
            child: const Text('Find Salons',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool hasValue = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasValue
              ? primary.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: hasValue
              ? Border.all(color: primary.withValues(alpha: 0.35))
              : null,
        ),
        child: Row(children: [
          Icon(icon, color: hasValue ? primary : Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasValue ? primary : Colors.black87)),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: hasValue ? primary.withValues(alpha: 0.8)
                                      : Colors.grey,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14,
              color: hasValue ? primary : Colors.grey.shade400),
        ]),
      ),
    );
  }
}
