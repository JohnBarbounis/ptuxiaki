// Αρχείο: lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
import '../models/tasks.dart';
import '../services/database_helper.dart';

class AddTaskScreen extends StatefulWidget {
  final String groveId;
  const AddTaskScreen({super.key, required this.groveId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDaysController = TextEditingController(
    text: '7',
  ); // Για τις προσαρμοσμένες μέρες

  String _selectedType = 'Ψεκασμός';
  final List<String> _taskTypes = [
    'Κλάδεμα',
    'Λίπανση',
    'Ψεκασμός',
    'Πότισμα',
    'Κοπή Χόρτων',
    'Συγκομιδή',
    'Άλλο',
  ];

  // --- ΝΕΕΣ ΜΕΤΑΒΛΗΤΕΣ ΓΙΑ ΤΟΝ ΕΞΥΠΝΟ ΠΡΟΓΡΑΜΜΑΤΙΣΜΟ ---
  bool _scheduleNext = false;

  // Τα έτοιμα "Πρότυπα Αγρότη"
  final List<Map<String, dynamic>> _presets = [
    {'label': 'Ψεκασμός Δάκου (21 μέρες)', 'days': 21},
    {'label': 'Πότισμα (10 μέρες)', 'days': 10},
    {'label': 'Διαφυλλική Λίπανση (20 μέρες)', 'days': 20},
    {'label': 'Κοπή Χόρτων (40 μέρες)', 'days': 40},
    {'label': 'Προσαρμοσμένο (Επιλογή ημερών)...', 'days': 0},
  ];

  late Map<String, dynamic> _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presets[0]; // Προεπιλογή: Ψεκασμός Δάκου
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();

      // 1. Αποθηκεύουμε την ΤΩΡΙΝΗ εργασία που μόλις έκανε
      final currentTask = Task(
        id: now.millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        title: _titleController.text,
        type: _selectedType,
        date: now,
        cost: double.tryParse(_costController.text) ?? 0.0,
        notes: _notesController.text,
      );
      await DatabaseHelper.instance.insertTask(currentTask);

      // 2. Αν ο διακόπτης είναι ανοιχτός, αποθηκεύουμε ΚΑΙ τη ΜΕΛΛΟΝΤΙΚΗ υπενθύμιση
      if (_scheduleNext) {
        // Βρίσκουμε τις μέρες (αν είναι 0, παίρνουμε αυτό που έγραψε στο πεδίο)
        int daysToAdd = _selectedPreset['days'];
        if (daysToAdd == 0) {
          daysToAdd = int.tryParse(_customDaysController.text) ?? 7;
        }

        final nextDate = now.add(Duration(days: daysToAdd));

        final futureTask = Task(
          id: nextDate.millisecondsSinceEpoch
              .toString(), // Νέο μοναδικό ID (ημερομηνία στο μέλλον)
          groveId: widget.groveId,
          title:
              '⏳ ΕΠΑΝΑΛΗΨΗ: ${_titleController.text}', // Βάζουμε το σύμβολο ⏳ για να ξεχωρίζει
          type: _selectedType,
          date: nextDate,
          cost: 0.0, // Το κόστος είναι 0 γιατί δεν έχει γίνει ακόμα
          notes:
              'Αυτόματη υπενθύμιση. Μην ξεχάσετε να ενημερώσετε το κόστος όταν την ολοκληρώσετε.',
        );
        await DatabaseHelper.instance.insertTask(futureTask);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Νέα Εργασία', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Βασικά Πεδία
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Τίτλος (π.χ. 1ο χέρι ράντισμα)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Εισάγετε τίτλο' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Είδος Εργασίας',
                  border: OutlineInputBorder(),
                ),
                items: _taskTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Κόστος (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => value!.isEmpty ? 'Εισάγετε κόστος' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Σημειώσεις / Φάρμακο που έπεσε (Προαιρετικό)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const Divider(height: 40, thickness: 2),

              // ---- ΕΞΥΠΝΟΣ ΠΡΟΓΡΑΜΜΑΤΙΣΜΟΣ (SMART SCHEDULING) ----
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Υπενθύμιση Επανάληψης',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      subtitle: const Text(
                        'Δημιουργεί αυτόματα μελλοντική εκκρεμότητα',
                      ),
                      value: _scheduleNext,
                      activeColor: Colors.blue[700],
                      onChanged: (bool value) {
                        setState(() => _scheduleNext = value);
                      },
                    ),

                    // Αν ο διακόπτης είναι ανοιχτός, δείχνουμε τα πρότυπα!
                    if (_scheduleNext) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedPreset,
                        decoration: const InputDecoration(
                          labelText: 'Επιλογή Προτύπου',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _presets
                            .map(
                              (preset) => DropdownMenuItem(
                                value: preset,
                                child: Text(preset['label']),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedPreset = value!);
                        },
                      ),

                      // Αν διάλεξε "Προσαρμοσμένο", δείχνουμε πεδίο για να γράψει μέρες
                      if (_selectedPreset['days'] == 0) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customDaysController,
                          decoration: const InputDecoration(
                            labelText: 'Σε πόσες μέρες από σήμερα;',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _saveTask,
                child: const Text(
                  'Αποθήκευση',
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
