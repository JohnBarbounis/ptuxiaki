import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/tasks.dart';
import '../services/database_helper.dart';
import '../utils/text_formatting.dart'; // ✅ Text formatting utilities

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Ημερομηνίες για τον έλεγχο του ημερολογίου
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Εδώ θα αποθηκεύουμε τις εργασίες ομαδοποιημένες ανά ημέρα
  Map<DateTime, List<Task>> _groupedTasks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllTasks();
  }

  // Συνάρτηση που φέρνει ολες τις εργασίες από όλα τα χωράφια
  Future<void> _loadAllTasks() async {
    final groves = await DatabaseHelper.instance.getAllGroves();
    Map<DateTime, List<Task>> tempTasks = {};

    for (var grove in groves) {
      final tasks = await DatabaseHelper.instance.getTasksForGrove(grove.id);
      for (var task in tasks) {
        // Αφαιρούμε την ώρα/λεπτά για να γίνεται σωστά η ομαδοποίηση ανά ημέρα
        final normalizedDate = DateTime(
          task.date.year,
          task.date.month,
          task.date.day,
        );

        if (tempTasks[normalizedDate] == null) {
          tempTasks[normalizedDate] = [];
        }
        // Προσθέτουμε την εργασία στη συγκεκριμένη μέρα
        tempTasks[normalizedDate]!.add(task);
      }
    }

    setState(() {
      _groupedTasks = tempTasks;
      _isLoading = false;
    });
  }

  // Επιστρέφει τις εργασίες για μια συγκεκριμένη μέρα
  List<Task> _getTasksForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _groupedTasks[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Οι εργασίες της ημέρας που έχει πατήσει ο χρήστης
    final selectedTasks = _getTasksForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Συγκεντρωτικό Ημερολόγιο',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. ΤΟ ΗΜΕΡΟΛΟΓΙΟ
                Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TableCalendar<Task>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getTasksForDay, // Φορτώνει τις κουκκίδες
                    startingDayOfWeek:
                        StartingDayOfWeek.monday, // Η εβδομάδα ξεκινάει Δευτέρα
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false, // Κρύβουμε το κουμπί
                      titleCentered: true,
                    ),

                    // Όταν ο χρήστης πατάει μια μέρα
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 8.0),
                Text(
                  'Εργασίες για: ${TextFormatting.formatDateGreek(_selectedDay!)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const Divider(),

                // 2. Η ΛΙΣΤΑ ΜΕ ΤΙΣ ΕΡΓΑΣΙΕΣ ΤΗΣ ΗΜΕΡΑΣ
                Expanded(
                  child: selectedTasks.isEmpty
                      ? const Center(
                          child: Text(
                            'Δεν υπάρχουν εργασίες για αυτή την ημέρα.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: selectedTasks.length,
                          itemBuilder: (context, index) {
                            final task = selectedTasks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Icon(
                                    Icons.agriculture,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('Τύπος: ${task.type}'),
                                trailing: task.cost > 0
                                    ? Text(
                                        '${task.cost.toStringAsFixed(2)}€',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.grey,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
