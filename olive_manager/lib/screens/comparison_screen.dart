// Αρχείο: lib/screens/comparison_screen.dart
import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _groveStats = [];

  @override
  void initState() {
    super.initState();
    _loadComparisonData();
  }

  Future<void> _loadComparisonData() async {
    final groves = await DatabaseHelper.instance.getAllGroves();
    List<Map<String, dynamic>> stats = [];

    for (var grove in groves) {
      final tasks = await DatabaseHelper.instance.getTasksForGrove(grove.id);
      final harvests = await DatabaseHelper.instance.getHarvestsForGrove(
        grove.id,
      );

      double cost = 0.0;
      for (var t in tasks) cost += t.cost;

      double revenue = 0.0;
      double oil = 0.0;
      for (var h in harvests) {
        revenue += (h.oilVolume * h.pricePerUnit);
        oil += h.oilVolume;
      }

      double profit = revenue - cost;

      // Κρίσιμοι Δείκτες Απόδοσης (KPIs)
      double profitPerStremma = grove.area > 0 ? profit / grove.area : 0;
      double oilPerTree = grove.treeCount > 0 ? oil / grove.treeCount : 0;
      double costPerTree = grove.treeCount > 0 ? cost / grove.treeCount : 0;

      stats.add({
        'name': grove.name,
        'profitPerStremma': profitPerStremma,
        'oilPerTree': oilPerTree,
        'costPerTree': costPerTree,
        'totalProfit': profit,
      });
    }

    // Ταξινόμηση με βάση το Κέρδος ανά Στρέμμα (Φθίνουσα σειρά)
    stats.sort(
      (a, b) => b['profitPerStremma'].compareTo(a['profitPerStremma']),
    );

    setState(() {
      _groveStats = stats;
      _isLoading = false;
    });
  }

  Widget _buildKpiColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Κατάταξη Χωραφιών',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groveStats.isEmpty
          ? const Center(child: Text('Δεν υπάρχουν δεδομένα.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _groveStats.length,
              itemBuilder: (context, index) {
                final stat = _groveStats[index];

                // Απονομή Μεταλλίων για τα 3 κορυφαία!
                String rankMedal = '';
                Color cardBorder = Colors.grey[300]!;
                if (index == 0) {
                  rankMedal = '🥇 ';
                  cardBorder = Colors.amber;
                } else if (index == 1) {
                  rankMedal = '🥈 ';
                  cardBorder = Colors.grey[400]!;
                } else if (index == 2) {
                  rankMedal = '🥉 ';
                  cardBorder = Colors.brown[300]!;
                }

                return Card(
                  elevation: index < 3 ? 4 : 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cardBorder,
                      width: index < 3 ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$rankMedal${stat['name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Σύνολο: ${stat['totalProfit'].toStringAsFixed(0)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: stat['totalProfit'] >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildKpiColumn(
                              '${stat['profitPerStremma'].toStringAsFixed(1)} €',
                              'Κέρδος/Στρέμμα',
                              Colors.blue[700]!,
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey[300],
                            ),
                            _buildKpiColumn(
                              '${stat['oilPerTree'].toStringAsFixed(1)} L',
                              'Λάδι/Δέντρο',
                              Colors.amber[700]!,
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey[300],
                            ),
                            _buildKpiColumn(
                              '${stat['costPerTree'].toStringAsFixed(1)} €',
                              'Κόστος/Δέντρο',
                              Colors.red[700]!,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
