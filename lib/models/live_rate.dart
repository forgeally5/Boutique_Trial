class LiveRate {
  final String id;
  final String name;
  final String description;
  final double ratePerGram;
  final double purityFineness; // e.g. 0.583 for 14K
  final String unit; // '/g' or similar

  LiveRate({
    required this.id,
    required this.name,
    required this.description,
    required this.ratePerGram,
    required this.purityFineness,
    this.unit = '/g',
  });

  LiveRate copyWith({
    String? id,
    String? name,
    String? description,
    double? ratePerGram,
    double? purityFineness,
    String? unit,
  }) {
    return LiveRate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ratePerGram: ratePerGram ?? this.ratePerGram,
      purityFineness: purityFineness ?? this.purityFineness,
      unit: unit ?? this.unit,
    );
  }
}
