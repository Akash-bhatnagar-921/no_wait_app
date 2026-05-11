class UserProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String role;
  final int? age;
  final String? gender;
  final String? createdAt;

  UserProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    this.age,
    this.gender,
    this.createdAt
  });

  factory UserProfileModel.fromJson(
      Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      age: json['age'],
      gender: json['gender'],
      createdAt: json['createdAt']
    );
  }
}