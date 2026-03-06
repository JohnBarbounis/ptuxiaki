// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../services/database_helper.dart';
import 'add_task_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class GroveDetailsScreen extends StatefulWidget {
  final OliveGrove grove;

  const GroveDetailsScreen({super.key, required this.grove});

  @override
  State<GroveDetailsScreen> createState() => _GroveDetailsScreenState();
}

class _GroveDetailsScreenState extends State<GroveDetailsScreen> {
  List<Task> tasks = [];
  bool isLoading = false;
  double totalCost = 0.0; // ΝΕΟ: Εδώ θα κρατάμε το άθροισμα των εξόδων

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => isLoading = true);

    // Φέρνουμε τις εργασίες από τη βάση
    final fetchedTasks = await DatabaseHelper.instance.getTasksForGrove(
      widget.grove.id,
    );

    // Υπολογισμός του συνολικού κόστους
    double cost = 0.0;
    for (var task in fetchedTasks) {
      cost += task.cost;
    }

    setState(() {
      tasks = fetchedTasks;
      totalCost = cost; // Ενημερώνουμε τη μεταβλητή μας
      isLoading = false;
    });
  }

  Future<void> _navigateToAddTask() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(groveId: widget.grove.id),
      ),
    );

    if (result == true) {
      _loadTasks(); // Ξαναφορτώνει και υπολογίζει ξανά τα έξοδα!
    }
  }

  // Συνάρτηση για άνοιγμα του Google Maps
  Future<void> _navigateToGrove() async {
    // Ελέγχουμε αν υπάρχουν συντεταγμένες
    if (widget.grove.lat == null || widget.grove.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Δεν υπάρχει αποθηκευμένη τοποθεσία για αυτό το χωράφι.',
          ),
        ),
      );
      return;
    }

    // Δημιουργία του URL για Οδηγίες Πλοήγησης (Directions)
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.grove.lat},${widget.grove.lng}',
    );

    // Ζητάμε από το κινητό να ανοίξει το link (κατά προτίμηση στην εφαρμογή Google Maps)
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Αδυναμία ανοίγματος του Google Maps.')),
        );
      }
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
          : Column(
              children: [
                // ΝΕΟ: Το πλαίσιο συνολικών εξόδων στην κορυφή
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  color: Colors.green[50], // Απαλό πράσινο φόντο
                  child: Column(
                    children: [
                      const Text(
                        'Συνολικά Έξοδα Χωραφιού',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalCost.toStringAsFixed(2)} €', // Δείχνει το ποσό με 2 δεκαδικά ψηφία
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                // ΝΕΟ: Κουμπί Πλοήγησης (Εμφανίζεται μόνο αν υπάρχουν συντεταγμένες)
                if (widget.grove.lat != null && widget.grove.lng != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _navigateToGrove,
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'Πλοήγηση στο Χωράφι',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .blue[700], // Μπλε χρώμα για να ξεχωρίζει από τις αγροτικές εργασίες
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const Divider(
                  height: 1,
                  thickness: 2,
                ), // Μια γραμμή διαχωρισμού
                // Η λίστα με τις εργασίες
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                            'Δεν υπάρχουν εργασίες για αυτό το χωράφι.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Dismissible(
                              // Κάθε Dismissible χρειάζεται ένα μοναδικό κλειδί (το ID της εργασίας)
                              key: Key(task.id),

                              // Κατεύθυνση: από δεξιά προς τα αριστερά
                              direction: DismissDirection.endToStart,

                              // Το κόκκινο φόντο με τον κάδο που εμφανίζεται από πίσω όταν σέρνουμε
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),

                              // Εμφάνιση παραθύρου επιβεβαίωσης πριν τη διαγραφή
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Επιβεβαίωση"),
                                      content: const Text(
                                        "Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την εργασία;",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text("ΑΚΥΡΩΣΗ"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text(
                                            "ΔΙΑΓΡΑΦΗ",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },

                              // Τι θα γίνει αν ο χρήστης πατήσει "ΔΙΑΓΡΑΦΗ"
                              onDismissed: (direction) async {
                                // 1. Διαγραφή από τη βάση δεδομένων
                                await DatabaseHelper.instance.deleteTask(
                                  task.id,
                                );

                                // 2. Ανανέωση της λίστας και των συνολικών εξόδων
                                _loadTasks();

                                // 3. Εμφάνιση ενός μικρού μηνύματος στο κάτω μέρος
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Η εργασία διαγράφηκε επιτυχώς',
                                    ),
                                  ),
                                );
                              },

                              // Η κάρτα μας όπως ήταν πριν, τυλιγμένη πλέον στο Dismissible
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green[100],
                                    child: const Icon(
                                      Icons.agriculture,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${task.type} • ${task.date.day}/${task.date.month}/${task.date.year}',
                                  ),
                                  trailing: Text(
                                    '${task.cost.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
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
