// Αρχείο: lib/models/olive_grove.dart

class OliveGrove {
  final String id;
  final String name;
  final double area; // Στρέμματα (αντί για treeCount)
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
      area: map['area'],
      lat: map['lat'],
      lng: map['lng'],
    );
  }
}
