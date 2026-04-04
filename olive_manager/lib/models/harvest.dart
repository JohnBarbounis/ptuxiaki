class Harvest {
  final String id;
  final String groveId;
  final double oilVolume;
  final double olivesWeight;
  final double acidity;
  final double pricePerUnit; // Νέο πεδίο
  final DateTime date;

  Harvest({
    required this.id,
    required this.groveId,
    required this.oilVolume,
    required this.olivesWeight,
    required this.acidity,
    required this.pricePerUnit,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groveId': groveId,
      'oilVolume': oilVolume,
      'olivesWeight': olivesWeight,
      'acidity': acidity,
      'pricePerUnit': pricePerUnit,
      'date': date.toIso8601String(),
    };
  }

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'],
      groveId: map['groveId'],
      oilVolume: (map['oilVolume'] as num).toDouble(),
      olivesWeight: (map['olivesWeight'] as num).toDouble(),
      acidity: (map['acidity'] as num).toDouble(),
      pricePerUnit: (map['pricePerUnit'] as num? ?? 0.0).toDouble(),
      date: DateTime.parse(map['date']),
    );
  }
}
