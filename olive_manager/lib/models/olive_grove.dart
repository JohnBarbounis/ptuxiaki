// Αρχείο: lib/models/olive_grove.dart

class OliveGrove {
  final String id;
  final String name;
  final int treeCount;

  OliveGrove({required this.id, required this.name, required this.treeCount});

  // Μετατροπή του αντικειμένου σε Map (για εγγραφή στη βάση)
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'treeCount': treeCount};
  }

  // Δημιουργία αντικειμένου από Map (για ανάγνωση από τη βάση)
  factory OliveGrove.fromMap(Map<String, dynamic> map) {
    return OliveGrove(
      id: map['id'],
      name: map['name'],
      treeCount: map['treeCount'],
    );
  }
}
