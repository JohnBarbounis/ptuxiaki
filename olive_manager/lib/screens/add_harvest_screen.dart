import 'package:flutter/material.dart';
import '../models/harvest.dart';
import '../services/database_helper.dart';

class AddHarvestScreen extends StatefulWidget {
  final String groveId;
  final Harvest? existingHarvest; // Αν υπάρχει, κάνουμε επεξεργασία

  const AddHarvestScreen({
    super.key,
    required this.groveId,
    this.existingHarvest,
  });

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _oilController;
  late TextEditingController _weightController;
  late TextEditingController _acidityController;
  late TextEditingController _priceController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Αν έχουμε existingHarvest, γεμίζουμε τα πεδία με τις παλιές τιμές
    _oilController = TextEditingController(
      text: widget.existingHarvest?.oilVolume.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.existingHarvest?.olivesWeight.toString() ?? '',
    );
    _acidityController = TextEditingController(
      text: widget.existingHarvest?.acidity.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.existingHarvest?.pricePerUnit.toString() ?? '',
    );
    _selectedDate = widget.existingHarvest?.date ?? DateTime.now();
  }

  void _saveHarvest() async {
    if (_formKey.currentState!.validate()) {
      final harvest = Harvest(
        id:
            widget.existingHarvest?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        oilVolume: double.parse(_oilController.text),
        olivesWeight: double.parse(_weightController.text),
        acidity: double.parse(_acidityController.text),
        pricePerUnit: double.parse(_priceController.text),
        date: _selectedDate,
      );

      if (widget.existingHarvest == null) {
        await DatabaseHelper.instance.insertHarvest(harvest);
      } else {
        await DatabaseHelper.instance.updateHarvest(
          harvest,
        ); // Χρειάζεται αυτή η μέθοδος στο DatabaseHelper
      }
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingHarvest == null
              ? 'Νέα Συγκομιδή'
              : 'Διόρθωση Συγκομιδής',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_oilController, 'Λίτρα Λαδιού', Icons.opacity),
              const SizedBox(height: 15),
              _buildField(_weightController, 'Κιλά Ελιάς', Icons.scale),
              const SizedBox(height: 15),
              _buildField(_acidityController, 'Οξύτητα', Icons.science),
              const SizedBox(height: 15),
              _buildField(
                _priceController,
                'Τιμή Πώλησης (€/Λίτρο)',
                Icons.euro_symbol,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveHarvest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.all(15),
                ),
                child: const Text(
                  'Αποθήκευση',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) => value!.isEmpty ? 'Συμπληρώστε το πεδίο' : null,
    );
  }
}
