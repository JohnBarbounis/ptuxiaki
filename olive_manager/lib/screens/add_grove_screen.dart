// Αρχείο: lib/screens/add_grove_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';

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
  void _saveGrove() {
    if (_formKey.currentState!.validate()) {
      // Αν η φόρμα είναι έγκυρη, φτιάχνουμε το αντικείμενο
      final newGrove = OliveGrove(
        id: DateTime.now().toString(), // Προσωρινό ID
        name: _nameController.text,
        treeCount: int.parse(_treesController.text),
      );

      // Κλείνουμε την οθόνη και επιστρέφουμε το νέο χωράφι στην προηγούμενη οθόνη
      Navigator.of(context).pop(newGrove);
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
                  if (value == null || value.isEmpty) {
                    return 'Παρακαλώ εισάγετε όνομα';
                  }
                  return null;
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
