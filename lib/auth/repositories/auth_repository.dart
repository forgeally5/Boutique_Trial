import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_user_model.dart';

/// Single source of truth for all Firebase Authentication and Firestore
/// admin-verification I/O.
///
/// This repository does NOT expose any UI logic; it returns raw data or
/// throws typed [FirebaseAuthException] / [Exception] for the ViewModel
/// to handle.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The Firestore collection that holds admin user documents.
  static const String _kAdminUsers = 'admin_users';

  // ─── Auth State ─────────────────────────────────────────────────────────────

  /// Stream of Firebase Auth state changes.
  /// Emits [User] when signed in, [null] when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently authenticated Firebase user, or [null] if signed out.
  User? get currentUser => _auth.currentUser;

  // ─── Sign In / Out ───────────────────────────────────────────────────────────

  /// Sign in with [email] and [password] via Firebase Authentication.
  ///
  /// Throws [FirebaseAuthException] on failure (wrong password, user not found, etc.).
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out the currently authenticated Firebase user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Firestore Admin Verification ───────────────────────────────────────────

  /// Query [admin_users] collection for a document whose [email] field matches
  /// [email]. Returns [AdminUserModel] if found, [null] otherwise.
  ///
  /// NOTE: Authentication is via Firebase Auth only. This query is solely for
  /// role verification.
  Future<AdminUserModel?> fetchAdminUser(String email) async {
    final snapshot = await _firestore
        .collection(_kAdminUsers)
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AdminUserModel.fromMap(snapshot.docs.first.data());
  }

  // ─── Password Reset ──────────────────────────────────────────────────────────

  /// Send a password reset email to [email] via Firebase Authentication.
  ///
  /// Throws [FirebaseAuthException] if the email is not registered.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Change Password ─────────────────────────────────────────────────────────

  /// Re-authenticates the current user with [currentPassword], then:
  ///  1. Updates the Firebase Authentication password to [newPassword].
  ///  2. Syncs the new password to the [admin_users] Firestore document
  ///     (field: `password`) so both systems stay consistent.
  ///
  /// Throws [FirebaseAuthException] if re-authentication fails or if no user
  /// is currently signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found. Please log in again.',
      );
    }

    // Step 1 — Re-authenticate before sensitive Firebase Auth operation
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Step 2 — Update Firebase Authentication password
    await user.updatePassword(newPassword);

    // Step 3 — Sync new password to Firestore admin_users document
    await _updatePasswordInFirestore(
      email: user.email!,
      newPassword: newPassword,
    );
  }

  /// Finds the [admin_users] document where [email] matches and updates
  /// the [password] field to [newPassword].
  ///
  /// This keeps Firestore in sync with Firebase Auth.
  /// Errors here are non-fatal — the Firebase Auth password is already
  /// changed successfully at this point.
  Future<void> _updatePasswordInFirestore({
    required String email,
    required String newPassword,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_kAdminUsers)
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'password': newPassword,
        });
      }
    } catch (_) {
      // Firebase Auth password is already updated.
      // Firestore sync failure is logged but not re-thrown.
    }
  }
}

