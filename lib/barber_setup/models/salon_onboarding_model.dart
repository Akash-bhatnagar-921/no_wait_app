class SalonOnboardingModel {
  // STEP 1 — Salon details
  String salonName     = '';
  String address       = '';
  String city          = '';
  String pincode       = '';
  String state         = '';
  String landmark      = '';
  // Salon phone — this is the login credential for the professional app.
  // Each salon must have a unique phone number.
  String contactNumber = '';
  String shopEmail     = '';

  // STEP 1 — Business / Franchise owner (for ownership records only — NOT login)
  // The same owner can register multiple salons without any conflict.
  String ownerName  = '';
  String ownerPhone = '';

  // STEP 1 — Franchise
  bool   isFranchise   = false;
  String franchiseId   = '';   // UUID of selected existing franchise
  String franchiseName = '';   // name to create a new franchise if none selected

  // STEP 2
  List<String>             services    = [];
  List<String>             amenities   = [];
  String                   description = '';
  List<String>             workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String                   openingTime = '09:00';
  String                   closingTime = '21:00';

  // STEP 3
  List<Map<String, dynamic>> barbers = [];
}
