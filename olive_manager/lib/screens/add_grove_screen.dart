import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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

  // Controller για το πεδίο της διεύθυνσης
  final _addressController = TextEditingController();

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  void _showFallbackMessage(String message) {
    if (mounted) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange[800],
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

  // Συντεταγμένες -> Διεύθυνση
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          String address =
              '${place.street ?? ''}, ${place.locality ?? place.subAdministrativeArea ?? ''}';
          address = address.replaceAll(RegExp(r'^, |, $'), '').trim();

          if (address.isEmpty || address == ',') {
            _addressController.text = 'Γνωστή τοποθεσία, χωρίς ακριβή οδό';
          } else {
            _addressController.text = address; // Βάζουμε τη διεύθυνση στο πεδίο
          }
        });
      }
    } catch (e) {
      setState(() {
        _addressController.text = 'Άγνωστη διεύθυνση';
      });
    }
  }

  //Διεύθυνση -> Συντεταγμένες
  Future<void> _searchAddressFromText() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    // Κρύβουμε το πληκτρολόγιο
    FocusScope.of(context).unfocus();
    setState(() => _isLocating = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        LatLng newPos = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );
        setState(() {
          _selectedLocation = newPos;
          _isLocating = false;
        });
        // Πάμε τον χάρτη στη νέα τοποθεσία
        _mapController.move(newPos, 15.0);
      }
    } catch (e) {
      _showFallbackMessage('Δεν βρέθηκε η διεύθυνση. Ελέγξτε την ορθογραφία.');
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showFallbackMessage(
          'Το GPS είναι κλειστό. Παρακαλώ βάλτε την πινέζα χειροκίνητα.',
        );
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showFallbackMessage(
            'Δεν δόθηκε άδεια τοποθεσίας. Επιλέξτε το χωράφι χειροκίνητα.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showFallbackMessage(
          'Τα δικαιώματα τοποθεσίας είναι απενεργοποιημένα. Επιλέξτε χειροκίνητα.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        LatLng newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = newLocation;
          _isLocating = false;
        });

        _mapController.move(_selectedLocation!, 15.0);
        _getAddressFromLatLng(newLocation);
      }
    } catch (e) {
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

      // Σώζουμε πάντα τις συντεταγμένες (lat/lng) για να δουλεύει nη πλοήγηση
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),

                  //Πεδίο Αναζήτησης / Εμφάνισης Διεύθυνσης
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Διεύθυνση / Αναζήτηση',
                      hintText: 'π.χ. Ηράκλειο Κρήτης',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: _searchAddressFromText, // Κουμπί αναζήτησης
                        tooltip: 'Αναζήτηση στον χάρτη',
                      ),
                    ),
                    // Αν ο χρήστης πατήσει "Enter" στο πληκτρολόγιο, κάνει αναζήτηση
                    onFieldSubmitted: (_) => _searchAddressFromText(),
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
                      ), // Προεπιλογή
                      initialZoom: 6.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                        _getAddressFromLatLng(
                          point,
                        ); // Ανανεώνει το πεδίο διεύθυνσης
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
