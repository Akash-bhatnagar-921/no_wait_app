import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'services/location_prefs.dart';
import 'widgets/app_snackbar.dart';

/// Pure location-picker screen.
/// User picks a location (GPS / search / map pan), taps "Set Location",
/// and the screen pops with a [SavedLocation].
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Map state
  LatLng _center = const LatLng(20.5937, 78.9629); // India default
  LatLng? _currentLocation; // GPS blue dot
  String _centerName = 'Locating…';

  // UI
  bool _locating = false;
  bool _isSearching = false;
  bool _isReverseGeocoding = false;
  bool _showSuggestions = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  Timer? _reverseDebounce;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && mounted) {
        setState(() => _showSuggestions = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reverseDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _autoLocate() async {
    await _goToCurrentLocation(silent: true);
  }

  Future<void> _goToCurrentLocation({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !silent) {
          _showLocationDialog(
            title: 'GPS Disabled',
            body: 'Please enable Location/GPS in your device settings.',
            actionLabel: 'Open Settings',
            onAction: Geolocator.openLocationSettings,
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted && !silent) {
          AppSnackbar.warning(context, 'Location permission denied.');
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationDialog(
            title: 'Permission Denied',
            body: 'Location permission is permanently denied.\nEnable it in App Settings.',
            actionLabel: 'Open Settings',
            onAction: Geolocator.openAppSettings,
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;

      final center = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = center;
        _currentLocation = center;
      });
      _mapController.move(center, 16.0);
      _scheduleReverseGeocode(center);
    } on TimeoutException {
      if (mounted && !silent) {
        AppSnackbar.error(context, 'GPS timed out. Search manually or try again.');
      }
    } catch (e) {
      if (mounted && !silent) {
        AppSnackbar.error(context, 'Could not get location. Search manually.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationDialog({
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.location_off_outlined,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Text(body,
            style: const TextStyle(color: Colors.black54, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(ctx); onAction(); },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  void _scheduleReverseGeocode(LatLng pos) {
    _reverseDebounce?.cancel();
    setState(() { _isReverseGeocoding = true; _centerName = 'Locating…'; });
    _reverseDebounce = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(pos);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': pos.latitude.toString(),
        'lon': pos.longitude.toString(),
        'format': 'json',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'Baari/1.0 (salon-booking-app)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final name = _extractLocationName(address, data['display_name'] as String? ?? '');
        setState(() { _centerName = name; _isReverseGeocoding = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _centerName = 'Selected location'; _isReverseGeocoding = false; });
    }
  }

  String _extractLocationName(Map<String, dynamic> address, String displayName) {
    final suburb  = address['suburb']        as String?;
    final quarter = address['city_district']  as String?;
    final city    = address['city']           as String?
                 ?? address['town']           as String?
                 ?? address['village']        as String?;
    final state   = address['state']          as String?;

    final parts = [suburb ?? quarter, city ?? state]
        .where((e) => e != null && e.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');

    // Fallback: first two comma-parts of display_name
    final fallbackParts = displayName.split(',').take(2).map((s) => s.trim()).toList();
    return fallbackParts.join(', ');
  }

  // ── Forward search (Nominatim) ─────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      if (mounted) setState(() { _showSuggestions = false; _isSearching = false; });
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final vbMinLng = (_center.longitude - 0.5).clamp(-180.0, 180.0);
      final vbMinLat = (_center.latitude  - 0.5).clamp(-90.0,   90.0);
      final vbMaxLng = (_center.longitude + 0.5).clamp(-180.0, 180.0);
      final vbMaxLat = (_center.latitude  + 0.5).clamp(-90.0,   90.0);

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query, 'format': 'json', 'limit': '8',
        'addressdetails': '1',
        'viewbox': '$vbMinLng,$vbMinLat,$vbMaxLng,$vbMaxLat',
        'bounded': '0',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'Baari/1.0 (salon-booking-app)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() {
          _suggestions = list;
          _showSuggestions = list.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> place) async {
    final lat = double.tryParse(place['lat']?.toString() ?? '');
    final lng = double.tryParse(place['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;

    final parts = (place['display_name'] as String? ?? '').split(',');
    _searchCtrl.text = parts.first.trim();
    _searchFocus.unfocus();

    final center = LatLng(lat, lng);
    setState(() {
      _center = center;
      _showSuggestions = false;
      _isSearching = false;
    });
    _mapController.move(center, 14.0);
    _scheduleReverseGeocode(center);
  }

  // ── Set location ───────────────────────────────────────────────────────────

  Future<void> _confirmLocation() async {
    final name = _isReverseGeocoding ? 'Selected location' : _centerName;
    await LocationPrefs.saveLocation(
      lat: _center.latitude,
      lng: _center.longitude,
      name: name,
    );
    if (!mounted) return;
    AppSnackbar.success(context, 'Location set to $name');
    Navigator.pop(context,
        SavedLocation(lat: _center.latitude, lng: _center.longitude, name: name));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildMap(),
          _buildCenterPin(),
          SafeArea(child: _buildTopBar()),
          if (_showSuggestions) SafeArea(child: _buildSuggestionsDropdown()),
          _buildGpsFab(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 5.0,
        onTap: (tapPos, point) {
          _searchFocus.unfocus();
          setState(() => _showSuggestions = false);
        },
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            final newCenter = position.center;
            setState(() => _center = newCenter);
            _scheduleReverseGeocode(newCenter);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.baari.no_wait_app',
          maxZoom: 19,
          keepBuffer: 6,
          panBuffer: 3,
        ),
        if (_currentLocation != null)
          MarkerLayer(markers: [
            Marker(
              point: _currentLocation!,
              width: 36, height: 36,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
                ),
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.45),
                        blurRadius: 8, spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
      ],
    );
  }

  /// Fixed crosshair pin at the exact map center — shows what will be selected.
  Widget _buildCenterPin() {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: primary.withValues(alpha: 0.4),
                    blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.content_cut, color: Colors.white, size: 20),
          ),
          // Pin stem
          Container(width: 2, height: 14, color: primary),
          // Dot at base
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          ),
          // Invisible spacer so pin tip points to true center
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _pill(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _pill(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              child: Row(children: [
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search city, area or landmark…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isSearching)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() { _showSuggestions = false; _isSearching = false; });
                    },
                    child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required Widget child, VoidCallback? onTap,
      EdgeInsets padding = const EdgeInsets.all(10)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

  // ── Suggestions ────────────────────────────────────────────────────────────

  Widget _buildSuggestionsDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 72, 12, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions.asMap().entries.map((e) {
                  final idx = e.key;
                  final place = e.value;
                  final parts = (place['display_name'] as String? ?? '').split(',');
                  final title = parts.first.trim();
                  final subtitle = parts.skip(1).take(2).join(',').trim();
                  return Column(children: [
                    InkWell(
                      onTap: () => _selectSuggestion(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.location_on_outlined, size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                              if (subtitle.isNotEmpty)
                                Text(subtitle, style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          )),
                        ]),
                      ),
                    ),
                    if (idx < _suggestions.length - 1)
                      Divider(height: 1, color: Colors.grey.shade100),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── GPS FAB ────────────────────────────────────────────────────────────────

  Widget _buildGpsFab() {
    return Positioned(
      right: 16,
      bottom: 110,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        elevation: 4,
        onPressed: _goToCurrentLocation,
        child: _locating
            ? SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Icon(Icons.my_location,
                color: Theme.of(context).colorScheme.primary, size: 20),
      ),
    );
  }

  // ── Bottom "Set Location" bar ──────────────────────────────────────────────

  Widget _buildBottomBar() {
    final primary = Theme.of(context).colorScheme.primary;
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.location_on, size: 16, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isReverseGeocoding ? 'Locating…' : _centerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isReverseGeocoding ? Colors.grey : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('within 1 km radius',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Set This Location',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: _isReverseGeocoding ? null : _confirmLocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
