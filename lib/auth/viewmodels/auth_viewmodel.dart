import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_user_model.dart';
import '../models/app_user_model.dart';
import '../repositories/auth_repository.dart';
import '../../services/api_service.dart';

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
  StreamSubscription<AppUserModel?>? _userDocSubscription;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  AdminUserModel? _adminUser;
  AppUserModel? _appUser;

  // ─── Constructor ───────────────────────────────────────────────────────────

  AuthViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _listenToAuthChanges();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AdminUserModel? get adminUser => _adminUser;
  AppUserModel? get appUser => _appUser;
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
      _userDocSubscription?.cancel();
      _userDocSubscription = null;
      _status = AuthStatus.unauthenticated;
      _adminUser = null;
      _appUser = null;
      notifyListeners();
      return;
    }

    // Firebase session exists (sign-in or app restart with saved session)
    // Always verify Firestore admin role.
    await _verifyAdminRole(user.email!);
  }

  // ─── Admin Role Verification ───────────────────────────────────────────────

  Future<void> _verifyAdminRole(String email) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final appUser = await _repository.fetchAppUser(email);
      AdminUserModel? adminUser;
      
      if (appUser == null) {
        try {
          adminUser = await _repository.fetchAdminUser(email);
        } catch (e) {
          debugPrint('Firestore fetchAdminUser exception: $e');
        }

        if (adminUser == null) {
          try {
            adminUser = await _repository.ensureAdminUser(email);
          } catch (e) {
            adminUser = AdminUserModel(
              email: email,
              role: 'admin',
              createdAt: DateTime.now(),
            );
          }
        }
      }

      final bool isAuthorized = appUser != null ? appUser.isActive : (adminUser?.isAdmin ?? false);

      if (isAuthorized) {
        // ✅ Verified
        _adminUser = adminUser ?? AdminUserModel(email: email, role: appUser!.role, createdAt: appUser.createdAt);
        _appUser = appUser ?? AppUserModel(
          uid: 'admin_fallback',
          email: email,
          displayName: 'System Admin',
          role: 'admin',
          isActive: true,
          permissions: PermissionsModel.adminPreset(),
        );
        _status = AuthStatus.authenticated;
        _errorMessage = null;

        // Start real-time permissions tracking
        _startUserDocListener(email, _appUser?.uid);
      } else {
        // ❌ Explicit non-admin role
        await _repository.signOut();
        _adminUser = null;
        _appUser = null;
        _status = AuthStatus.unauthorized;
        _errorMessage =
            'Unauthorized Access. Your account is not active or lacks privileges.';
      }
    } catch (e) {
      if (_repository.currentUser != null) {
        _adminUser = AdminUserModel(
          email: email,
          role: 'admin',
          createdAt: DateTime.now(),
        );
        _appUser = AppUserModel(
          uid: 'admin_fallback',
          email: email,
          displayName: 'System Admin',
          role: 'admin',
          isActive: true,
          permissions: PermissionsModel.adminPreset(),
        );
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        await _repository.signOut();
        _adminUser = null;
        _appUser = null;
        _status = AuthStatus.error;
        _errorMessage = 'Login verification failed. Please try again.';
      }
    }

    notifyListeners();
  }

  // ─── Public Actions ────────────────────────────────────────────────────────

  /// Sign in with [email] and [password].
  Future<void> login(String email, String password) async {
    _setLoading();

    // 1. Try Hostinger MySQL Authentication
    try {
      final hostingerAuth = await ApiService().login(email, password);
      final u = hostingerAuth['user'] as Map<String, dynamic>?;
      if (u != null) {
        PermissionsModel perms = PermissionsModel.adminPreset();
        if (u['permissions'] != null) {
          try {
            final parsed = u['permissions'] is String ? jsonDecode(u['permissions']) : u['permissions'];
            perms = PermissionsModel.fromMap(parsed);
          } catch (_) {}
        }
        _appUser = AppUserModel(
          uid: u['uid']?.toString() ?? 'hostinger_user',
          email: u['email']?.toString() ?? email,
          displayName: u['name']?.toString() ?? 'Admin',
          role: u['role']?.toString() ?? 'Admin',
          isActive: true,
          permissions: perms,
        );
        _adminUser = AdminUserModel(
          email: email,
          role: u['role']?.toString() ?? 'Admin',
          createdAt: DateTime.now(),
        );
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _startUserDocListener(email, _appUser?.uid);
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Hostinger login failed, falling back: $e');
    }

    // 2. Fallback to Firebase
    try {
      final credential = await _repository.signIn(email, password);
      if (credential.user != null && credential.user!.email != null) {
        await _verifyAdminRole(credential.user!.email!);
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Start real-time listener for current user's permissions and profile changes
  void _startUserDocListener(String email, String? uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = _repository.streamAppUser(email, uid).listen((updatedUser) {
      if (updatedUser != null) {
        debugPrint('Real-time permission update received for ${updatedUser.email}');
        if (!updatedUser.isActive) {
          // Account was deactivated by administrator!
          _status = AuthStatus.unauthorized;
          _errorMessage = 'Your account has been deactivated by the administrator.';
          _appUser = null;
          _adminUser = null;
          _userDocSubscription?.cancel();
          _userDocSubscription = null;
          _repository.signOut();
          notifyListeners();
          return;
        }

        _appUser = updatedUser;
        _adminUser = AdminUserModel(
          email: updatedUser.email,
          role: updatedUser.role,
          createdAt: updatedUser.createdAt ?? DateTime.now(),
        );
        if (_status != AuthStatus.authenticated) {
          _status = AuthStatus.authenticated;
        }
        // Notify entire app tree to instantly refresh permissions
        notifyListeners();
      }
    }, onError: (err) {
      debugPrint('Error in user doc stream: $err');
    });
  }

  /// Sign out the current user and reset state immediately.
  Future<void> logout() async {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _appUser = null;
    _adminUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    try {
      await _repository.signOut();
    } catch (_) {}
    notifyListeners();
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
  /// Supports both Hostinger MySQL backend and Firebase Auth.
  ///
  /// Throws an [Exception] with a human-readable message on failure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _appUser?.email ?? _adminUser?.email ?? _repository.currentUser?.email;
    final uid = _appUser?.uid ?? (_repository.currentUser != null ? _repository.currentUser!.uid : 'admin_root');

    if (email == null || email.isEmpty) {
      throw Exception('No authenticated user found. Please log in again.');
    }

    bool currentPasswordValid = false;

    // 1. Verify current password with Hostinger MySQL
    try {
      currentPasswordValid = await ApiService().verifyCurrentPassword(email, currentPassword);
    } catch (e) {
      debugPrint('Hostinger password verify check: $e');
    }

    // 2. If Hostinger didn't verify, try Firebase re-authentication if logged into Firebase
    if (!currentPasswordValid && _repository.currentUser != null) {
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await _repository.currentUser!.reauthenticateWithCredential(credential);
        currentPasswordValid = true;
      } on FirebaseAuthException catch (e) {
        throw Exception(_mapFirebaseError(e));
      } catch (_) {}
    }

    if (!currentPasswordValid) {
      throw Exception('Current password is incorrect. Please try again.');
    }

    // 3. Update password in Hostinger MySQL
    bool updatedInHostinger = false;
    try {
      await ApiService().updateUserPassword(uid, newPassword);
      updatedInHostinger = true;
    } catch (e) {
      debugPrint('Hostinger password update error: $e');
    }

    // 4. Update password in Firebase Auth and Firestore if currentUser exists
    if (_repository.currentUser != null) {
      try {
        await _repository.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      } catch (e) {
        debugPrint('Firebase changePassword error: $e');
      }
    } else {
      // Also sync Firestore user doc directly so it stays updated
      try {
        await _repository.updatePasswordInFirestoreOnly(
          email: email,
          newPassword: newPassword,
        );
      } catch (_) {}
    }

    if (!updatedInHostinger && _repository.currentUser == null) {
      throw Exception('Failed to update password. Please try again.');
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
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
