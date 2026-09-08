import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_user_model.dart';
import '../repositories/auth_repository.dart';

// ─── Auth Status Enum ────────────────────────────────────────────────────────

/// Represents the authentication lifecycle states.
enum AuthStatus {
  /// App has just started; waiting for [authStateChanges] to emit.
  initial,

  /// An async operation is in progress.
  loading,

  /// User is authenticated AND verified as admin in Firestore.
  authenticated,

  /// No user is signed in (normal unauthenticated state).
  unauthenticated,

  /// User authenticated with Firebase but is NOT found in [admin_users]
  /// OR their [role] is not "admin". They have been signed out immediately.
  unauthorized,

  /// A recoverable error occurred (network, wrong password, etc.).
  error,
}

// ─── AuthViewModel ────────────────────────────────────────────────────────────

/// MVVM ViewModel for authentication, consumed by the UI via [Provider].
///
/// Responsibilities:
///  - Listen to Firebase Auth state changes for auto-login.
///  - Verify admin role in Firestore after every successful sign-in.
///  - Sign out immediately if the user is not an admin.
///  - Expose [login], [logout], [sendPasswordReset], [changePassword].
///  - Surface [status], [errorMessage], and [adminUser] to the UI.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  StreamSubscription<User?>? _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  AdminUserModel? _adminUser;

  // ─── Constructor ───────────────────────────────────────────────────────────

  AuthViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _listenToAuthChanges();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AdminUserModel? get adminUser => _adminUser;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ─── Auth State Listener ───────────────────────────────────────────────────

  void _listenToAuthChanges() {
    _authSubscription = _repository.authStateChanges.listen(
      _onAuthStateChanged,
      onError: (Object e) {
        _setError('Auth stream error. Please restart the app.');
      },
    );
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      // No Firebase session → always transition to unauthenticated.
      // This covers both explicit logout and session expiry.
      _status = AuthStatus.unauthenticated;
      _adminUser = null;
      notifyListeners();
      return;
    }

    // Firebase session exists (sign-in or app restart with saved session)
    // Always verify Firestore admin role.
    await _verifyAdminRole(user.email!);
  }

  // ─── Admin Role Verification ───────────────────────────────────────────────

  /// Query Firestore [admin_users], confirm [role == "admin"].
  /// Signs out immediately if verification fails.
  Future<void> _verifyAdminRole(String email) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final adminUser = await _repository.fetchAdminUser(email);

      if (adminUser != null && adminUser.isAdmin) {
        // ✅ Verified admin
        _adminUser = adminUser;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        // ❌ No doc found OR role != "admin" — sign out immediately
        await _repository.signOut();
        _adminUser = null;
        _status = AuthStatus.unauthorized;
        _errorMessage =
            'Unauthorized Access. You do not have administrator privileges.';
      }
    } on FirebaseAuthException catch (e) {
      await _repository.signOut();
      _adminUser = null;
      _status = AuthStatus.unauthorized;
      _errorMessage = _mapFirebaseError(e);
    } catch (_) {
      await _repository.signOut();
      _adminUser = null;
      _status = AuthStatus.unauthorized;
      _errorMessage =
          'Could not verify admin access. Please check your connection and try again.';
    }

    notifyListeners();
  }

  // ─── Public Actions ────────────────────────────────────────────────────────

  /// Sign in with [email] and [password].
  ///
  /// Flow:
  ///  1. Firebase Auth sign-in.
  ///  2. [_onAuthStateChanged] fires → [_verifyAdminRole] is called.
  ///  3. Status becomes [authenticated] or [unauthorized].
  Future<void> login(String email, String password) async {
    _setLoading();
    try {
      await _repository.signIn(email, password);
      // _onAuthStateChanged will drive the status from here.
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
    } catch (_) {
      _setError('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign out the current user and reset state.
  /// [AuthGate] will automatically navigate to [LoginView] once the
  /// [authStateChanges] stream emits null.
  Future<void> logout() async {
    // Do NOT set loading here — the stream handler must see a clean state
    // so it can transition to unauthenticated when Firebase emits null.
    await _repository.signOut();
  }

  /// Send a Firebase password reset email to [email].
  ///
  /// Throws an [Exception] with a human-readable message on failure.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    } catch (_) {
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  /// Re-authenticate with [currentPassword], then update to [newPassword].
  ///
  /// Throws an [Exception] with a human-readable message on failure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    } catch (_) {
      throw Exception('Failed to change password. Please try again.');
    }
  }

  /// Clear any displayed error and reset status to [unauthenticated].
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error ||
        _status == AuthStatus.unauthorized) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Maps [FirebaseAuthException.code] to user-friendly messages.
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'Please log in again before changing your password.';
      case 'weak-password':
        return 'New password is too weak. Use at least 6 characters.';
      case 'no-current-user':
        return e.message ?? 'No authenticated user found.';
      default:
        return 'Authentication failed (${e.code}). Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
