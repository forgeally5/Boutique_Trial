import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/models/app_user_model.dart';
import '../auth/models/system_quota_model.dart';
import '../auth/models/override_request_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _usersRef => _firestore.collection('users');
  DocumentReference get _quotaRef => _firestore.collection('system_config').doc('quotas');
  CollectionReference get _overrideRequestsRef => _firestore.collection('override_requests');

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------

  Stream<List<AppUserModel>> streamUsers() {
    return _usersRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppUserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<AppUserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (doc.exists) {
      return AppUserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> createUser(AppUserModel user) async {
    AppUserModel userToSave = user;
    try {
      if (user.plainPassword != null && user.plainPassword!.isNotEmpty) {
        final FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'TemporaryApp_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final cred = await tempAuth.createUserWithEmailAndPassword(
          email: user.email,
          password: user.plainPassword!,
        );
        
        userToSave = AppUserModel(
          uid: cred.user!.uid,
          email: user.email,
          displayName: user.displayName,
          role: user.role,
          isActive: user.isActive,
          plainPassword: user.plainPassword,
          permissions: user.permissions,
          createdAt: user.createdAt,
        );
        await tempApp.delete();
      }
    } catch (e) {
      debugPrint('Error creating auth user: $e');
    }
    
    await _usersRef.doc(userToSave.uid).set(userToSave.toMap());
  }

  Future<void> updateUser(AppUserModel user) async {
    await _usersRef.doc(user.uid).update(user.toMap());
  }

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _usersRef.doc(uid).update({'isActive': isActive});
  }

  Future<void> deleteUser(String uid) async {
    await _usersRef.doc(uid).delete();
  }

  // ---------------------------------------------------------------------------
  // QUOTAS
  // ---------------------------------------------------------------------------

  Stream<SystemQuotaModel> streamQuotas() {
    return _quotaRef.snapshots().map((doc) {
      if (doc.exists) {
        return SystemQuotaModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return const SystemQuotaModel(
        maxSalesmen: 0,
        currentSalesmen: 0,
      );
    });
  }

  Future<void> updateQuotas({required int maxSalesmen}) async {
    await _quotaRef.set({
      'maxSalesmen': maxSalesmen,
    }, SetOptions(merge: true));
  }
  
  Future<void> incrementActiveUsersCount(String role, int change) async {
    if (role.toLowerCase() == 'salesman') {
      await _quotaRef.update({'currentSalesmen': FieldValue.increment(change)});
    }
  }

  // ---------------------------------------------------------------------------
  // OVERRIDE REQUESTS
  // ---------------------------------------------------------------------------

  Stream<List<OverrideRequestModel>> streamPendingRequests() {
    return _overrideRequestsRef
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return OverrideRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> createOverrideRequest(OverrideRequestModel request) async {
    await _overrideRequestsRef.add(request.toMap());
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await _overrideRequestsRef.doc(requestId).update({'status': status});
  }
}
