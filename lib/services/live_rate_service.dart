import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_rate.dart';

/// Service that streams live metal/stone rates from Firestore.
/// Rates are stored in a single document: settings/rates
class LiveRateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<LiveRatesData> getLiveRatesStream() {
    return _firestore
        .collection('settings')
        .doc('rates')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return const LiveRatesData();
      }
      return LiveRatesData.fromMap(snap.data()!);
    });
  }

  Future<void> updateRates(Map<String, dynamic> updates) async {
    await _firestore
        .collection('settings')
        .doc('rates')
        .set(updates, SetOptions(merge: true));
  }
}
