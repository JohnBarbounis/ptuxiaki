class Harvest {
  final String id;
  final String groveId;
  final double oilVolume;
  final double olivesWeight;
  final double acidity;
  final double pricePerUnit; // ΝΕΟ ΠΕΔΙΟ
  final DateTime date;

  Harvest({
    required this.id,
    required this.groveId,
    required this.oilVolume,
    required this.olivesWeight,
    required this.acidity,
    required this.pricePerUnit, // ΝΕΟ
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groveId': groveId,
      'oilVolume': oilVolume,
      'olivesWeight': olivesWeight,
      'acidity': acidity,
      'pricePerUnit': pricePerUnit, // ΝΕΟ
      'date': date.toIso8601String(),
    };
  }

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'],
      groveId: map['groveId'],
      oilVolume: map['oilVolume'],
      olivesWeight: map['olivesWeight'],
      acidity: map['acidity'],
      pricePerUnit: map['pricePerUnit'] ?? 0.0,
      date: DateTime.parse(map['date']),
    );
  }
}
