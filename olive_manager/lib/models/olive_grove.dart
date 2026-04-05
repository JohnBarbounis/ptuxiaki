import 'dart:convert';
import 'package:latlong2/latlong.dart';

class OliveGrove {
  final String id;
  final String name;
  final double area;
  final double? lat;
  final double? lng;
  final String? boundaries; // ΝΕΟ: Εδώ θα σώζονται τα σύνορα του πολυγώνου

  OliveGrove({
    required this.id,
    required this.name,
    required this.area,
    this.lat,
    this.lng,
    this.boundaries,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'area': area,
      'lat': lat,
      'lng': lng,
      'boundaries': boundaries, // ΝΕΟ
    };
  }

  factory OliveGrove.fromMap(Map<String, dynamic> map) {
    return OliveGrove(
      id: map['id'],
      name: map['name'],
      area: (map['area'] as num).toDouble(),
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      boundaries: map['boundaries'], // ΝΕΟ
    );
  }

  // ΝΕΑ ΣΥΝΑΡΤΗΣΗ: Μετατρέπει το JSON κείμενο της βάσης σε λίστα σημείων για τον χάρτη
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
