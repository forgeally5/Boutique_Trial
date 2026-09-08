import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a document from the Firestore [admin_users] collection.
///
/// Fields in Firestore: createdAt, email, password, role.
///
/// IMPORTANT: [password] is stored in Firestore for legacy/reference purposes
/// only. Authentication is performed exclusively through Firebase Authentication.
/// This app never reads or uses the [password] field for auth.
class AdminUserModel {
  /// The admin's email address (matches FirebaseAuth.currentUser.email).
  final String email;

  /// The role assigned to this user (must be "admin" for access).
  final String role;

  /// Timestamp when this document was created in Firestore.
  final DateTime? createdAt;

  const AdminUserModel({
    required this.email,
    required this.role,
    this.createdAt,
  });

  /// Deserialise from a Firestore document map.
  factory AdminUserModel.fromMap(Map<String, dynamic> map) {
    return AdminUserModel(
      email: (map['email'] as String?)?.trim() ?? '',
      role: (map['role'] as String?)?.trim() ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Returns [true] if the user's role is exactly "admin" (case-insensitive).
  bool get isAdmin => role.toLowerCase() == 'admin';

  @override
  String toString() =>
      'AdminUserModel(email: $email, role: $role, createdAt: $createdAt)';
}
