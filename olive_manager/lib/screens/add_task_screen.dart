// Αρχείο: lib/screens/add_task_screen.dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_helper.dart';

class AddTaskScreen extends StatefulWidget {
  final String
  groveId; // Χρειαζόμαστε το ID του χωραφιού για να "δέσουμε" την εργασία

  const AddTaskScreen({super.key, required this.groveId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'Ψεκασμός'; // Προεπιλεγμένη τιμή
  final List<String> _taskTypes = [
    'Ψεκασμός',
    'Κλάδεμα',
    'Λίπανση',
    'Άρδευση',
    'Άλλο',
  ];

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groveId: widget.groveId,
        title: _titleController.text,
        type: _selectedType,
        date: DateTime.now(), // Για συντομία βάζουμε τη σημερινή ημερομηνία
        cost: double.tryParse(_costController.text) ?? 0.0,
        notes: _notesController.text,
      );

      await DatabaseHelper.instance.insertTask(newTask);

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
          'Προσθήκη Εργασίας',
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
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Τίτλος (π.χ. Ράντισμα για Δάκο)',
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
                  labelText: 'Συνολικό Κόστος (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _saveTask,
                child: const Text(
                  'Αποθήκευση Εργασίας',
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
