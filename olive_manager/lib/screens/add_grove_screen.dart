// Αρχείο: lib/screens/add_grove_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final _areaController =
      TextEditingController(); // Controller για τα στρέμματα

  // Αρχικό κέντρο χάρτη (Ελλάδα - Αθήνα)
  final MapController _mapController = MapController();
  LatLng? _selectedLocation; // Εδώ θα αποθηκεύεται η πινέζα

  Future<void> _saveGrove() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedLocation == null) {
        // Ειδοποίηση αν δεν έβαλε πινέζα
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
        area: double.parse(_areaController.text), // Στρέμματα
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
                    'Πατήστε στον χάρτη για να βάλετε πινέζα:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Ο διαδραστικός χάρτης!
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(
                    38.2462,
                    21.7351,
                  ), // Κέντρο (π.χ. Πάτρα, μπορείς να βάλεις ότι θες)
                  initialZoom: 6.0,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedLocation =
                          point; // Βάζουμε την πινέζα εκεί που πάτησε
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
