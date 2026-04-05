import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final List<LatLng> initialBoundaries;

  const MapPickerScreen({super.key, this.initialBoundaries = const []});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  List<LatLng> boundaries = [];
  final MapController _mapController = MapController();
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    boundaries = List.from(widget.initialBoundaries);
  }

  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      boundaries.add(latlng);
    });
  }

  void _undoLastPoint() {
    if (boundaries.isNotEmpty) {
      setState(() {
        boundaries.removeLast();
      });
    }
  }

  void _clearMap() {
    setState(() {
      boundaries.clear();
    });
  }

  // ΣΥΝΑΡΤΗΣΗ 1: Απλή μετακίνηση του χάρτη (Απαιτεί Ίντερνετ για να δεις τον χάρτη)
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

  // ΣΥΝΑΡΤΗΣΗ 2 (ΤΟ OFFLINE FALLBACK): Καρφώνει πινέζα στο ακριβές σημείο που στέκεσαι!
  Future<void> _addCurrentLocationAsPin() async {
    setState(() => _isLocating = true);
    try {
      Position position = await _getGpsPosition();
      LatLng currentPos = LatLng(position.latitude, position.longitude);

      setState(() {
        boundaries.add(currentPos);
        // Μετακινούμε και τον χάρτη εκεί για να βλέπει την πινέζα που μόλις μπήκε
        _mapController.move(currentPos, 17.5);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Προστέθηκε γωνία βάσει GPS!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // Βοηθητική συνάρτηση για τον έλεγχο αδειών και λήψη GPS (Κοινή και για τα 2 κουμπιά)
  Future<Position> _getGpsPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Το GPS είναι κλειστό.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw Exception('Αρνηθήκατε την άδεια.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Οι άδειες είναι κλειδωμένες.');
    }

    // Το forceLocationManager βοηθάει κάποιες φορές σε Android συσκευές χωρίς Google Play Services
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Σχεδιασμός Συνόρων'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Αναίρεση',
            onPressed: _undoLastPoint,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Καθαρισμός',
            onPressed: _clearMap,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: boundaries.isNotEmpty
                  ? boundaries.first
                  : const LatLng(35.3387, 25.1442),
              initialZoom: 15.0,
              onTap: _handleTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.olive_manager',
              ),
              if (boundaries.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundaries,
                      color: Colors.green.withOpacity(0.4),
                      borderColor: Colors.green[900]!,
                      borderStrokeWidth: 3.0,
                      //  isFilled: true,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: boundaries
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

          // ΤΑ ΚΟΥΜΠΙΑ ΔΕΞΙΑ (GPS & Fallback)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                // Κουμπί 1: Απλή Μετακίνηση Χάρτη (Το παλιό)
                FloatingActionButton(
                  heroTag: 'move_map_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _isLocating ? null : _moveToCurrentLocation,
                  tooltip: 'Εστίαση στη θέση μου',
                  child: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 12),

                // Κουμπί 2 (ΤΟ ΝΕΟ FALLBACK): Καρφώνει Πινέζα
                FloatingActionButton.extended(
                  heroTag: 'add_pin_btn',
                  backgroundColor: Colors.orange[800],
                  onPressed: _isLocating ? null : _addCurrentLocationAsPin,
                  icon: const Icon(Icons.add_location_alt, color: Colors.white),
                  label: const Text(
                    'Πινέζα Εδώ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Οδηγίες στο κάτω μέρος
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.touch_app, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Πατήστε στον χάρτη ή χρησιμοποιήστε το πορτοκαλί κουμπί αν περπατάτε στο χωράφι!',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: () {
                          if (boundaries.length < 3) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Προσθέστε τουλάχιστον 3 σημεία!',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, boundaries);
                        },
                        child: const Text(
                          'ΑΠΟΘΗΚΕΥΣΗ ΣΥΝΟΡΩΝ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
