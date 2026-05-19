// Αρχείο: lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  final String groveId;
  final String groveName;

  const StatisticsScreen({
    super.key,
    required this.groveId,
    required this.groveName,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, double> _categoryCosts = {};
  double _totalCost = 0.0;
  bool _isLoading = true;

  // Χρώματα για τις διάφορες εργασίες
  final Map<String, Color> _categoryColors = {
    'Κλάδεμα': Colors.brown,
    'Λίπανση': Colors.orange,
    'Ψεκασμός': Colors.blue,
    'Πότισμα': Colors.lightBlueAccent,
    'Κοπή Χόρτων': Colors.green,
    'Συγκομιδή': Colors.purple,
    'Άλλο': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final tasks = await DatabaseHelper.instance.getTasksForGrove(
      widget.groveId,
    );

    Map<String, double> costs = {};
    double total = 0.0;
    for (var task in tasks) {
      if (task.cost > 0) {
        costs[task.type] = (costs[task.type] ?? 0) + task.cost;
        total += task.cost;
      }
    }

    setState(() {
      _categoryCosts = costs;
      _totalCost = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Στατιστικά: ${widget.groveName}'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _totalCost == 0
          ? const Center(
              child: Text(
                'Δεν υπάρχουν έξοδα για αυτό το χωράφι ακόμα.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Κατανομή Εξόδων ανά Εργασία',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // ΤΟ ΓΡΑΦΗΜΑ ΠΙΤΑΣ
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: _getSections(),
                    ),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 3,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _categoryCosts.entries.map((entry) {
                          final percentage = (entry.value / _totalCost) * 100;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _categoryColors[entry.key] ?? Colors.black,
                              radius: 12,
                            ),
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '${entry.value.toStringAsFixed(2)}€ (${percentage.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 15),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<PieChartSectionData> _getSections() {
    return _categoryCosts.entries.map((entry) {
      final percentage = (entry.value / _totalCost) * 100;
      return PieChartSectionData(
        color: _categoryColors[entry.key] ?? Colors.black,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
