import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ΝΕΟ: Για την αποθήκευση της κατάστασης του Tutorial

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
  late TextEditingController _treeController;

  List<LatLng> _selectedBoundaries = [];
  final MapController _mapController = MapController();
  bool _isLocating = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingGrove?.name ?? '',
    );
    _areaController = TextEditingController(
      text: widget.existingGrove?.area.toString() ?? '',
    );
    _treeController = TextEditingController(
      text: widget.existingGrove?.treeCount.toString() ?? '',
    );

    if (widget.existingGrove != null) {
      _selectedBoundaries = widget.existingGrove!.getPolygon();
    }

    // ΝΕΟ: Ελέγχουμε αν είναι η 1η φορά μόλις χτιστεί η οθόνη
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  // --- ΝΕΑ ΛΟΓΙΚΗ: TUTORIAL ONBOARDING ---
  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    // Διαβάζουμε αν το έχει δει. Αν δεν υπάρχει η ρύθμιση, επιστρέφει false (άρα είναι η 1η φορά)
    bool hasSeenTutorial = prefs.getBool('has_seen_map_tutorial') ?? false;

    if (!hasSeenTutorial) {
      _showMapTutorial(); // Δείχνουμε το tutorial
      await prefs.setBool(
        'has_seen_map_tutorial',
        true,
      ); // Το αποθηκεύουμε για να μην ξαναβγεί
    }
  }

  void _showMapTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.school, color: Colors.blue, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Πώς λειτουργεί ο Χάρτης;',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTutorialStep(
              Icons.touch_app,
              Colors.green,
              'Σχεδιασμός με το χέρι',
              'Πατήστε στις γωνίες του χωραφιού σας στον χάρτη για να δημιουργήσετε τα σύνορα.',
            ),
            const SizedBox(height: 12),
            _buildTutorialStep(
              Icons.my_location,
              Colors.orange,
              'Περπάτημα με GPS',
              'Είστε στο χωράφι; Χρησιμοποιήστε την πορτοκαλί "Πινέζα" για να βάζετε σημεία περπατώντας!',
            ),
            const SizedBox(height: 12),
            _buildTutorialStep(
              Icons.auto_awesome,
              Colors.purple,
              'Αυτόματος Υπολογισμός',
              'Τα στρέμματα υπολογίζονται αυτόματα μόλις κλείσετε το σχήμα (3+ σημεία)!',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ΤΟ ΚΑΤΑΛΑΒΑ!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialStep(
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // ----------------------------------------

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
    return area / 1000.0;
  }

  void _updateAreaLive() {
    double calcArea = _calculatePolygonAreaInStremmata(_selectedBoundaries);
    if (calcArea > 0) {
      _areaController.text = calcArea.toStringAsFixed(2);
    } else if (_selectedBoundaries.isEmpty) {
      _areaController.text = '';
    }
  }

  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedBoundaries.add(latlng);
      _updateAreaLive();
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

  Future<Position> _getGpsPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Το GPS είναι κλειστό.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Αρνηθήκατε την άδεια.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Οι άδειες είναι κλειδωμένες.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      Position position = await _getGpsPosition();
      LatLng pos = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = pos);
      _mapController.move(pos, 17.5);
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
        _currentLocation = currentPos;
        _selectedBoundaries.add(currentPos);
        _updateAreaLive();
        _mapController.move(currentPos, 17.5);
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
        treeCount: int.tryParse(_treeController.text) ?? 0,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
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

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(
                      labelText: 'Στρέμματα',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.square_foot),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => value!.isEmpty ? 'Κενό' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _treeController,
                    decoration: const InputDecoration(
                      labelText: 'Δέντρα',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.park),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Κενό' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- ΝΕΟ WIDGET: ΤΟ TIP / ΟΔΗΓΟΣ ΧΑΡΤΗ ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber[700], size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'TIP: Ζωγραφίστε τα σύνορα στον χάρτη για να υπολογιστούν τα στρέμματα αυτόματα!',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _showMapTutorial, // Ξανανοίγει το tutorial αν το πατήσει
                    child: const Text(
                      'ΟΔΗΓΙΕΣ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Ο ΧΑΡΤΗΣ ΜΑΣ ---
            Container(
              height: 380,
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
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          ..._selectedBoundaries.map(
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
                          ),
                          if (_currentLocation != null)
                            Marker(
                              point: _currentLocation!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

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
                ],
              ),
            ),

            const SizedBox(height: 32),

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
