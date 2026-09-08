import 'package:cloud_firestore/cloud_firestore.dart';

class LiveRatesData {
  final double gold24KTrading;
  final double gold22KJewellery;
  final double gold18KJewellery;
  final double oldGoldTrading;
  final double repairingSampleGold;
  final double diamond18KJewellery;
  final double diamond22KJewellery;
  final double diamondTrading;
  final double stoneTrading;
  final double pureSilverTrading;
  final double oldSilverTrading;
  final double silver925;
  final double platinum;
  final double oldPlatinum;
  final double alloys;
  final Map<String, dynamic> diamondRates; // Nest map: { clarity: { color: rate } }

  LiveRatesData({
    required this.gold24KTrading,
    required this.gold22KJewellery,
    required this.gold18KJewellery,
    required this.oldGoldTrading,
    required this.repairingSampleGold,
    required this.diamond18KJewellery,
    required this.diamond22KJewellery,
    required this.diamondTrading,
    required this.stoneTrading,
    required this.pureSilverTrading,
    required this.oldSilverTrading,
    required this.silver925,
    required this.platinum,
    required this.oldPlatinum,
    required this.alloys,
    required this.diamondRates,
  });

  factory LiveRatesData.fromDoc(Map<String, dynamic> data) {
    return LiveRatesData(
      gold24KTrading: (data['gold24KTrading'] as num?)?.toDouble() ?? 0.0,
      gold22KJewellery: (data['gold22'] as num?)?.toDouble() ?? (data['gold22KJewellery'] as num?)?.toDouble() ?? 0.0,
      gold18KJewellery: (data['gold18'] as num?)?.toDouble() ?? (data['gold18KJewellery'] as num?)?.toDouble() ?? 0.0,
      oldGoldTrading: (data['oldGoldTrading'] as num?)?.toDouble() ?? 0.0,
      repairingSampleGold: (data['repairingSampleGold'] as num?)?.toDouble() ?? 0.0,
      diamond18KJewellery: (data['diamond18KJewellery'] as num?)?.toDouble() ?? 0.0,
      diamond22KJewellery: (data['diamond22KJewellery'] as num?)?.toDouble() ?? 0.0,
      diamondTrading: (data['diamondTrading'] as num?)?.toDouble() ?? 0.0,
      stoneTrading: (data['stoneTrading'] as num?)?.toDouble() ?? 0.0,
      pureSilverTrading: (data['silver'] as num?)?.toDouble() ?? (data['pureSilverTrading'] as num?)?.toDouble() ?? 0.0,
      oldSilverTrading: (data['oldSilverTrading'] as num?)?.toDouble() ?? 0.0,
      silver925: (data['silver925'] as num?)?.toDouble() ?? 0.0,
      platinum: (data['platinum'] as num?)?.toDouble() ?? 0.0,
      oldPlatinum: (data['oldPlatinum'] as num?)?.toDouble() ?? 0.0,
      alloys: (data['alloys'] as num?)?.toDouble() ?? 0.0,
      diamondRates: (data['diamondRates'] as Map?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as Map?)?.map(
                    (ck, cv) => MapEntry(
                      ck.toString(),
                      (cv as num?)?.toDouble() ?? 0.0,
                    ),
                  ) ??
                  {},
            ),
          ) ??
          {},
    );
  }

  factory LiveRatesData.empty() {
    return LiveRatesData(
      gold24KTrading: 0.0,
      gold22KJewellery: 0.0,
      gold18KJewellery: 0.0,
      oldGoldTrading: 0.0,
      repairingSampleGold: 0.0,
      diamond18KJewellery: 0.0,
      diamond22KJewellery: 0.0,
      diamondTrading: 0.0,
      stoneTrading: 0.0,
      pureSilverTrading: 0.0,
      oldSilverTrading: 0.0,
      silver925: 0.0,
      platinum: 0.0,
      oldPlatinum: 0.0,
      alloys: 0.0,
      diamondRates: {},
    );
  }

  Map<String, dynamic> toDocMap() {
    return {
      'gold24KTrading': gold24KTrading,
      'gold22KJewellery': gold22KJewellery,
      'gold18KJewellery': gold18KJewellery,
      'oldGoldTrading': oldGoldTrading,
      'repairingSampleGold': repairingSampleGold,
      'diamond18KJewellery': diamond18KJewellery,
      'diamond22KJewellery': diamond22KJewellery,
      'diamondTrading': diamondTrading,
      'stoneTrading': stoneTrading,
      'pureSilverTrading': pureSilverTrading,
      'oldSilverTrading': oldSilverTrading,
      'silver925': silver925,
      'platinum': platinum,
      'oldPlatinum': oldPlatinum,
      'alloys': alloys,
      'diamondRates': diamondRates,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class LiveRateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of live rates data from Firestore.
  Stream<LiveRatesData> getLiveRatesStream() {
    return _firestore
        .collection('settings')
        .doc('rates')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return LiveRatesData.fromDoc(snapshot.data()!);
      }
      return LiveRatesData.empty();
    });
  }

  /// One-off read of live rates from Firestore.
  Future<LiveRatesData> getLiveRates() async {
    final doc = await _firestore.collection('settings').doc('rates').get();
    if (doc.exists && doc.data() != null) {
      return LiveRatesData.fromDoc(doc.data()!);
    }
    return LiveRatesData.empty();
  }
}
