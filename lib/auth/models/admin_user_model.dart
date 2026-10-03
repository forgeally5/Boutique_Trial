/// Represents an Admin user profile from Hostinger DB.
class AdminUserModel {
  final String email;
  final String role;
  final DateTime? createdAt;

  const AdminUserModel({
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AdminUserModel.fromMap(Map<String, dynamic> map) {
    return AdminUserModel(
      email: (map['email'] as String?)?.trim() ?? '',
      role: (map['role'] as String?)?.trim() ?? '',
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : (map['created_at'] != null || map['createdAt'] != null
              ? DateTime.tryParse((map['created_at'] ?? map['createdAt']).toString())
              : null),
    );
  }

  /// Returns [true] if the user's role is exactly "admin" (case-insensitive).
  bool get isAdmin => role.toLowerCase() == 'admin';

  @override
  String toString() =>
      'AdminUserModel(email: $email, role: $role, createdAt: $createdAt)';
}
