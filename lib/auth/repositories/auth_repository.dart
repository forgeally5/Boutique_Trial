import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../models/admin_user_model.dart';
import '../models/app_user_model.dart';

/// Source of truth for authentication and user verification via Hostinger MySQL APIs.
class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<AppUserModel?> fetchAppUser(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final users = await _apiService.getAllUsers();
      for (final u in users) {
        if (u is Map<String, dynamic>) {
          final uEmail = (u['email'] ?? '').toString().trim().toLowerCase();
          if (uEmail == cleanEmail) {
            return AppUserModel.fromMap(u, u['uid']?.toString() ?? 'user_${u['id']}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching app user: $e');
    }
    return null;
  }

  Future<AdminUserModel?> fetchAdminUser(String email) async {
    final appUser = await fetchAppUser(email);
    if (appUser != null) {
      return AdminUserModel(
        email: appUser.email,
        role: appUser.role,
        createdAt: appUser.createdAt,
      );
    }
    return null;
  }

  Future<void> changePassword({
    required String uid,
    required String newPassword,
  }) async {
    await _apiService.updateUserPassword(uid, newPassword);
  }
}
