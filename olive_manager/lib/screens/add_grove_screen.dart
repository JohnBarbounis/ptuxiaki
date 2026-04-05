import 'dart:convert';
import 'dart:math'
    as math; // ΝΕΟ: Απαραίτητο για τους μαθηματικούς υπολογισμούς!
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/olive_grove.dart';
import '../services/database_helper.dart';
import 'map_picker_screen.dart';

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

  List<LatLng> _selectedBoundaries = [];

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

  // ΝΕΟΣ ΑΛΓΟΡΙΘΜΟΣ: Υπολογισμός Εμβαδού Πολυγώνου στη Σφαίρα της Γης
  double _calculatePolygonAreaInStremmata(List<LatLng> points) {
    if (points.length < 3)
      return 0.0; // Ένα πολύγωνο χρειάζεται τουλάχιστον 3 σημεία

    const double earthRadius =
        6378137.0; // Ακτίνα της Γης στον Ισημερινό (σε μέτρα)
    double area = 0.0;

    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;

      // Μετατροπή των μοιρών σε Ακτίνια (Radians)
      double lat1 = points[i].latitude * math.pi / 180;
      double lng1 = points[i].longitude * math.pi / 180;
      double lat2 = points[j].latitude * math.pi / 180;
      double lng2 = points[j].longitude * math.pi / 180;

      // Γεωγραφικός τύπος υπολογισμού
      area += (lng2 - lng1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    // Το αποτέλεσμα βγαίνει σε Τετραγωνικά Μέτρα
    area = (area * earthRadius * earthRadius / 2.0).abs();

    // Επιστρέφουμε Στρέμματα (1 στρέμμα = 1000 τ.μ.)
    return area / 1000.0;
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

      // Αντικατάσταση τυχόν κόμματος (,) με τελεία (.) για να μην κρασάρει το double.parse
      String safeAreaText = _areaController.text.replaceAll(',', '.');

      final grove = OliveGrove(
        id:
            widget.existingGrove?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        area: double.parse(
          safeAreaText,
        ), // Χρησιμοποιεί ό,τι λέει το TextField (το αυτόματο ή του χρήστη)
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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

              // Το πεδίο των Στρεμμάτων (Επεξεργάσιμο από τον χρήστη)
              TextFormField(
                controller: _areaController,
                decoration: InputDecoration(
                  labelText: 'Στρέμματα',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.square_foot),
                  suffixText: 'Στρέμματα',
                  // Μικρό βοηθητικό μήνυμα αν έχει γίνει αυτόματος υπολογισμός
                  helperText: _selectedBoundaries.isNotEmpty
                      ? 'Μπορείτε να τροποποιήσετε την αυτόματη τιμή'
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Εισάγετε στρέμματα' : null,
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.map,
                        size: 48,
                        color: _selectedBoundaries.isEmpty
                            ? Colors.grey
                            : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedBoundaries.isEmpty
                            ? 'Δεν έχετε ορίσει σύνορα στον χάρτη'
                            : 'Τα σύνορα έχουν οριστεί επιτυχώς!',
                        style: TextStyle(
                          color: _selectedBoundaries.isEmpty
                              ? Colors.grey[700]
                              : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                        ),
                        icon: const Icon(Icons.draw, color: Colors.white),
                        label: const Text(
                          'Σχεδιασμός στον Χάρτη',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapPickerScreen(
                                initialBoundaries: _selectedBoundaries,
                              ),
                            ),
                          );

                          if (result != null && result is List<LatLng>) {
                            setState(() {
                              _selectedBoundaries = result;

                              // ΝΕΟ: Αυτόματος Υπολογισμός Εμβαδού!
                              double calcArea =
                                  _calculatePolygonAreaInStremmata(result);

                              if (calcArea > 0) {
                                // Γράφουμε το νούμερο στο πεδίο (με 2 δεκαδικά ψηφία)
                                _areaController.text = calcArea.toStringAsFixed(
                                  2,
                                );

                                // Πετάμε όμορφο μήνυμα επιβεβαίωσης
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Τα στρέμματα υπολογίστηκαν αυτόματα από τον χάρτη!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
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
            ],
          ),
        ),
      ),
    );
  }
}
