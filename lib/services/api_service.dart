import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../barber_setup/models/salon_onboarding_model.dart';
import '../models/user_profile_model.dart';

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
    defaultValue: "http://192.168.29.19:3000",
  );
  static const Duration requestTimeout = Duration(seconds: 15);
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
  }) async {
    final response = await _postJson(
      '/auth/register',
      {
        "phone": phone,
        "role": role,
        "name": name,
        "email": email,
        "age": age,
        "gender": gender,
        "hasAcceptedTerms": true,
      },
    );

    return _decodeResponse(response, 'Registration failed');
  }

  // ================= Login =================

  static Future<Map<String, dynamic>> login({required String phone}) async {
    print("Inside login function");
    print("URL: $baseUrl/auth/login");
    final response = await _postJson('/auth/login', {"phone": phone});
    print('API cliekd');
    print(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception('Login failed');
    }

    loginData = jsonDecode(response.body);
    print('loginData$loginData');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> requestLoginOtp({
    required String phone,
  }) async {
    final response = await _postJson(
      '/auth/login/request-otp',
      {"phone": phone},
    );

    return _decodeResponse(response, 'Failed to send OTP');
  }

  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _postJson(
      '/auth/login/verify-otp',
      {"phone": phone, "otp": otp},
    );

    final data = _decodeResponse(response, 'OTP verification failed');
    loginData = data;
    return data;
  }

  // ================= TOKEN =================

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', token);

    print('TOKEN SAVED => ${prefs.getString('access_token')}');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('access_token');

    print('TOKEN FETCHED => $token');

    return token;
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

  // ================= LOGOUT =================

  static Future<void> logout() async {
    // accessToken = null;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
  }

  // ================= CREATE SALON =================

  static Future<Map<String, dynamic>> createSalon({
    required SalonOnboardingModel salonData,
  }) async {
    final token = await getToken();
    print("TOKEN: $token");

    final response = await http.post(
      Uri.parse('$baseUrl/salons'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "salonName": salonData.salonName,
        "address": salonData.address,
        "city": salonData.city,
        "pincode": salonData.pincode,
        "state": salonData.state,
        "landmark": salonData.landmark,
        "contactNumber": salonData.contactNumber,
        "shopEmail": salonData.shopEmail,

        "services": salonData.services,
        "amenities": salonData.amenities,

        "barbers": salonData.barbers,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<UserProfileModel?> getProfile() async {
    // final prefs = await SharedPreferences.getInstance();

    final token = await ApiService.getToken();

    print("PROFILE TOKEN => $token");

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

    print(response.body);

    final data = jsonDecode(response.body);

    return UserProfileModel.fromJson(data);
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
}
