// Αρχείο: lib/screens/add_harvest_screen.dart
import 'package:flutter/material.dart';
import '../models/harvest.dart';
import '../services/database_helper.dart';

class AddHarvestScreen extends StatefulWidget {
  final String groveId;

  const AddHarvestScreen({super.key, required this.groveId});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _olivesController = TextEditingController();
  final _oilController = TextEditingController();
  final _acidityController = TextEditingController();

  Future<void> _saveHarvest() async {
    if (_formKey.currentState!.validate()) {
      final newHarvest = Harvest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        date: DateTime.now(),
        olivesWeight: double.parse(_olivesController.text),
        oilVolume: double.parse(_oilController.text),
        acidity: double.parse(_acidityController.text),
      );

      await DatabaseHelper.instance.insertHarvest(newHarvest);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Νέα Συγκομιδή',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _olivesController,
                decoration: const InputDecoration(
                  labelText: 'Κιλά Ελιάς (π.χ. 1500)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Απαραίτητο πεδίο' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _oilController,
                decoration: const InputDecoration(
                  labelText: 'Λίτρα/Κιλά Λαδιού (π.χ. 300)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Απαραίτητο πεδίο' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _acidityController,
                decoration: const InputDecoration(
                  labelText: 'Οξύτητα (π.χ. 0.3)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Απαραίτητο πεδίο' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _saveHarvest,
                child: const Text(
                  'Αποθήκευση Συγκομιδής',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
