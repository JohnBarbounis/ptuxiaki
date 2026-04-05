import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/olive_grove.dart';
import '../services/database_helper.dart';

class AddGroveScreen extends StatefulWidget {
  final OliveGrove? existingGrove;

  const AddGroveScreen({super.key, this.existingGrove});

  @override
  State<AddGroveScreen> createState() => _AddGroveScreenState();
}

class _AddGroveScreenState extends State<AddGroveScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _areaController;

  // Μεταβλητές Χάρτη
  List<LatLng> _selectedBoundaries = [];
  final MapController _mapController = MapController();
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingGrove?.name ?? '',
    );
    _areaController = TextEditingController(
      text: widget.existingGrove?.area.toString() ?? '',
    );

    if (widget.existingGrove != null) {
      _selectedBoundaries = widget.existingGrove!.getPolygon();
    }
  }

  // --- ΜΑΘΗΜΑΤΙΚΟΣ ΑΛΓΟΡΙΘΜΟΣ (Σφαιρικό Εμβαδόν) ---
  double _calculatePolygonAreaInStremmata(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    const double earthRadius = 6378137.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      double lat1 = points[i].latitude * math.pi / 180;
      double lng1 = points[i].longitude * math.pi / 180;
      double lat2 = points[j].latitude * math.pi / 180;
      double lng2 = points[j].longitude * math.pi / 180;
      area += (lng2 - lng1) * (2 + math.sin(lat1) + math.sin(lat2));
    }
    area = (area * earthRadius * earthRadius / 2.0).abs();
    return area / 1000.0; // Μετατροπή τ.μ. σε Στρέμματα
  }

  // --- ΖΩΝΤΑΝΗ ΕΝΗΜΕΡΩΣΗ ΣΤΡΕΜΜΑΤΩΝ ---
  void _updateAreaLive() {
    double calcArea = _calculatePolygonAreaInStremmata(_selectedBoundaries);
    if (calcArea > 0) {
      _areaController.text = calcArea.toStringAsFixed(2);
    } else if (_selectedBoundaries.isEmpty) {
      _areaController.text = ''; // Καθαρίζει αν σβήσουμε όλα τα σημεία
    }
  }

  // --- ΛΕΙΤΟΥΡΓΙΕΣ ΧΑΡΤΗ ---
  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedBoundaries.add(latlng);
      _updateAreaLive(); // Υπολογισμός με κάθε νέο πάτημα!
    });
  }

  void _undoLastPoint() {
    if (_selectedBoundaries.isNotEmpty) {
      setState(() {
        _selectedBoundaries.removeLast();
        _updateAreaLive();
      });
    }
  }

  void _clearMap() {
    setState(() {
      _selectedBoundaries.clear();
      _updateAreaLive();
    });
  }

  // --- ΛΕΙΤΟΥΡΓΙΕΣ GPS ---
  Future<Position> _getGpsPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Το GPS είναι κλειστό.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw Exception('Αρνηθήκατε την άδεια.');
    }
    if (permission == LocationPermission.deniedForever)
      throw Exception('Οι άδειες είναι κλειδωμένες.');

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      Position position = await _getGpsPosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 17.5);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _addCurrentLocationAsPin() async {
    setState(() => _isLocating = true);
    try {
      Position position = await _getGpsPosition();
      LatLng currentPos = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedBoundaries.add(currentPos);
        _updateAreaLive(); // Αυτόματος υπολογισμός και εδώ!
        _mapController.move(currentPos, 17.5);
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showError(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
  }

  // --- ΑΠΟΘΗΚΕΥΣΗ ΣΤΗ ΒΑΣΗ ---
  void _saveGrove() async {
    if (_formKey.currentState!.validate()) {
      String? boundariesJson;
      double? centerLat;
      double? centerLng;

      if (_selectedBoundaries.isNotEmpty) {
        boundariesJson = jsonEncode(
          _selectedBoundaries
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        );
        centerLat = _selectedBoundaries.first.latitude;
        centerLng = _selectedBoundaries.first.longitude;
      }

      String safeAreaText = _areaController.text.replaceAll(',', '.');

      final grove = OliveGrove(
        id:
            widget.existingGrove?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        area: double.parse(safeAreaText),
        lat: centerLat,
        lng: centerLng,
        boundaries: boundariesJson,
      );

      if (widget.existingGrove == null) {
        await DatabaseHelper.instance.insertGrove(grove);
      } else {
        await DatabaseHelper.instance.updateGrove(grove);
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingGrove == null ? 'Νέο Χωράφι' : 'Επεξεργασία Χωραφιού',
        ),
        backgroundColor: Colors.green[700],
      ),
      // Χρησιμοποιούμε ListView για να μπορεί να κάνει scroll η φόρμα
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. ΟΝΟΜΑ ΧΩΡΑΦΙΟΥ
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Όνομα Χωραφιού (π.χ. Κάτω Ελιές)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nature),
              ),
              validator: (value) => value!.isEmpty ? 'Εισάγετε όνομα' : null,
            ),
            const SizedBox(height: 16),

            // 2. ΣΤΡΕΜΜΑΤΑ
            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: 'Στρέμματα',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.square_foot),
                suffixText: 'Στρέμματα',
                helperText: _selectedBoundaries.isNotEmpty
                    ? 'Το εμβαδόν υπολογίστηκε από τον χάρτη (επεξεργάσιμο)'
                    : null,
                helperStyle: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Εισάγετε στρέμματα' : null,
            ),
            const SizedBox(height: 24),

            // 3. ΕΝΣΩΜΑΤΩΜΕΝΟΣ ΧΑΡΤΗΣ
            const Text(
              'Σχεδιασμός Συνόρων (Προαιρετικό)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 380, // Αρκετό ύψος για να σχεδιάσει άνετα
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedBoundaries.length >= 3
                      ? Colors.green
                      : Colors.blueGrey,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  // Το Layer του χάρτη
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedBoundaries.isNotEmpty
                          ? _selectedBoundaries.first
                          : const LatLng(35.3387, 25.1442),
                      initialZoom: 15.0,
                      onTap: _handleTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.olive_manager',
                      ),
                      if (_selectedBoundaries.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _selectedBoundaries,
                              color: Colors.green.withOpacity(0.4),
                              borderColor: Colors.green[900]!,
                              borderStrokeWidth: 3.0,
                              //isFilled: true,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: _selectedBoundaries
                            .map(
                              (point) => Marker(
                                point: point,
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),

                  // Κουμπιά Επεξεργασίας (Πάνω Δεξιά)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'undo_btn',
                          backgroundColor: Colors.white,
                          tooltip: 'Αναίρεση τελευταίου',
                          onPressed: _undoLastPoint,
                          child: const Icon(Icons.undo, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'clear_btn',
                          backgroundColor: Colors.white,
                          tooltip: 'Καθαρισμός',
                          onPressed: _clearMap,
                          child: const Icon(
                            Icons.delete_sweep,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Κουμπιά GPS (Κάτω Δεξιά)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'gps_move_btn',
                          backgroundColor: Colors.white,
                          tooltip: 'Η τοποθεσία μου',
                          onPressed: _isLocating
                              ? null
                              : _moveToCurrentLocation,
                          child: _isLocating
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.extended(
                          heroTag: 'gps_pin_btn',
                          backgroundColor: Colors.orange[800],
                          onPressed: _isLocating
                              ? null
                              : _addCurrentLocationAsPin,
                          icon: const Icon(
                            Icons.add_location_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Πινέζα Εδώ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ενημερωτικό Banner (Κάτω Αριστερά)
                  if (_selectedBoundaries.isEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Πατήστε στον χάρτη',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. ΚΟΥΜΠΙ ΑΠΟΘΗΚΕΥΣΗΣ
            ElevatedButton(
              onPressed: _saveGrove,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ΑΠΟΘΗΚΕΥΣΗ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
