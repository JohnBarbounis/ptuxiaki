class Task {
  final String id;
  final String groveId; // Σε ποιο χωράφι ανήκει αυτή η εργασία
  final String title; // π.χ. "Ψεκασμός για Δάκο"
  final String type; // π.χ. "Ψεκασμός", "Κλάδεμα", "Λίπανση"
  final DateTime date; // Πότε έγινε
  final double cost; // Πόσο κόστισε
  final String notes; // Έξτρα σημειώσεις
  final String?
  nextTaskId; // ID της μελλοντικής επαναληπτικής εργασίας (αν υπάρχει)

  Task({
    required this.id,
    required this.groveId,
    required this.title,
    required this.type,
    required this.date,
    this.cost = 0.0,
    this.notes = '',
    this.nextTaskId,
  });

  // Μετατροπή σε Map για την SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groveId': groveId,
      'title': title,
      'type': type,
      // Στη βάση αποθηκεύουμε την ημερομηνία ως κείμενο (ISO 8601)
      'date': date.toIso8601String(),
      'cost': cost,
      'notes': notes,
      'nextTaskId': nextTaskId,
    };
  }

  // Δημιουργία από Map όταν διαβάζουμε από την SQLite
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      groveId: map['groveId'],
      title: map['title'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      cost: map['cost'],
      notes: map['notes'] ?? '',
      nextTaskId: map['nextTaskId'],
    );
  }
}
