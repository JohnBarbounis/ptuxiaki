import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class UpcomingTasksScreen extends StatefulWidget {
  const UpcomingTasksScreen({super.key});

  @override
  State<UpcomingTasksScreen> createState() => _UpcomingTasksScreenState();
}

class _UpcomingTasksScreenState extends State<UpcomingTasksScreen> {
  List<Map<String, dynamic>> upcomingTasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingTasks();
  }

  Future<void> _loadUpcomingTasks() async {
    final tasks = await DatabaseHelper.instance.getUpcomingTasks();
    setState(() {
      upcomingTasks = tasks;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Μελλοντικές Εργασίες',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:
            Colors.blue[700], // Μπλε χρώμα για να ξεχωρίζει από τα χωράφια
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : upcomingTasks.isEmpty
          ? const Center(
              child: Text(
                'Δεν υπάρχουν προγραμματισμένες εργασίες!\nΕίστε απολύτως οργανωμένοι.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: upcomingTasks.length,
              itemBuilder: (context, index) {
                final task = upcomingTasks[index];
                final date = DateTime.parse(task['date']);

                // Υπολογίζουμε σε πόσες μέρες από σήμερα είναι η εργασία
                final daysLeft = date.difference(DateTime.now()).inDays;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blue[200]!, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      task['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '📍 Χωράφι: ${task['groveName']}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        Text(
                          '📅 ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: daysLeft <= 3
                            ? Colors.red[100]
                            : Colors
                                  .green[100], // Αν είναι κοντά, γίνεται κόκκινο!
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        daysLeft == 0 ? 'Σήμερα!' : 'Σε $daysLeft μέρες',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: daysLeft <= 3
                              ? Colors.red[800]
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
