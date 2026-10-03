import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/admin_user_model.dart';
import '../models/app_user_model.dart';
import '../repositories/auth_repository.dart';
import '../../services/api_service.dart';

// ─── Auth Status Enum ────────────────────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  unauthorized,
  error,
}

// ─── AuthViewModel ────────────────────────────────────────────────────────────

/// ViewModel for Hostinger MySQL authentication and real-time permission sync.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;
  Timer? _userPollTimer;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  AdminUserModel? _adminUser;
  AppUserModel? _appUser;

  static const String _sessionBoxName = 'user_session_box';

  AuthViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _tryAutoLogin();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AdminUserModel? get adminUser => _adminUser;
  AppUserModel? get appUser => _appUser;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ─── Auto Login ────────────────────────────────────────────────────────────

  Future<void> _tryAutoLogin() async {
    try {
      if (!Hive.isBoxOpen(_sessionBoxName)) {
        await Hive.openBox(_sessionBoxName);
      }
      final box = Hive.box(_sessionBoxName);
      final rawUser = box.get('session_user');
      final token = box.get('session_token') as String?;

      if (rawUser != null && token != null) {
        final Map<String, dynamic> userMap = Map<String, dynamic>.from(jsonDecode(rawUser as String));
        final restoredUser = AppUserModel.fromMap(userMap, userMap['uid'] ?? 'restored_user');

        if (restoredUser.isActive) {
          ApiService().setAuthToken(token);
          _appUser = restoredUser;
          _adminUser = AdminUserModel(
            email: restoredUser.email,
            role: restoredUser.role,
            createdAt: restoredUser.createdAt,
          );
          _status = AuthStatus.authenticated;
          _startUserPolling(restoredUser.email);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Auto login check note: $e');
    }

    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Public Actions ────────────────────────────────────────────────────────

  /// Sign in with [email] and [password] via Hostinger MySQL API.
  Future<void> login(String email, String password) async {
    _setLoading();

    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    try {
      final hostingerAuth = await ApiService().login(cleanEmail, cleanPassword);
      final u = hostingerAuth['user'] as Map<String, dynamic>?;
      final token = hostingerAuth['token']?.toString();

      if (u != null) {
        final isUserActive = u['is_active'] == 1 || u['is_active'] == true || u['isActive'] == true;
        if (!isUserActive) {
          _status = AuthStatus.unauthorized;
          _errorMessage = 'Your account has been deactivated. Please contact an admin.';
          notifyListeners();
          return;
        }

        PermissionsModel perms = PermissionsModel.adminPreset();
        if (u['permissions'] != null) {
          try {
            final parsed = u['permissions'] is String ? jsonDecode(u['permissions']) : u['permissions'];
            if (parsed is Map<String, dynamic>) {
              perms = PermissionsModel.fromMap(parsed);
            }
          } catch (_) {}
        } else if (u['role']?.toString().toLowerCase() != 'admin') {
          perms = PermissionsModel.salesmanPreset();
        }

        _appUser = AppUserModel(
          uid: u['uid']?.toString() ?? 'user_${u['id'] ?? 1}',
          email: u['email']?.toString() ?? cleanEmail,
          displayName: u['name']?.toString() ?? u['displayName']?.toString() ?? 'User',
          role: u['role']?.toString() ?? 'Salesman',
          isActive: true,
          permissions: perms,
        );

        _adminUser = AdminUserModel(
          email: cleanEmail,
          role: _appUser!.role,
          createdAt: DateTime.now(),
        );

        // Save session locally for persistent login
        _saveSessionLocally(_appUser!, token);

        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _startUserPolling(cleanEmail);
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Hostinger login error: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
      return;
    }

    _setError('Invalid email or password. Please try again.');
  }

  /// Start periodic polling (every 10s) to keep permissions and account status live
  void _startUserPolling(String email) {
    _userPollTimer?.cancel();
    _userPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_status != AuthStatus.authenticated || _appUser == null) return;
      try {
        final updatedUser = await _repository.fetchAppUser(email);
        if (updatedUser != null) {
          if (!updatedUser.isActive) {
            _status = AuthStatus.unauthorized;
            _errorMessage = 'Your account has been deactivated by the administrator.';
            _appUser = null;
            _adminUser = null;
            _userPollTimer?.cancel();
            _clearSessionLocally();
            notifyListeners();
            return;
          }

          _appUser = updatedUser;
          _adminUser = AdminUserModel(
            email: updatedUser.email,
            role: updatedUser.role,
            createdAt: updatedUser.createdAt ?? DateTime.now(),
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('User polling check error: $e');
      }
    });
  }

  /// Sign out the current user and clear local session state.
  Future<void> logout() async {
    _userPollTimer?.cancel();
    _userPollTimer = null;
    _appUser = null;
    _adminUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    ApiService().setAuthToken(null);
    await _clearSessionLocally();
    notifyListeners();
  }

  /// Re-authenticate with [currentPassword], then update to [newPassword] on Hostinger DB.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _appUser?.email ?? _adminUser?.email;
    final uid = _appUser?.uid ?? 'admin_root';

    if (email == null || email.isEmpty) {
      throw Exception('No authenticated user found. Please log in again.');
    }

    // Verify current password with Hostinger MySQL
    bool currentPasswordValid = false;
    try {
      currentPasswordValid = await ApiService().verifyCurrentPassword(email, currentPassword);
    } catch (e) {
      debugPrint('Hostinger password verify check: $e');
    }

    if (!currentPasswordValid) {
      throw Exception('Current password is incorrect. Please try again.');
    }

    // Update password in Hostinger MySQL (PHP hashes password with BCRYPT)
    await ApiService().updateUserPassword(uid, newPassword);
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error || _status == AuthStatus.unauthorized) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Local Session Helpers ─────────────────────────────────────────────────

  Future<void> _saveSessionLocally(AppUserModel user, String? token) async {
    try {
      if (!Hive.isBoxOpen(_sessionBoxName)) {
        await Hive.openBox(_sessionBoxName);
      }
      final box = Hive.box(_sessionBoxName);
      await box.put('session_user', jsonEncode(user.toMap()));
      if (token != null) await box.put('session_token', token);
    } catch (e) {
      debugPrint('Error saving session locally: $e');
    }
  }

  Future<void> _clearSessionLocally() async {
    try {
      if (!Hive.isBoxOpen(_sessionBoxName)) {
        await Hive.openBox(_sessionBoxName);
      }
      final box = Hive.box(_sessionBoxName);
      await box.delete('session_user');
      await box.delete('session_token');
    } catch (e) {
      debugPrint('Error clearing session locally: $e');
    }
  }

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

  @override
  void dispose() {
    _userPollTimer?.cancel();
    super.dispose();
  }
}
