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
  late TextEditingController _oilVolumeController;
  late TextEditingController _weightController;
  late TextEditingController _acidityController;
  late TextEditingController _priceController;
  late DateTime _selectedDate;

  // --- ΝΕΕΣ ΜΕΤΑΒΛΗΤΕΣ ΓΙΑ ΤΟΝ ΖΩΝΤΑΝΟ ΥΠΟΛΟΓΙΣΜΟ ---
  double _totalGroveExpenses = 0.0;
  double _currentTypedOil = 0.0;
  double _currentTypedPrice = 0.0;
  bool _isLoadingExpenses = true;

  @override
  void initState() {
    super.initState();
    _oilVolumeController = TextEditingController(
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

    _loadExpenses(); // Φορτώνουμε τα έξοδα μόλις ανοίξει η οθόνη

    // Βάζουμε "αυτιά" στα πεδία για να υπολογίζουν ζωντανά καθώς πληκτρολογεί ο χρήστης!
    _oilVolumeController.addListener(_onInputChanged);
    _priceController.addListener(_onInputChanged);
  }

  // Συνάρτηση που βρίσκει πόσα έχει ξοδέψει ο αγρότης σε αυτό το χωράφι
  Future<void> _loadExpenses() async {
    final tasks = await DatabaseHelper.instance.getTasksForGrove(
      widget.groveId,
    );
    double sum = 0.0;
    for (var t in tasks) {
      sum += t.cost;
    }
    setState(() {
      _totalGroveExpenses = sum;
      _isLoadingExpenses = false;
    });
  }

  // Συνάρτηση που τρέχει κάθε φορά που ο χρήστης πατάει ένα πλήκτρο στα πεδία
  void _onInputChanged() {
    setState(() {
      _currentTypedOil =
          double.tryParse(_oilVolumeController.text.replaceAll(',', '.')) ??
          0.0;
      _currentTypedPrice =
          double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
    });
  }

  @override
  void dispose() {
    _oilVolumeController.removeListener(_onInputChanged);
    _priceController.removeListener(_onInputChanged);
    _oilVolumeController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _acidityController.dispose();
    super.dispose();
  }

  void _saveHarvest() async {
    if (_formKey.currentState!.validate()) {
      final harvest = Harvest(
        id:
            widget.existingHarvest?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        oilVolume: double.parse(_oilVolumeController.text),
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
              _buildField(_oilVolumeController, 'Λίτρα Λαδιού', Icons.opacity),
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
              const SizedBox(height: 24),

              // --- ΝΕΟ: ΖΩΝΤΑΝΗ ΚΑΡΤΑ ΔΙΑΠΡΑΓΜΑΤΕΥΣΗΣ (REAL-TIME BI) ---
              if (!_isLoadingExpenses &&
                  _totalGroveExpenses > 0 &&
                  _currentTypedOil > 0)
                Builder(
                  builder: (context) {
                    // Υπολογισμοί
                    double breakEvenPrice =
                        _totalGroveExpenses / _currentTypedOil;
                    bool isProfitable = _currentTypedPrice >= breakEvenPrice;
                    double projectedProfit =
                        (_currentTypedOil * _currentTypedPrice) -
                        _totalGroveExpenses;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _currentTypedPrice == 0
                            ? Colors
                                  .blue[50] // Αν δεν έχει βάλει τιμή ακόμα, μπλε πληροφοριακό
                            : isProfitable
                            ? Colors.green[50] // Αν έχει κέρδος, πράσινο
                            : Colors.red[50], // Αν έχει ζημιά, κόκκινο
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentTypedPrice == 0
                              ? Colors.blue[300]!
                              : isProfitable
                              ? Colors.green
                              : Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _currentTypedPrice == 0
                                    ? Icons.info_outline
                                    : isProfitable
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: _currentTypedPrice == 0
                                    ? Colors.blue[700]
                                    : isProfitable
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Υπολογισμός Κέρδους',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Τα φετινά έξοδα αυτού του χωραφιού είναι ${_totalGroveExpenses.toStringAsFixed(0)}€.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          // 1. Το Νεκρό Σημείο
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Πρέπει να πουλήσετε πάνω από ',
                                ),
                                TextSpan(
                                  text:
                                      '${breakEvenPrice.toStringAsFixed(2)} €/Λίτρο',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const TextSpan(text: ' για να έχετε κέρδος.'),
                              ],
                            ),
                          ),
                          // 2. Η Πρόβλεψη αν βάλει τιμή!
                          if (_currentTypedPrice > 0) ...[
                            const Divider(height: 16),
                            Text(
                              isProfitable
                                  ? 'Με αυτή την τιμή θα έχετε ΚΑΘΑΡΟ ΚΕΡΔΟΣ: +${projectedProfit.toStringAsFixed(2)}€ 💰'
                                  : 'Προσοχή! Με αυτή την τιμή θα έχετε ΖΗΜΙΑ: ${projectedProfit.toStringAsFixed(2)}€ 📉',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isProfitable
                                    ? Colors.green[800]
                                    : Colors.red[800],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
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
