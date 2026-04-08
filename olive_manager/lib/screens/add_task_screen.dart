// Αρχείο: lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
import '../models/tasks.dart';
import '../services/database_helper.dart';

class AddTaskScreen extends StatefulWidget {
  final String groveId;
  final Task?
  existingTask; // Αν είναι null, σημαίνει νέα εργασία. Αν όχι, επεξεργασία υπάρχουσας.
  const AddTaskScreen({super.key, required this.groveId, this.existingTask});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _costController;
  late final TextEditingController _notesController;
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

  bool _scheduleNext = false;
  late DateTime _selectedDate;

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
    // Προ-συμπλήρωση αν κάνουμε Επεξεργασία (Edit)
    _titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    _costController = TextEditingController(
      text: widget.existingTask?.cost.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existingTask?.notes ?? '',
    );
    _selectedType =
        widget.existingTask?.type ??
        'Κλάδεμα'; // Βάλε τον δικό σου default τύπο εδώ
    _selectedPreset = _presets[2]; // Initialize with a default preset
    _selectedDate = widget.existingTask?.date ?? DateTime.now();
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      // 1. Δημιουργούμε το αντικείμενο της εργασίας
      final task = Task(
        // Αν υπάρχει ήδη η εργασία, κρατάμε το παλιό ID. Αλλιώς, φτιάχνουμε νέο.
        id:
            widget.existingTask?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        title: _titleController.text,
        type: _selectedType,
        date:
            _selectedDate, // ΣΗΜΑΝΤΙΚΟ: Βάζουμε την επιλεγμένη ημερομηνία, όχι απλά την τωρινή!
        cost:
            double.tryParse(_costController.text.replaceAll(',', '.')) ??
            0.0, // Ασφαλής μετατροπή
        notes: _notesController.text,
      );

      // 2. Ελέγχουμε αν πρόκειται για ΝΕΑ ΠΡΟΣΘΗΚΗ ή ΕΠΕΞΕΡΓΑΣΙΑ
      if (widget.existingTask == null) {
        // --- Α. ΝΕΑ ΕΡΓΑΣΙΑ ---
        await DatabaseHelper.instance.insertTask(task);

        // Αν έχουμε επιλέξει να προγραμματίσουμε την επόμενη εργασία (Γίνεται ΜΟΝΟ σε νέες εργασίες)
        if (_scheduleNext) {
          int daysToAdd = _selectedPreset['days'];
          if (daysToAdd == 0) {
            daysToAdd = int.tryParse(_customDaysController.text) ?? 7;
          }

          final nextDate = DateTime.now().add(Duration(days: daysToAdd));

          final futureTask = Task(
            id: nextDate.millisecondsSinceEpoch
                .toString(), // Νέο μοναδικό ID στο μέλλον
            groveId: widget.groveId,
            title: '⏳ ΕΠΑΝΑΛΗΨΗ: ${_titleController.text}',
            type: _selectedType,
            date: nextDate,
            cost: 0.0, // Η μελλοντική εργασία δεν έχει ακόμα κόστος
            notes:
                'Αυτόματη υπενθύμιση. Μην ξεχάσετε να ενημερώσετε το κόστος όταν την ολοκληρώσετε.',
          );
          await DatabaseHelper.instance.insertTask(futureTask);
        }
      } else {
        // --- Β. ΕΠΕΞΕΡΓΑΣΙΑ ΥΠΑΡΧΟΥΣΑΣ ΕΡΓΑΣΙΑΣ ---
        await DatabaseHelper.instance.updateTask(task);
      }

      // 3. Επιστροφή στην προηγούμενη οθόνη με σήμα (true) ότι έγινε αλλαγή
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
                initialValue: _selectedType,
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
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Ημερομηνία'),
                subtitle: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),

              const Divider(height: 40, thickness: 2),
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
                      activeThumbColor: Colors.blue[700],
                      onChanged: (bool value) {
                        setState(() => _scheduleNext = value);
                      },
                    ),
                    if (_scheduleNext) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _selectedPreset,
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
