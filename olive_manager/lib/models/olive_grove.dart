import 'dart:convert';
import 'package:latlong2/latlong.dart';

class OliveGrove {
  final String id;
  final String name;
  final double area;
  final int treeCount; // ΝΕΟ ΠΕΔΙΟ
  final double? lat;
  final double? lng;
  final String? boundaries;

  OliveGrove({
    required this.id,
    required this.name,
    required this.area,
    required this.treeCount, // Απαιτούμενο
    this.lat,
    this.lng,
    this.boundaries,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'area': area,
      'treeCount': treeCount, // Στη βάση
      'lat': lat,
      'lng': lng,
      'boundaries': boundaries,
    };
  }

  factory OliveGrove.fromMap(Map<String, dynamic> map) {
    return OliveGrove(
      id: map['id'],
      name: map['name'],
      area: (map['area'] as num).toDouble(),
      treeCount: map['treeCount'] ?? 0, // Αν είναι παλιό χωράφι, βάλε 0
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      boundaries: map['boundaries'],
    );
  }

  List<LatLng> getPolygon() {
    if (boundaries == null || boundaries!.isEmpty) return [];
    try {
      List<dynamic> decoded = jsonDecode(boundaries!);
      return decoded.map((p) => LatLng(p['lat'], p['lng'])).toList();
    } catch (e) {
      return [];
    }
  }
}
