// Αρχείο: lib/models/harvest.dart

class Harvest {
  final String id;
  final String groveId; // Ξένο κλειδί: Σε ποιο χωράφι έγινε η συγκομιδή
  final DateTime date;
  final double olivesWeight; // Κιλά ελιάς (π.χ. 1500)
  final double oilVolume; // Κιλά/Λίτρα λαδιού (π.χ. 300)
  final double acidity; // Οξύτητα (π.χ. 0.3)

  Harvest({
    required this.id,
    required this.groveId,
    required this.date,
    required this.olivesWeight,
    required this.oilVolume,
    required this.acidity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groveId': groveId,
      'date': date.toIso8601String(),
      'olivesWeight': olivesWeight,
      'oilVolume': oilVolume,
      'acidity': acidity,
    };
  }

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'],
      groveId: map['groveId'],
      date: DateTime.parse(map['date']),
      olivesWeight: map['olivesWeight'],
      oilVolume: map['oilVolume'],
      acidity: map['acidity'],
    );
  }
}
