// Αρχείο: lib/screens/add_grove_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // ΝΕΟ IMPORT
import '../models/olive_grove.dart';
import '../services/database_helper.dart';

class AddGroveScreen extends StatefulWidget {
  const AddGroveScreen({super.key});

  @override
  State<AddGroveScreen> createState() => _AddGroveScreenState();
}

class _AddGroveScreenState extends State<AddGroveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  // Μεταβλητή για να δείχνουμε ότι ψάχνουμε το GPS
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // Βοηθητική συνάρτηση για το Fallback
  void _showFallbackMessage(String message) {
    if (mounted) {
      setState(() => _isLocating = false); // Κρύβουμε το loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange[800], // Πορτοκαλί χρώμα προειδοποίησης
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'ΟΚ',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Συνάρτηση που βρίσκει το GPS του χρήστη με ασφάλεια (Fallback)
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Ελέγχουμε αν το GPS της συσκευής είναι ανοιχτό
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showFallbackMessage(
          'Το GPS είναι κλειστό. Παρακαλώ βάλτε την πινέζα χειροκίνητα.',
        );
        return;
      }

      // 2. Ελέγχουμε τα δικαιώματα
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Ο χρήστης πάτησε "Άρνηση" (Fallback)
          _showFallbackMessage(
            'Δεν δόθηκε άδεια τοποθεσίας. Επιλέξτε το χωράφι χειροκίνητα.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Ο χρήστης έχει μπλοκάρει μόνιμα την τοποθεσία (Fallback)
        _showFallbackMessage(
          'Τα δικαιώματα τοποθεσίας είναι απενεργοποιημένα. Επιλέξτε χειροκίνητα.',
        );
        return;
      }

      // 3. Παίρνουμε την ακριβή τοποθεσία
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // Ζητάμε υψηλή ακρίβεια
      );

      // 4. Μετακινούμε τον χάρτη εκεί και βάζουμε αυτόματα την πινέζα!
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });

        _mapController.move(_selectedLocation!, 15.0);
      }
    } catch (e) {
      // Αν γίνει οποιοδήποτε άλλο σφάλμα (π.χ. χάθηκε το σήμα)
      _showFallbackMessage(
        'Αποτυχία εύρεσης τοποθεσίας. Παρακαλώ βάλτε την πινέζα χειροκίνητα.',
      );
    }
  }

  Future<void> _saveGrove() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Παρακαλώ επιλέξτε τοποθεσία στον χάρτη!'),
          ),
        );
        return;
      }

      final newGrove = OliveGrove(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        area: double.parse(_areaController.text),
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
      );

      await DatabaseHelper.instance.insertGrove(newGrove);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Νέο Χωράφι', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Όνομα Χωραφιού',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Εισάγετε όνομα' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(
                      labelText: 'Στρέμματα',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Εισάγετε στρέμματα' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Πατήστε στον χάρτη για αλλαγή πινέζας:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Ο Χάρτης
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(
                        38.2462,
                        21.7351,
                      ), // Προεπιλογή αν αργήσει το GPS
                      initialZoom: 6.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.olive_manager',
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Δείχνει ένα κυκλάκι φόρτωσης όσο ψάχνει το GPS
                  if (_isLocating)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  onPressed: _saveGrove,
                  child: const Text(
                    'Αποθήκευση Χωραφιού',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
