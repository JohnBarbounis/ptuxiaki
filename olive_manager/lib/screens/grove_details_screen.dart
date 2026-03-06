// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../services/database_helper.dart';
import 'add_task_screen.dart'; // Θα το φτιάξουμε στο επόμενο βήμα!

class GroveDetailsScreen extends StatefulWidget {
  final OliveGrove grove; // Το χωράφι που επιλέξαμε

  const GroveDetailsScreen({super.key, required this.grove});

  @override
  State<GroveDetailsScreen> createState() => _GroveDetailsScreenState();
}

class _GroveDetailsScreenState extends State<GroveDetailsScreen> {
  List<Task> tasks = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Διαβάζει τις εργασίες ΜΟΝΟ για αυτό το χωράφι
  Future<void> _loadTasks() async {
    setState(() => isLoading = true);
    tasks = await DatabaseHelper.instance.getTasksForGrove(widget.grove.id);
    setState(() => isLoading = false);
  }

  Future<void> _navigateToAddTask() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(groveId: widget.grove.id),
      ),
    );

    if (result == true) {
      _loadTasks(); // Αν προστέθηκε νέα εργασία, ανανέωσε τη λίστα
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.grove.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
          ? const Center(
              child: Text('Δεν υπάρχουν εργασίες για αυτό το χωράφι.'),
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: const Icon(Icons.agriculture, color: Colors.green),
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Εμφάνιση τύπου και ημερομηνίας (μορφοποιημένη απλά)
                    subtitle: Text(
                      '${task.type} • ${task.date.day}/${task.date.month}/${task.date.year}',
                    ),
                    trailing: Text(
                      '${task.cost} €',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddTask,
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Νέα Εργασία', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
