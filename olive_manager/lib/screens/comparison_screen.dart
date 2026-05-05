// Αρχείο: lib/screens/comparison_screen.dart
import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _overallStats = [];
  List<int> _availableYears = [];
  int? _selectedYear;
  Map<int, List<Map<String, dynamic>>> _yearlyStats = {};
  Map<int, double> _yearlyTotalProfits = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final groves = await DatabaseHelper.instance.getAllGroves();
    List<Map<String, dynamic>> overall = [];
    Set<int> yearsSet = {};
    Map<int, List<Map<String, dynamic>>> tempYearlyStats = {};
    Map<int, double> tempYearlyTotals = {};

    for (var grove in groves) {
      final tasks = await DatabaseHelper.instance.getTasksForGrove(grove.id);
      final harvests = await DatabaseHelper.instance.getHarvestsForGrove(
        grove.id,
      );

      // --- 1. ΥΠΟΛΟΓΙΣΜΟΣ ΣΥΝΟΛΙΚΩΝ ---
      double totalCost = 0.0, totalRevenue = 0.0, totalOil = 0.0;
      for (var t in tasks) {
        totalCost += t.cost;
      }
      for (var h in harvests) {
        totalRevenue += (h.oilVolume * h.pricePerUnit);
        totalOil += h.oilVolume;
      }

      double totalProfit = totalRevenue - totalCost;
      // ΝΕΟ: Υπολογισμός Σκορ Αποδοτικότητας (ROI)
      double roi = totalCost > 0
          ? (totalProfit / totalCost) * 100
          : (totalProfit > 0 ? 100.0 : 0.0);

      overall.add({
        'name': grove.name,
        'profitPerStremma': grove.area > 0 ? totalProfit / grove.area : 0,
        'oilPerStremma': grove.area > 0
            ? totalOil / grove.area
            : 0, // ΑΛΛΑΓΗ: Λάδι ανά Στρέμμα αντί για δέντρο
        'costPerStremma': grove.area > 0
            ? totalCost / grove.area
            : 0, // ΑΛΛΑΓΗ: Κόστος ανά Στρέμμα
        'totalProfit': totalProfit,
        'costPerLiter': totalOil > 0 ? totalCost / totalOil : 0.0,
        'roi': roi, // Το Σκορ Αποδοτικότητας
      });

      // --- 2. ΥΠΟΛΟΓΙΣΜΟΣ ΑΝΑ ΕΤΟΣ ---
      for (var t in tasks) {
        yearsSet.add(t.date.year);
      }
      for (var h in harvests) {
        yearsSet.add(h.date.year);
      }

      for (int year in yearsSet) {
        double yearCost = 0.0, yearRevenue = 0.0;

        for (var t in tasks.where((t) => t.date.year == year)) {
          yearCost += t.cost;
        }
        for (var h in harvests.where((h) => h.date.year == year)) {
          yearRevenue += (h.oilVolume * h.pricePerUnit);
        }

        double yearProfit = yearRevenue - yearCost;
        double yearRoi = yearCost > 0
            ? (yearProfit / yearCost) * 100
            : (yearProfit > 0 ? 100.0 : 0.0);
        double yearProfitPerStremma = grove.area > 0
            ? yearProfit / grove.area
            : 0;

        if (!tempYearlyStats.containsKey(year)) tempYearlyStats[year] = [];
        tempYearlyTotals[year] = (tempYearlyTotals[year] ?? 0.0) + yearProfit;

        tempYearlyStats[year]!.add({
          'name': grove.name,
          'yearProfit': yearProfit,
          'yearCost': yearCost,
          'yearRevenue': yearRevenue,
          'yearProfitPerStremma': yearProfitPerStremma,
          'yearRoi': yearRoi, // Το Σκορ Αποδοτικότητας του έτους
        });
      }
    }

    // Ταξινόμηση
    overall.sort(
      (a, b) => b['profitPerStremma'].compareTo(a['profitPerStremma']),
    );
    List<int> sortedYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));
    for (int year in sortedYears) {
      tempYearlyStats[year]?.sort(
        (a, b) =>
            b['yearProfitPerStremma'].compareTo(a['yearProfitPerStremma']),
      );
    }

    setState(() {
      _overallStats = overall;
      _availableYears = sortedYears;
      _yearlyStats = tempYearlyStats;
      _yearlyTotalProfits = tempYearlyTotals;
      _selectedYear = sortedYears.isNotEmpty ? sortedYears.first : null;
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
            fontSize: 14,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // Βοηθητικό Widget για το Ταμπελάκι Αποδοτικότητας (Badge)
  Widget _buildRoiBadge(double roi) {
    Color badgeColor;
    String text;
    IconData icon;

    if (roi >= 100) {
      badgeColor = Colors.green[700]!;
      text = 'Άριστη (${roi.toStringAsFixed(0)}%)';
      icon = Icons.star;
    } else if (roi >= 20) {
      badgeColor = Colors.blue[600]!;
      text = 'Καλή (${roi.toStringAsFixed(0)}%)';
      icon = Icons.thumb_up;
    } else if (roi >= 0) {
      badgeColor = Colors.orange[600]!;
      text = 'Οριακή (${roi.toStringAsFixed(0)}%)';
      icon = Icons.warning_amber;
    } else {
      badgeColor = Colors.red[700]!;
      text = 'Ζημιά (${roi.toStringAsFixed(0)}%)';
      icon = Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Οικονομική Ανάλυση',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green[300],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'ΣΥΝΟΛΙΚΑ'),
            Tab(icon: Icon(Icons.calendar_month), text: 'ΑΝΑ ΕΤΟΣ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // --- TAB 1: ΣΥΝΟΛΙΚΑ ---
                _overallStats.isEmpty
                    ? const Center(child: Text('Δεν υπάρχουν δεδομένα.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _overallStats.length,
                        itemBuilder: (context, index) {
                          final stat = _overallStats[index];
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$rankMedal${stat['name']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // ΝΕΟ: Εμφάνιση του Ταμπελακίου Αποδοτικότητας ψηλά δεξιά!
                                      _buildRoiBadge(stat['roi'] ?? 0.0),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (stat['costPerLiter'] > 0)
                                        Text(
                                          'Κόστος Παραγωγής: ${stat['costPerLiter'].toStringAsFixed(2)} €/L',
                                          style: TextStyle(
                                            color: Colors.blue[800],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      Text(
                                        'Καθαρό Ταμείο: ${stat['totalProfit'].toStringAsFixed(0)} €',
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      // ΑΛΛΑΓΗ: Όλοι οι δείκτες πλέον είναι "Ανά Στρέμμα" για να υπάρχει απόλυτη δικαιοσύνη!
                                      _buildKpiColumn(
                                        '${stat['profitPerStremma'].toStringAsFixed(1)} €',
                                        'Κέρδος/Στρέμμα',
                                        Colors.green[700]!,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: Colors.grey[300],
                                      ),
                                      _buildKpiColumn(
                                        '${stat['oilPerStremma'].toStringAsFixed(1)} L',
                                        'Λάδι/Στρέμμα',
                                        Colors.amber[700]!,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: Colors.grey[300],
                                      ),
                                      _buildKpiColumn(
                                        '${stat['costPerStremma'].toStringAsFixed(1)} €',
                                        'Κόστος/Στρέμμα',
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

                // --- TAB 2: ΑΝΑ ΕΤΟΣ ---
                _availableYears.isEmpty
                    ? const Center(
                        child: Text('Δεν υπάρχουν καταχωρημένα έτη.'),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.green[50],
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.date_range,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Επιλογή Έτους: ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    DropdownButton<int>(
                                      value: _selectedYear,
                                      underline: Container(
                                        height: 2,
                                        color: Colors.green,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                      items: _availableYears.map((year) {
                                        return DropdownMenuItem(
                                          value: year,
                                          child: Text(year.toString()),
                                        );
                                      }).toList(),
                                      onChanged: (value) =>
                                          setState(() => _selectedYear = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('Συνολικό Κέρδος Χρονιάς'),
                                      Text(
                                        '${_yearlyTotalProfits[_selectedYear]?.toStringAsFixed(2) ?? 0.0} €',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              (_yearlyTotalProfits[_selectedYear] ??
                                                      0) >=
                                                  0
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount:
                                  _yearlyStats[_selectedYear]?.length ?? 0,
                              itemBuilder: (context, index) {
                                final stat =
                                    _yearlyStats[_selectedYear]![index];
                                final isProfitable = stat['yearProfit'] >= 0;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          stat['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        // ΝΕΟ: Εμφάνιση Αποδοτικότητας και στην ετήσια λίστα
                                        _buildRoiBadge(stat['yearRoi'] ?? 0.0),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Κέρδος ανά στρέμμα: ${stat['yearProfitPerStremma'].toStringAsFixed(1)}€\nΈσοδα: ${stat['yearRevenue'].toStringAsFixed(0)}€ | Έξοδα: ${stat['yearCost'].toStringAsFixed(0)}€',
                                      ),
                                    ),
                                    trailing: Text(
                                      '${stat['yearProfit'].toStringAsFixed(0)} €',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isProfitable
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ],
            ),
    );
  }
}
