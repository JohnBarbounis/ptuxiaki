class OliveGrove {
  final String id; // Μοναδικό Αναγνωριστικό Ελαιώνα
  final String name; // Όνομα Ελαιώνα
  final double area; // Στρέμματα
  final double? lat; // Γεωγραφικό Πλάτος
  final double? lng; // Γεωγραφικό Μήκος

  OliveGrove({
    required this.id,
    required this.name,
    required this.area,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'area': area, 'lat': lat, 'lng': lng};
  }

  factory OliveGrove.fromMap(Map<String, dynamic> map) {
    return OliveGrove(
      id: map['id'],
      name: map['name'],
      area: (map['area'] ?? 0.0).toDouble(),
      lat: map['lat'],
      lng: map['lng'],
    );
  }
}
