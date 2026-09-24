import 'package:cloud_firestore/cloud_firestore.dart';
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
    // NOTE: In a real app, creating the FirebaseAuth user account would happen here 
    // or via a Cloud Function to avoid signing out the admin. 
    // Here we focus on the Firestore document creation.
    await _usersRef.doc(user.uid).set(user.toMap());
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
