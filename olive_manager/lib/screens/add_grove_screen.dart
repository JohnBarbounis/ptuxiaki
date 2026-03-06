// Αρχείο: lib/screens/add_grove_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';
import '../services/database_helper.dart';

class AddGroveScreen extends StatefulWidget {
  const AddGroveScreen({super.key});

  @override
  State<AddGroveScreen> createState() => _AddGroveScreenState();
}

class _AddGroveScreenState extends State<AddGroveScreen> {
  // Το κλειδί για να ελέγχουμε τη φόρμα
  final _formKey = GlobalKey<FormState>();

  // Controllers για να διαβάζουμε τι γράφει ο χρήστης
  final _nameController = TextEditingController();
  final _treesController = TextEditingController();

  // Συνάρτηση αποθήκευσης
  Future<void> _saveGrove() async {
    if (_formKey.currentState!.validate()) {
      final newGrove = OliveGrove(
        id: DateTime.now().millisecondsSinceEpoch
            .toString(), // Πιο ασφαλές μοναδικό ID
        name: _nameController.text,
        treeCount: int.parse(_treesController.text),
      );

      // Αποθήκευση στη μόνιμη βάση δεδομένων!
      await DatabaseHelper.instance.insertGrove(newGrove);

      // Επιστρέφουμε 'true' στην προηγούμενη οθόνη για να ξέρει ότι έγινε αλλαγή
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
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Άσπρο βελάκι επιστροφής
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Όνομα Χωραφιού (π.χ. Πάνω Αμπέλι)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Παρακαλώ εισάγετε όνομα';
                  }

                  // Regular Expression: Δέχεται μόνο Αγγλικά, Ελληνικά, Αριθμούς και Κενά.
                  // (Καλύπτει και τα τονισμένα ελληνικά φωνήεντα)
                  final nameRegex = RegExp(
                    r'^[a-zA-Zα-ωΑ-ΩάέήίόύώΆΈΉΊΌΎΏ0-9\s]+$',
                  );

                  if (!nameRegex.hasMatch(value)) {
                    return 'Επιτρέπονται μόνο Ελληνικοί/Αγγλικοί χαρακτήρες και αριθμοί';
                  }

                  return null; // Αν περάσει τους ελέγχους, είναι έγκυρο!
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _treesController,
                decoration: const InputDecoration(
                  labelText: 'Αριθμός Δέντρων',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    TextInputType.number, // Ανοίγει αριθμητικό πληκτρολόγιο
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      int.tryParse(value) == null) {
                    return 'Παρακαλώ εισάγετε έγκυρο αριθμό';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, // Το κουμπί πιάνει όλο το πλάτος
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  onPressed: _saveGrove,
                  child: const Text(
                    'Αποθήκευση',
                    style: TextStyle(color: Colors.white, fontSize: 18),
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
