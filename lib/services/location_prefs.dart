import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLocation {
  final double lat;
  final double lng;
  final String name;
  const SavedLocation({required this.lat, required this.lng, required this.name});
}

/// Persists the user's chosen location and booking date across sessions.
class LocationPrefs {
  static const _latKey  = 'saved_lat';
  static const _lngKey  = 'saved_lng';
  static const _nameKey = 'saved_location_name';
  static const _dateKey = 'saved_booking_date';

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  // ── Location ────────────────────────────────────────────────────────────────

  static Future<void> saveLocation({
    required double lat,
    required double lng,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(_latKey,  lat),
      prefs.setDouble(_lngKey,  lng),
      prefs.setString(_nameKey, name),
    ]);
  }

  static Future<SavedLocation?> loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat  = prefs.getDouble(_latKey);
    final lng  = prefs.getDouble(_lngKey);
    final name = prefs.getString(_nameKey);
    if (lat == null || lng == null) return null;
    return SavedLocation(lat: lat, lng: lng, name: name ?? 'Selected location');
  }

  // ── Date ────────────────────────────────────────────────────────────────────

  static Future<void> saveDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, _dateFmt.format(date));
  }

  static Future<DateTime?> loadDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_dateKey);
    if (str == null) return null;
    try {
      return _dateFmt.parse(str);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_latKey),
      prefs.remove(_lngKey),
      prefs.remove(_nameKey),
      prefs.remove(_dateKey),
    ]);
  }
}
