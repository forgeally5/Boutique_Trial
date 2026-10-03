import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/models/app_user_model.dart';
import '../auth/models/system_quota_model.dart';
import '../auth/models/override_request_model.dart';
import 'api_service.dart';

class UserManagementService {
  final ApiService _apiService = ApiService();

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------

  Stream<List<AppUserModel>> streamUsers() async* {
    while (true) {
      try {
        final usersRaw = await _apiService.getAllUsers();
        final users = usersRaw.map((u) {
          final map = Map<String, dynamic>.from(u as Map);
          return AppUserModel.fromMap(map, map['uid']?.toString() ?? 'user_${map['id']}');
        }).toList();
        yield users;
      } catch (e) {
        debugPrint('Error streaming users: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<AppUserModel?> getUser(String uid) async {
    try {
      final usersRaw = await _apiService.getAllUsers();
      for (final u in usersRaw) {
        if (u is Map) {
          final map = Map<String, dynamic>.from(u);
          if (map['uid']?.toString() == uid) {
            return AppUserModel.fromMap(map, uid);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  Future<void> createUser(AppUserModel user) async {
    final payload = {
      'uid': user.uid,
      'name': user.displayName,
      'email': user.email,
      'password': user.plainPassword ?? 'Boutique@123',
      'role': user.role,
      'permissions': user.permissions.toMap(),
    };
    await _apiService.createUser(payload);
  }

  Future<void> updateUser(AppUserModel user) async {
    final url = Uri.parse('${_apiService.baseUrl}/auth.php?action=update');
    final payload = {
      'uid': user.uid,
      'name': user.displayName,
      'role': user.role,
      'is_active': user.isActive ? 1 : 0,
      'permissions': user.permissions.toMap(),
      if (user.plainPassword != null && user.plainPassword!.isNotEmpty)
        'password': user.plainPassword,
    };
    await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
  }

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    final url = Uri.parse('${_apiService.baseUrl}/auth.php?action=update');
    final payload = {
      'uid': uid,
      'is_active': isActive ? 1 : 0,
    };
    await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
  }

  Future<void> deleteUser(String uid) async {
    final url = Uri.parse('${_apiService.baseUrl}/auth.php?action=delete&uid=${Uri.encodeComponent(uid)}');
    await http.post(url);
  }

  // ---------------------------------------------------------------------------
  // QUOTAS
  // ---------------------------------------------------------------------------

  Stream<SystemQuotaModel> streamQuotas() async* {
    while (true) {
      try {
        final setting = await _apiService.getSetting('quotas');
        if (setting is Map<String, dynamic>) {
          yield SystemQuotaModel.fromMap(setting);
        } else {
          yield const SystemQuotaModel(maxSalesmen: 10, currentSalesmen: 1);
        }
      } catch (_) {
        yield const SystemQuotaModel(maxSalesmen: 10, currentSalesmen: 1);
      }
      await Future.delayed(const Duration(seconds: 6));
    }
  }

  Future<void> updateQuotas({required int maxSalesmen}) async {
    final setting = await _apiService.getSetting('quotas');
    final Map<String, dynamic> data = setting is Map<String, dynamic> ? Map<String, dynamic>.from(setting) : {};
    data['maxSalesmen'] = maxSalesmen;
    await _apiService.saveSetting('quotas', data);
  }
  
  Future<void> incrementActiveUsersCount(String role, int change) async {
    if (role.toLowerCase() == 'salesman') {
      final setting = await _apiService.getSetting('quotas');
      final Map<String, dynamic> data = setting is Map<String, dynamic> ? Map<String, dynamic>.from(setting) : {};
      final curr = (data['currentSalesmen'] as num?)?.toInt() ?? 0;
      data['currentSalesmen'] = curr + change;
      await _apiService.saveSetting('quotas', data);
    }
  }

  // ---------------------------------------------------------------------------
  // OVERRIDE REQUESTS
  // ---------------------------------------------------------------------------

  Stream<List<OverrideRequestModel>> streamPendingRequests() async* {
    while (true) {
      try {
        final setting = await _apiService.getSetting('override_requests');
        if (setting is List) {
          final list = setting.map((e) => OverrideRequestModel.fromMap(Map<String, dynamic>.from(e as Map), e['id'] ?? '')).where((r) => r.status == 'pending').toList();
          yield list;
        } else {
          yield [];
        }
      } catch (_) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> createOverrideRequest(OverrideRequestModel request) async {
    final setting = await _apiService.getSetting('override_requests');
    final List list = setting is List ? List.from(setting) : [];
    list.add(request.toMap());
    await _apiService.saveSetting('override_requests', list);
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    final setting = await _apiService.getSetting('override_requests');
    if (setting is List) {
      final list = List.from(setting);
      for (var item in list) {
        if (item is Map && item['id'] == requestId) {
          item['status'] = status;
        }
      }
      await _apiService.saveSetting('override_requests', list);
    }
  }
}
