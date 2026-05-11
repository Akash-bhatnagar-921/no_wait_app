class SalonOnboardingModel {
  // STEP 1
  String salonName = '';
  String address = '';
  String city = '';
  String pincode = '';
  String state = '';
  String landmark = '';
  String contactNumber = '';
  String shopEmail = '';

  // STEP 2
  List<String> services = [];
  List<String> amenities = [];
  String description = '';

  // STEP 3
  List<Map<String, dynamic>> barbers = [];
}