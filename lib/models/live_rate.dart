/// Live metal/stone rate model used by AdminState for pricing calculations.
class LiveRate {
  final String id;
  final String name;
  final String description;
  final double ratePerGram;
  final double purityFineness;

  const LiveRate({
    required this.id,
    required this.name,
    required this.description,
    required this.ratePerGram,
    required this.purityFineness,
  });

  LiveRate copyWith({
    String? id,
    String? name,
    String? description,
    double? ratePerGram,
    double? purityFineness,
  }) {
    return LiveRate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ratePerGram: ratePerGram ?? this.ratePerGram,
      purityFineness: purityFineness ?? this.purityFineness,
    );
  }
}

/// Flat data structure holding all live rates — used to read/write from Firestore.
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
  final Map<String, Map<String, double>> diamondRates;

  const LiveRatesData({
    this.gold24KTrading = 0.0,
    this.gold22KJewellery = 0.0,
    this.gold18KJewellery = 0.0,
    this.oldGoldTrading = 0.0,
    this.repairingSampleGold = 0.0,
    this.diamond18KJewellery = 0.0,
    this.diamond22KJewellery = 0.0,
    this.diamondTrading = 0.0,
    this.stoneTrading = 0.0,
    this.pureSilverTrading = 0.0,
    this.oldSilverTrading = 0.0,
    this.silver925 = 0.0,
    this.platinum = 0.0,
    this.oldPlatinum = 0.0,
    this.alloys = 0.0,
    this.diamondRates = const {},
  });

  factory LiveRatesData.fromMap(Map<String, dynamic> map) {
    Map<String, Map<String, double>> dRates = {};
    final raw = map['diamondRates'];
    if (raw is Map) {
      raw.forEach((clarity, colorMap) {
        if (colorMap is Map) {
          dRates[clarity.toString()] = colorMap.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
          );
        }
      });
    }
    return LiveRatesData(
      gold24KTrading: (map['gold24KTrading'] as num?)?.toDouble() ?? 0.0,
      gold22KJewellery: (map['gold22KJewellery'] as num?)?.toDouble() ?? 0.0,
      gold18KJewellery: (map['gold18KJewellery'] as num?)?.toDouble() ?? 0.0,
      oldGoldTrading: (map['oldGoldTrading'] as num?)?.toDouble() ?? 0.0,
      repairingSampleGold: (map['repairingSampleGold'] as num?)?.toDouble() ?? 0.0,
      diamond18KJewellery: (map['diamond18KJewellery'] as num?)?.toDouble() ?? 0.0,
      diamond22KJewellery: (map['diamond22KJewellery'] as num?)?.toDouble() ?? 0.0,
      diamondTrading: (map['diamondTrading'] as num?)?.toDouble() ?? 0.0,
      stoneTrading: (map['stoneTrading'] as num?)?.toDouble() ?? 0.0,
      pureSilverTrading: (map['pureSilverTrading'] as num?)?.toDouble() ?? 0.0,
      oldSilverTrading: (map['oldSilverTrading'] as num?)?.toDouble() ?? 0.0,
      silver925: (map['silver925'] as num?)?.toDouble() ?? 0.0,
      platinum: (map['platinum'] as num?)?.toDouble() ?? 0.0,
      oldPlatinum: (map['oldPlatinum'] as num?)?.toDouble() ?? 0.0,
      alloys: (map['alloys'] as num?)?.toDouble() ?? 0.0,
      diamondRates: dRates,
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
    };
  }
}
