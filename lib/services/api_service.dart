import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../barber_setup/models/salon_onboarding_model.dart';
import '../role_selection_screen.dart';
import '../models/user_profile_model.dart';
import 'location_prefs.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: "http://192.168.1.10:3000",
  );
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Set from main.dart so the service can navigate on 401 without a BuildContext.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Called whenever the server returns 401. Clears the token and sends the
  /// user back to role-selection so they can log in again.
  static Future<void> _handleUnauthorized() async {
    await logout();
    // Use currentState directly — avoids BuildContext-across-async-gap lint.
    navigatorKey?.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }
  static Map<String, dynamic> loginData = {};
  // static String? accessToken;

  // ================= AUTH =================

  static Future<Map<String, dynamic>> register({
    required String phone,
    required String role,
    required String name,
    required String email,
    required int age,
    required String gender,
    bool hasAcceptedTerms = false,
  }) async {
    final response = await _postJson('/auth/register', {
      "phone": phone,
      "role": role,
      "name": name,
      "email": email,
      "age": age,
      "gender": gender,
      "hasAcceptedTerms": hasAcceptedTerms,
    });

    return _decodeResponse(response, 'Registration failed');
  }

  // ================= Login =================

  static Future<Map<String, dynamic>> login({required String phone}) async {
    final response = await _postJson('/auth/login', {"phone": phone});

    if (response.statusCode != 200) {
      throw Exception('Login failed');
    }

    loginData = jsonDecode(response.body);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> requestLoginOtp({
    required String phone,
  }) async {
    final response = await _postJson('/auth/login/request-otp', {
      "phone": phone,
    });

    return _decodeResponse(response, 'Failed to send OTP');
  }

  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _postJson('/auth/login/verify-otp', {
      "phone": phone,
      "otp": otp,
    });

    final data = _decodeResponse(response, 'OTP verification failed');
    loginData = data;
    return data;
  }

  // ================= TOKEN =================

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('access_token');
  }

  // ================= PHONE CHECK =================

  static Future<Map<String, dynamic>> checkPhone(String phone) async {
    final response = await http
        .get(Uri.parse('$baseUrl/auth/check-phone?phone=$phone'))
        .timeout(requestTimeout);
    return _decodeResponse(response, 'Phone check failed');
  }

  // ================= SERVICES =================

  static Future<List<dynamic>> getServices() async {
    final res = await http.get(Uri.parse('$baseUrl/salons/services'));
    return jsonDecode(res.body);
  }

  // ================= AMENITIES =================

  static Future<List<dynamic>> getAmenities() async {
    final res = await http.get(Uri.parse('$baseUrl/salons/amenities'));
    return jsonDecode(res.body);
  }

  // ================= NEARBY SALONS =================

  static Future<List<dynamic>> nearbySalons({
    required double lat,
    required double lng,
    double radiusKm = 1,
  }) async {
    return searchSalons(lat: lat, lng: lng, radiusKm: radiusKm);
  }

  // ================= SEARCH SALONS (full filters) =================

  static Future<List<dynamic>> searchSalons({
    required double lat,
    required double lng,
    double radiusKm = 1,
    List<String> amenities = const [],
    List<String> services  = const [],
    String sort = 'distance_asc',
  }) async {
    final params = <String, String>{
      'lat':    lat.toString(),
      'lng':    lng.toString(),
      'radius': radiusKm.toString(),
      'sort':   sort,
      if (amenities.isNotEmpty) 'amenities': amenities.join(','),
      if (services.isNotEmpty)  'services':  services.join(','),
    };
    final uri = Uri.parse('$baseUrl/salons/nearby').replace(queryParameters: params);
    try {
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ================= FRANCHISE SEARCH =================

  static Future<List<dynamic>> searchFranchises(String query) async {
    final encoded = Uri.encodeComponent(query);
    final res = await http
        .get(Uri.parse('$baseUrl/salons/franchises?q=$encoded'))
        .timeout(requestTimeout);
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ================= VERIFY SALON CODE (2-step login) =================

  static Future<Map<String, dynamic>> verifySalonCode({
    required String phone,
    required String code,
  }) async {
    final response = await _postJson('/salons/verify-code', {
      "phone": phone,
      "code": code,
    });
    return _decodeResponse(response, 'Invalid secret code');
  }

  // ================= MY SALONS (for professional login check) =================

  static Future<List<dynamic>> getMySalons() async {
    final token = await getToken();
    if (token == null) return [];
    final response = await http
        .get(
          Uri.parse('$baseUrl/salons/my'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    return jsonDecode(response.body) as List<dynamic>;
  }

  // ================= SUBSCRIPTION =================

  static Future<Map<String, dynamic>> getSubscription() async {
    final token = await getToken();
    if (token == null) return {'plan': 'free', 'status': 'active'};
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/subscription'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (res.statusCode != 200) return {'plan': 'free', 'status': 'active'};
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'plan': 'free', 'status': 'active'};
    }
  }

  /// Professional subscription details including feature limits.
  static Future<Map<String, dynamic>> getProfessionalSubscription() async {
    final token = await getToken();
    if (token == null) return {'plan': 'free', 'status': 'active'};
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/subscription/professional'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (res.statusCode != 200) return {'plan': 'free', 'status': 'active'};
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'plan': 'free', 'status': 'active'};
    }
  }

  /// Step 1 of checkout: creates a Razorpay order on the server.
  /// Returns { orderId, amount, currency, keyId }.
  static Future<Map<String, dynamic>> createSubscriptionOrder(String plan) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/users/subscription/order'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'plan': plan}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create payment order');
  }

  /// Step 2 of checkout: verifies the Razorpay payment and activates the plan.
  static Future<Map<String, dynamic>> createSubscription(
    String plan, {
    String? paymentId,
    String? orderId,
    String? signature,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/users/subscription'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'plan':      plan,
        'paymentId': ?paymentId,
        'orderId':   ?orderId,
        'signature': ?signature,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Subscription activation failed');
  }

  // ================= INVOICES =================

  static Future<List<dynamic>> getUserInvoices() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/users/invoices'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load invoices');
  }

  static Future<Map<String, dynamic>> getInvoiceDetail(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/users/invoices/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load invoice');
  }

  // ================= SALON OPEN/CLOSED STATUS =================

  static Future<void> updateSalonOpenStatus(bool isOpen) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/open-status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'isOpen': isOpen}),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update salon status');
  }

  // ================= SALON LOCATION UPDATE (professional) =================

  /// Submits a new location for the professional's salon. Goes live only after
  /// admin approval via PATCH /salons/:id/approve-location.
  /// Submit a city / state / pincode change for admin approval.
  static Future<Map<String, dynamic>> updateSalonAddress({
    required String city,
    required String state,
    String? pincode,
    String? address,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/address'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'city':    city,
        'state':   state,
        'pincode': ?pincode,
        'address': ?address,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update address');
  }

  static Future<Map<String, dynamic>> updateSalonLocation({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'lat': lat, 'lng': lng, 'address': address}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to submit location update');
  }

  // ================= SALON CONFIG (professional) =================

  static Future<Map<String, dynamic>> getMySalonConfig() async {
    final token = await getToken();
    if (token == null) return {};
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/salons/my/config'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (res.statusCode != 200) return {};
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> updateSalonServices(
    List<Map<String, dynamic>> services,
  ) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.put(
      Uri.parse('$baseUrl/salons/my/services'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'services': services}),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update services');
  }

  /// Each entry must include amenityName. amenityId is optional (null/missing
  /// for custom amenities the backend will create on the fly).
  static Future<void> updateSalonAmenities(
    List<Map<String, dynamic>> amenities,
  ) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.put(
      Uri.parse('$baseUrl/salons/my/amenities'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'amenities': amenities}),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update amenities');
  }

  // ================= WISHLIST =================

  static Future<List<dynamic>> getWishlist() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/wishlist'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  /// Returns only the salonIds the user has wishlisted — cheap sync call.
  static Future<Set<String>> getWishlistIds() async {
    final token = await getToken();
    if (token == null) return {};
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/wishlist/ids'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) return {};
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final ids = data['ids'] as List<dynamic>? ?? [];
      return ids.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> addToWishlist(String salonId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final response = await http
        .post(
          Uri.parse('$baseUrl/users/wishlist/$salonId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        (body['message'] as String?) ?? 'Could not add to wishlist',
      );
    }
  }

  static Future<bool> removeFromWishlist(String salonId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/users/wishlist/$salonId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ================= DELETE ACCOUNT =================

  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final response = await http
        .delete(
          Uri.parse('$baseUrl/users/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(requestTimeout);
    return _decodeResponse(response, 'Failed to delete account');
  }

  // ================= LOGOUT =================

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    // Clear saved location and date so the next user starts fresh
    await LocationPrefs.clearAll();
  }

  // ================= CREATE SALON =================

  static Future<Map<String, dynamic>> createSalon({
    required SalonOnboardingModel salonData,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/salons'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "salonName":     salonData.salonName,
            "address":       salonData.address,
            "city":          salonData.city,
            "pincode":       salonData.pincode,
            "state":         salonData.state,
            "landmark":      salonData.landmark,
            // Salon phone = login credential (stored in User.phone)
            "contactNumber": salonData.contactNumber,
            "shopEmail":     salonData.shopEmail,
            // Business owner — ownership records only, NOT used for login
            "ownerName":     salonData.ownerName,
            if (salonData.ownerPhone.isNotEmpty)
              "ownerPhone":  salonData.ownerPhone,
            "openingTime":   salonData.openingTime,
            "closingTime":   salonData.closingTime,
            "workingDays":   salonData.workingDays.join(','),
            "services":      salonData.services,
            "amenities":     salonData.amenities,
            "barbers":       salonData.barbers,
            if (salonData.franchiseId.isNotEmpty)
              "franchiseId":   salonData.franchiseId,
            if (salonData.franchiseName.isNotEmpty)
              "franchiseName": salonData.franchiseName,
          }),
        )
        .timeout(requestTimeout);

    return _decodeResponse(response, 'Failed to create salon');
  }

  static Future<UserProfileModel?> getProfile() async {
    // final prefs = await SharedPreferences.getInstance();

    final token = await ApiService.getToken();

    if (token == null) {
      return null;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Profile fetch failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    return UserProfileModel.fromJson(data);
  }

  // ================= SALON DETAIL =================

  static Future<Map<String, dynamic>?> getSalonDetail(String salonId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/salons/$salonId'))
          .timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ================= BOOKING SLOTS =================

  static Future<List<dynamic>> getAvailableSlots({
    required String salonId,
    required String date,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/bookings/slots')
          .replace(queryParameters: {'salonId': salonId, 'date': date});
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ================= BOOKINGS =================

  static Future<Map<String, dynamic>> createBooking({
    required String salonId,
    required String salonName,
    required String scheduledAt,
    required List<Map<String, dynamic>> services,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'salonId': salonId,
        'salonName': salonName,
        'scheduledAt': scheduledAt,
        'services': services,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create booking');
  }

  /// Returns `{ bookings: List, pagination: { page, limit, total, hasMore } }`.
  static Future<Map<String, dynamic>> getMyBookingsPaged({
    int page = 1,
    int limit = 20,
  }) async {
    final token = await getToken();
    if (token == null) return {'bookings': [], 'pagination': {'hasMore': false}};
    try {
      final uri = Uri.parse('$baseUrl/bookings/my')
          .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return {'bookings': [], 'pagination': {'hasMore': false}};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'bookings': [], 'pagination': {'hasMore': false}};
    }
  }

  /// Convenience: fetch page 1 only, returns the flat booking list.
  static Future<List<dynamic>> getMyBookings() async {
    final result = await getMyBookingsPaged(page: 1, limit: 20);
    return (result['bookings'] as List?) ?? [];
  }

  /// Returns `{ bookings: List, stats: { todayBookings, todayRevenue, pendingCount } }`.
  static Future<Map<String, dynamic>> getSalonBookings() async {
    final token = await getToken();
    if (token == null) return {'bookings': [], 'stats': {}};
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/salon'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return {'bookings': [], 'stats': {}};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'bookings': [], 'stats': {}};
    }
  }

  static Future<Map<String, dynamic>> completeBooking(String bookingId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/complete'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to complete booking');
  }

  // ================= SALON REVIEWS =================

  static Future<List<dynamic>> getSalonReviews(String salonId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/salons/$salonId/reviews'))
          .timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ================= EARNINGS (professional) =================

  static Future<Map<String, dynamic>> getEarnings() async {
    final token = await getToken();
    if (token == null) return {'stats': {}, 'bookings': []};
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/earnings'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return {'stats': {}, 'bookings': []};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'stats': {}, 'bookings': []};
    }
  }

  // ================= MY REVIEWS (professional) =================

  static Future<List<dynamic>> getMyReviews() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/salons/my/reviews'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ================= BARBER MANAGEMENT =================

  static Future<List<dynamic>> getMyBarbers() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/salons/my/barbers'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return [];
      return jsonDecode(response.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addBarber(
      String name, int experience, {String? workingDays}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/my/barbers'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'experience': experience,
        'workingDays': ?workingDays,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to add barber');
  }

  static Future<Map<String, dynamic>> updateBarber(
      String barberId, String name, int experience,
      {String? workingDays}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'experience': experience,
        'workingDays': ?workingDays,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update barber');
  }

  static Future<Map<String, dynamic>> deleteBarber(String barberId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to remove barber');
  }

  // ================= WORKING HOURS =================

  static Future<Map<String, dynamic>> updateWorkingHours({
    required String openingTime,
    required String closingTime,
    required String workingDays,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/hours'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'openingTime': openingTime,
        'closingTime': closingTime,
        'workingDays': workingDays,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update working hours');
  }

  static Future<Map<String, dynamic>> modifyBookingServices({
    required String bookingId,
    required List<Map<String, dynamic>> services,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/services'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'services': services}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to modify booking');
  }

  static Future<Map<String, dynamic>> acceptBooking(String bookingId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/accept'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to accept booking');
  }

  static Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/reject'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to reject booking');
  }

  static Future<Map<String, dynamic>> verifyBookingOtp(
      String bookingId, String otp) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/verify-otp'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'otp': otp}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Invalid OTP');
  }

  static Future<Map<String, dynamic>?> getActiveBooking() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/active'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body == null ? null : body as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> cancelBooking(
    String bookingId, {
    String? reason,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final request = http.Request(
      'DELETE', Uri.parse('$baseUrl/bookings/$bookingId'));
    request.headers['Authorization'] = 'Bearer $token';
    if (reason != null && reason.isNotEmpty) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'reason': reason});
    }
    final streamed = await request.send().timeout(requestTimeout);
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res, 'Failed to cancel booking');
  }

  // ================= REVIEWS =================

  static Future<Map<String, dynamic>> submitReview({
    required String salonId,
    required int rating,
    String comment = '',
    String? bookingId,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/$salonId/reviews'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'rating': rating,
        'comment': comment,
        'bookingId': bookingId,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to submit review');
  }

  // ================= UPDATE PROFILE =================

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update profile');
  }

  // ================= FCM TOKEN =================

  static Future<void> saveFcmToken(String token) async {
    final t = await getToken();
    if (t == null) return; // not logged in yet — skip
    try {
      await http.patch(
        Uri.parse('$baseUrl/users/fcm-token'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(requestTimeout);
    } catch (_) { /* best-effort — silently ignore */ }
  }

  // ================= MONTHLY BOOKING COUNT =================

  /// Single server-side COUNT query — never fetches full booking list.
  static Future<int> getMonthlyBookingCount() async {
    final token = await getToken();
    if (token == null) return 0;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/monthly-count'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return 0;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getProfessionalMonthlyBookingCount() async {
    final token = await getToken();
    if (token == null) return 0;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/professional/monthly-count'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return 0;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ================= DISCOVERY =================

  static Future<Map<String, dynamic>?> getLastCompletedBooking() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/last-completed'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body == null) return null;
      return body as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getTrendingSalons({
    double? lat,
    double? lng,
    String? city,
    double radiusKm = 10,
  }) async {
    try {
      String query;
      if (lat != null && lng != null) {
        query = 'lat=$lat&lng=$lng&radius=$radiusKm';
      } else if (city != null && city.isNotEmpty) {
        query = 'city=${Uri.encodeComponent(city)}';
      } else {
        query = '';
      }
      final url = '$baseUrl/salons/trending${query.isNotEmpty ? '?$query' : ''}';
      final res = await http.get(Uri.parse(url)).timeout(requestTimeout);
      if (res.statusCode != 200) return {'topSalons': [], 'popularServices': []};
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'topSalons': [], 'popularServices': []};
    }
  }

  static Future<Map<String, dynamic>> getSalonQueue(String salonId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/salons/$salonId/queue'),
      ).timeout(requestTimeout);
      if (res.statusCode != 200) {
        return {'queueSize': 0, 'estimatedWaitMins': 0, 'isAvailable': true, 'barberCount': 1};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'queueSize': 0, 'estimatedWaitMins': 0, 'isAvailable': true, 'barberCount': 1};
    }
  }

  // ================= SALON PHOTO UPLOAD =================

  /// Uploads an image file as the salon's cover photo.
  /// [filePath] must be an absolute path to a local JPEG/PNG/WebP file.
  static Future<Map<String, dynamic>> uploadSalonPhoto(String filePath) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/salons/my/photo'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));
    final streamed = await request.send().timeout(requestTimeout);
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res, 'Failed to upload photo');
  }

  // ================= CANCEL SUBSCRIPTION =================

  static Future<Map<String, dynamic>> cancelSubscription() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/users/subscription'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to cancel subscription');
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String fallbackMessage,
  ) {
    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{"data": decoded};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        // Token expired or revoked — clear session and send to login.
        _handleUnauthorized();
      }
      throw ApiException(
        response.statusCode,
        data['message']?.toString() ?? fallbackMessage,
        data,
      );
    }

    return data;
  }

  static Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        408,
        'Connection timed out. Check that the backend is running on $baseUrl and your phone is on the same Wi-Fi.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        0,
        'Cannot connect to backend at $baseUrl. ${e.message}',
      );
    }
  }

  // ================= OFFERS =================

  // Customer: active offers for a specific salon
  static Future<List<dynamic>> getSalonOffers(String salonId) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/salons/$salonId/offers'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    ).timeout(requestTimeout);
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  // Customer: all active offers across all salons
  static Future<List<dynamic>> getAllActiveOffers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/salons/offers/active'),
    ).timeout(requestTimeout);
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  // Professional: get my offers
  static Future<List<dynamic>> getMyOffers() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/salons/my/offers'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load offers');
  }

  // Professional: create offer
  static Future<Map<String, dynamic>> createOffer({
    required String title,
    String? description,
    int discountPercent = 0,
    String? validUntil,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/my/offers'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        if (description != null) 'description': description,
        'discountPercent': discountPercent,
        if (validUntil != null) 'validUntil': validUntil,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create offer');
  }

  // Professional: update offer
  static Future<Map<String, dynamic>> updateOffer(
    String offerId, {
    String? title,
    String? description,
    int? discountPercent,
    String? validUntil,
    bool? isActive,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/offers/$offerId'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (discountPercent != null) 'discountPercent': discountPercent,
        if (validUntil != null) 'validUntil': validUntil,
        if (isActive != null) 'isActive': isActive,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update offer');
  }

  // Professional: delete offer
  static Future<void> deleteOffer(String offerId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/offers/$offerId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw ApiException(res.statusCode, 'Failed to delete offer');
    }
  }

  // ================= BARBER PROFILES =================

  static Future<Map<String, dynamic>?> getBarberProfile(String barberId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/barbers/$barberId'))
          .timeout(requestTimeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> followBarber(String barberId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/barbers/$barberId/follow'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to follow barber');
  }

  static Future<Map<String, dynamic>> unfollowBarber(String barberId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/barbers/$barberId/follow'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to unfollow barber');
  }

  static Future<List<dynamic>> getFollowedBarbers() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/barbers/following'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(requestTimeout);
      if (res.statusCode != 200) return [];
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateBarberProfile(
    String barberId, {
    String? specialization,
    String? bio,
    String? openingTime,
    String? closingTime,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/profile'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (specialization != null) 'specialization': specialization,
        if (bio != null) 'bio': bio,
        if (openingTime != null) 'openingTime': openingTime,
        if (closingTime != null) 'closingTime': closingTime,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update barber profile');
  }

  static Future<Map<String, dynamic>> setBarberAvailability(
    String barberId, {
    required bool isAvailable,
    String? leaveUntil,
    String? breakUntil,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/availability'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'isAvailable': isAvailable,
        if (leaveUntil != null) 'leaveUntil': leaveUntil,
        if (breakUntil != null) 'breakUntil': breakUntil,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update availability');
  }

  static Future<Map<String, dynamic>> uploadBarberPhoto(
      String barberId, String filePath) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/photo'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));
    final streamed = await request.send().timeout(requestTimeout);
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res, 'Failed to upload barber photo');
  }

  static Future<Map<String, dynamic>> addToBarberGallery(
      String barberId, String filePath, {String? caption}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/gallery'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));
    if (caption != null) request.fields['caption'] = caption;
    final streamed = await request.send().timeout(requestTimeout);
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res, 'Failed to upload gallery photo');
  }

  static Future<Map<String, dynamic>> removeFromBarberGallery(
      String barberId, int index) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/gallery/$index'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to remove gallery photo');
  }

  // ================= SALON PORTFOLIO =================

  static Future<List<dynamic>> getSalonPortfolio(String salonId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/salons/$salonId/portfolio'))
          .timeout(requestTimeout);
      if (res.statusCode != 200) return [];
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> uploadPortfolioPhoto(
    String filePath, {
    String type = 'portfolio',
    String? caption,
    String? beforeUrl,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/salons/my/portfolio'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['type'] = type
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));
    if (caption != null) request.fields['caption'] = caption;
    if (beforeUrl != null) request.fields['beforeUrl'] = beforeUrl;
    final streamed = await request.send().timeout(requestTimeout);
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res, 'Failed to upload portfolio photo');
  }

  static Future<Map<String, dynamic>> deletePortfolioPhoto(String photoId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/portfolio/$photoId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to delete portfolio photo');
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminLogin(String phone, String password) async {
    final res = await _postJson('/admin/auth/login', {'phone': phone, 'password': password});
    return _decodeResponse(res, 'Admin login failed');
  }

  static Future<Map<String, dynamic>> adminSeed({
    required String password,
    required String phone,
    required String seedSecret,
    String fullName = 'Baari Admin',
    String? email,
  }) async {
    final res = await _postJson('/admin/seed', {
      'password': password,
      'phone': phone, 'fullName': fullName, 'seedSecret': seedSecret,
      if (email != null) 'email': email,
    });
    return _decodeResponse(res, 'Seed failed');
  }

  static Future<Map<String, dynamic>> adminGetStats() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/admin/stats'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load stats');
  }

  // Users
  static Future<Map<String, dynamic>> adminGetUsers({
    int page = 1, int limit = 20, String search = '', String role = '',
    String? dateFrom, String? dateTo,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/users').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (search.isNotEmpty) 'search': search,
      if (role.isNotEmpty) 'role': role,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load users');
  }

  static Future<Map<String, dynamic>> adminGetUser(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/admin/users/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load user');
  }

  static Future<Map<String, dynamic>> adminGetUserBookings(
    String id, {
    int page = 1,
    int limit = 20,
    String status = '',
    String? dateFrom,
    String? dateTo,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/users/$id/bookings').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (status.isNotEmpty) 'status': status,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load user bookings');
  }

  static Future<void> adminUpdateUser(String id, Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/users/$id'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update user');
  }

  static Future<void> adminDeleteUser(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/users/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete user');
  }

  static Future<Map<String, dynamic>> adminSetSubscription(
    String userId,
    String plan, {
    int? durationDays,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$userId/subscription'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'plan': plan,
        if (durationDays != null) 'durationDays': durationDays,
      }),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update subscription');
  }

  static Future<Map<String, dynamic>> adminCancelSubscription(String userId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/users/$userId/subscription'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to cancel subscription');
  }

  // Salons
  static Future<Map<String, dynamic>> adminGetSalons({
    int page = 1, int limit = 20, String search = '', String status = '',
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/salons').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load salons');
  }

  static Future<Map<String, dynamic>> adminGetSalonBookings(
    String id, {
    int page = 1,
    int limit = 20,
    String status = '',
    String? dateFrom,
    String? dateTo,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/salons/$id/bookings').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (status.isNotEmpty) 'status': status,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load salon bookings');
  }

  static Future<Map<String, dynamic>> adminGetSalon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/admin/salons/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load salon');
  }

  static Future<Map<String, dynamic>> adminApproveSalon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/salons/$id/approve'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to approve salon');
  }

  static Future<Map<String, dynamic>> adminRejectSalon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/salons/$id/reject'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to reject salon');
  }

  static Future<Map<String, dynamic>> adminCreateSalon(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/salons'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create salon');
  }

  static Future<void> adminUpdateSalon(String id, Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/salons/$id'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update salon');
  }

  static Future<void> adminDeleteSalon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/salons/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete salon');
  }

  static Future<Map<String, dynamic>> adminBanUser(
    String id, {
    double? durationHours,
    required String reason,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$id/ban'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'durationHours': durationHours, 'reason': reason}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to ban user');
  }

  static Future<Map<String, dynamic>> adminUnbanUser(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$id/unban'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to unban user');
  }

  static Future<Map<String, dynamic>> adminBanSalon(
    String id, {
    double? durationHours,
    required String reason,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/salons/$id/ban'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'durationHours': durationHours, 'reason': reason}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to ban salon');
  }

  static Future<Map<String, dynamic>> adminUnbanSalon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/salons/$id/unban'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to unban salon');
  }

  static Future<Map<String, dynamic>> adminGetComplaints({
    int page = 1, int limit = 20, String type = '', String status = '',
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/complaints').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (type.isNotEmpty) 'type': type,
      if (status.isNotEmpty) 'status': status,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load complaints');
  }

  static Future<void> submitComplaint({
    required String type,
    required String targetId,
    required String reason,
    String description = '',
    String severity = 'minor',
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/users/complaints'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'targetId': targetId,
        'reason': reason,
        'description': description,
        'severity': severity,
      }),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to submit complaint');
  }

  // Bookings
  static Future<Map<String, dynamic>> adminGetBookings({
    int page = 1, int limit = 20, String search = '', String status = '',
    String? dateFrom, String? dateTo,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/bookings').replace(queryParameters: {
      'page': '$page', 'limit': '$limit',
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load bookings');
  }

  static Future<Map<String, dynamic>> adminCreateOffer(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/offers'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create offer');
  }

  static Future<Map<String, dynamic>> adminUpdateOffer(String id, Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/offers/$id'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update offer');
  }

  static Future<Map<String, dynamic>> adminAssignCoupon(String couponId, List<String> userIds) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/coupons/$couponId/assign'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'userIds': userIds}),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to assign coupon');
  }

  static Future<List<dynamic>> adminGetCouponAssignees(String couponId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/admin/coupons/$couponId/assignees'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load assignees');
  }

  static Future<void> adminRemoveCouponAssignee(String couponId, String userId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/coupons/$couponId/assignees/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to remove assignee');
  }

  static Future<Map<String, dynamic>> adminCreateSubAdmin(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/sub-admins'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create sub-admin');
  }

  static Future<List<dynamic>> adminListSubAdmins() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/admin/sub-admins'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load sub-admins');
  }

  static Future<void> adminUpdateSubAdminPermissions(String id, Map<String, dynamic> permissions) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/sub-admins/$id/permissions'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'permissions': permissions}),
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to update permissions');
  }

  static Future<void> adminDeleteSubAdmin(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/sub-admins/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete sub-admin');
  }

  // Offers (admin)
  static Future<Map<String, dynamic>> adminGetOffers({int page = 1, int limit = 30}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/offers').replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load offers');
  }

  static Future<void> adminDeleteOffer(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/offers/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete offer');
  }

  // Coupons (admin)
  static Future<Map<String, dynamic>> adminGetCoupons({int page = 1, int limit = 50}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/admin/coupons').replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load coupons');
  }

  static Future<Map<String, dynamic>> adminCreateCoupon(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/admin/coupons'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to create coupon');
  }

  static Future<void> adminToggleCoupon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/coupons/$id/toggle'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to toggle coupon');
  }

  static Future<void> adminDeleteCoupon(String id) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/admin/coupons/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete coupon');
  }

  static List<dynamic> _decodeListResponse(http.Response res, String fallback) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(res.statusCode, (body['message'] as String?) ?? fallback);
  }

  // ================= WALK-IN QUEUE =================

  static Future<List<dynamic>> getWalkIns({String? date}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/salons/my/walk-ins${date != null ? '?date=$date' : ''}');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load walk-ins');
  }

  /// Professional: look up a customer by phone for offline booking auto-fill.
  /// Returns `{ name, phone }` on success, null when no account exists.
  /// Throws [ApiException] (403) when the phone belongs to a professional or
  /// to the requesting salon itself — the caller should surface the message.
  static Future<Map<String, dynamic>?> lookupUserByPhone(String phone) async {
    final token = await getToken();
    if (token == null) return null;
    final res = await http.get(
      Uri.parse('$baseUrl/users/lookup-by-phone?phone=${Uri.encodeComponent(phone)}'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 404) return null;
    // 403 = professional account or own salon phone — surface the message
    Map<String, dynamic>? body;
    try { body = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
    final msg = body?['message'] as String? ?? 'This phone number cannot be used for booking';
    throw ApiException(res.statusCode, msg, body);
  }

  static Future<Map<String, dynamic>> addWalkIn(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/my/walk-ins'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to add walk-in');
  }

  static Future<Map<String, dynamic>> updateWalkIn(String walkInId, Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/walk-ins/$walkInId'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update walk-in');
  }

  static Future<void> deleteWalkIn(String walkInId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/walk-ins/$walkInId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete walk-in');
  }

  // ================= SCHEDULE GAPS =================

  static Future<Map<String, dynamic>> getScheduleGaps({String? date}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final uri = Uri.parse('$baseUrl/salons/my/schedule/gaps${date != null ? '?date=$date' : ''}');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load schedule gaps');
  }

  // ================= INVENTORY =================

  static Future<List<dynamic>> getInventory() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/salons/my/inventory'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load inventory');
  }

  static Future<Map<String, dynamic>> addInventoryItem(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/my/inventory'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to add inventory item');
  }

  static Future<Map<String, dynamic>> updateInventoryItem(String itemId, Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/inventory/$itemId'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update inventory item');
  }

  static Future<void> deleteInventoryItem(String itemId) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.delete(
      Uri.parse('$baseUrl/salons/my/inventory/$itemId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    _decodeResponse(res, 'Failed to delete inventory item');
  }

  // ================= ATTENDANCE =================

  static Future<List<dynamic>> getAttendance({int? month, int? year}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final res = await http.get(
      Uri.parse('$baseUrl/salons/my/attendance?month=$m&year=$y'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load attendance');
  }

  static Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> body) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.post(
      Uri.parse('$baseUrl/salons/my/attendance'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to mark attendance');
  }

  // ================= PAYROLL =================

  static Future<List<dynamic>> getPayrollSummary({int? month, int? year}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final res = await http.get(
      Uri.parse('$baseUrl/salons/my/payroll?month=$m&year=$y'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeListResponse(res, 'Failed to load payroll');
  }

  static Future<Map<String, dynamic>> updateBarberPayroll(
    String barberId,
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.patch(
      Uri.parse('$baseUrl/salons/my/barbers/$barberId/payroll'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to update payroll settings');
  }

  // ================= ANALYTICS =================

  static Future<Map<String, dynamic>> getSalonAnalytics({String period = '30d'}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Not authenticated');
    final res = await http.get(
      Uri.parse('$baseUrl/salons/my/analytics?period=$period'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(requestTimeout);
    return _decodeResponse(res, 'Failed to load analytics');
  }
}
