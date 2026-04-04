// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../models/harvest.dart';
import '../services/database_helper.dart';
import 'add_task_screen.dart';
import 'add_harvest_screen.dart';
import 'statistics_screen.dart';
import 'add_grove_screen.dart';

class GroveDetailsScreen extends StatefulWidget {
  final OliveGrove grove;
  const GroveDetailsScreen({super.key, required this.grove});

  @override
  State<GroveDetailsScreen> createState() => _GroveDetailsScreenState();
}

class _GroveDetailsScreenState extends State<GroveDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Task> tasks = [];
  List<Harvest> harvests = [];
  bool isLoading = false;
  double totalCost = 0.0;
  double totalOil = 0.0;

  // Μεταβλητές για τον Προηγμένο Ενοποιημένο Καιρό 14 Ημερών
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? currentWeatherCode;

  List<dynamic> dailyDates = [];
  List<dynamic> dailyMaxTemps = [];
  List<dynamic> dailyMinTemps = [];
  List<dynamic> dailyWeatherCodes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      setState(() {});
    });

    _loadData();
    _fetchUnifiedGroveWeather();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final fetchedTasks = await DatabaseHelper.instance.getTasksForGrove(
      widget.grove.id,
    );
    final fetchedHarvests = await DatabaseHelper.instance.getHarvestsForGrove(
      widget.grove.id,
    );

    double cost = 0.0;
    for (var t in fetchedTasks) cost += t.cost;

    double oil = 0.0;
    for (var h in fetchedHarvests) oil += h.oilVolume;

    setState(() {
      tasks = fetchedTasks;
      harvests = fetchedHarvests;
      totalCost = cost;
      totalOil = oil;
      isLoading = false;
    });
  }

  // ΝΕΑ ΣΥΝΑΡΤΗΣΗ: Φέρνει τον καιρό 14 Ημερών βάσει συντεταγμένων ΧΩΡΑΦΙΟΥ
  Future<void> _fetchUnifiedGroveWeather() async {
    if (widget.grove.lat == null || widget.grove.lng == null) {
      setState(() => isWeatherLoading = false);
      return;
    }

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=${widget.grove.lat}&longitude=${widget.grove.lng}&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=14&timezone=auto',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentTemp = data['current_weather']['temperature'];
          windSpeed = data['current_weather']['windspeed'];
          currentWeatherCode = data['current_weather']['weathercode'];

          dailyDates = data['daily']['time'];
          dailyMaxTemps = data['daily']['temperature_2m_max'];
          dailyMinTemps = data['daily']['temperature_2m_min'];
          dailyWeatherCodes = data['daily']['weathercode'];

          isWeatherLoading = false;
        });
      } else {
        throw Exception('Αποτυχία API');
      }
    } catch (e) {
      setState(() => isWeatherLoading = false);
    }
  }

  // ΑΛΓΟΡΙΘΜΟΣ ΑΝΑΛΥΣΗΣ: Σαρώνει ολόκληρη την εβδομάδα!
  Map<String, dynamic> _getAdvancedFarmingAdvice() {
    if (currentWeatherCode == null ||
        dailyWeatherCodes.isEmpty ||
        windSpeed == null) {
      return {
        'icon': Icons.info_outline,
        'color': Colors.grey,
        'msg': 'Δεν υπάρχουν δεδομένα καιρού.',
      };
    }

    String formatDate(String dateStr) {
      final parts = dateStr.split('-');
      return '${parts[2]}/${parts[1]}';
    }

    // 1. Άνεμος ΣΗΜΕΡΑ
    if (windSpeed! > 15.0) {
      return {
        'icon': Icons.air,
        'color': Colors.orange,
        'msg':
            'Δυνατός άνεμος σήμερα (${windSpeed}km/h). Απαγορευτικό για ψεκασμό!',
      };
    }

    // 2. Οποιαδήποτε Κακοκαιρία ΣΗΜΕΡΑ (Κωδικοί Open-Meteo >= 51 είναι Βροχή, Χιόνι, Καταιγίδα)
    if (currentWeatherCode! >= 51) {
      return {
        'icon': Icons.umbrella,
        'color': Colors.blue,
        'msg': 'Κακοκαιρία σήμερα. Αποφύγετε τις εργασίες στο χωράφι.',
      };
    }

    // ΣΑΡΩΣΗ ΕΠΟΜΕΝΩΝ 7 ΗΜΕΡΩΝ
    int? upcomingBadWeatherIndex;
    int? upcomingFrostIndex;

    for (int i = 1; i <= 7 && i < dailyWeatherCodes.length; i++) {
      // Ψάχνουμε την ΠΡΩΤΗ μέρα με παγετό
      if (dailyMinTemps[i] < 2.0 && upcomingFrostIndex == null) {
        upcomingFrostIndex = i;
      }
      // Ψάχνουμε την ΠΡΩΤΗ μέρα με ΚΑΚΟΚΑΙΡΙΑ (>= 51)
      if (dailyWeatherCodes[i] >= 51 && upcomingBadWeatherIndex == null) {
        upcomingBadWeatherIndex = i;
      }
    }

    // 3. Παγετός στο μέλλον (Έχει προτεραιότητα γιατί καταστρέφει την παραγωγή)
    if (upcomingFrostIndex != null) {
      return {
        'icon': Icons.ac_unit,
        'color': Colors.blueGrey,
        'msg':
            'Κίνδυνος παγετού στις ${formatDate(dailyDates[upcomingFrostIndex])}. Αποφύγετε τα κλαδέματα.',
      };
    }

    // 4. Βροχή/Καταιγίδα στο μέλλον
    if (upcomingBadWeatherIndex != null) {
      // Αν η κακοκαιρία είναι αύριο (index 1)
      if (upcomingBadWeatherIndex == 1) {
        return {
          'icon': Icons.warning_amber,
          'color': Colors.orange[700],
          'msg':
              'Αύριο αναμένεται κακοκαιρία! Ολοκληρώστε τις επείγουσες εργασίες σήμερα.',
        };
      }
      // Αν η κακοκαιρία είναι πιο μετά
      else {
        return {
          'icon': Icons.grass,
          'color': Colors.green[800],
          'msg':
              'Έρχεται κακοκαιρία στις ${formatDate(dailyDates[upcomingBadWeatherIndex])}. Προλάβετε να ρίξετε λίπασμα ώστε να το ποτίσει η βροχή.',
        };
      }
    }

    // 5. Καλοκαιρία (Αν δεν βρήκε κανένα κωδικό >= 51 στις επόμενες 7 μέρες)
    return {
      'icon': Icons.wb_sunny,
      'color': Colors.green,
      'msg':
          'Καλοκαιρία για τις επόμενες 7 ημέρες! Ιδανικές συνθήκες για ψεκασμούς και συγκομιδή.',
    };
  }

  IconData _getWeatherIcon(int code) {
    if (code <= 3) return Icons.wb_sunny;
    if (code <= 48) return Icons.cloud;
    if (code <= 67) return Icons.water_drop;
    if (code <= 77) return Icons.ac_unit;
    return Icons.flash_on;
  }

  Future<void> _navigateToMap() async {
    if (widget.grove.lat == null || widget.grove.lng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Δεν υπάρχει τοποθεσία.')));
      return;
    }
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.grove.lat},${widget.grove.lng}',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Αδυναμία ανοίγματος χάρτη.')),
        );
    }
  }

  void _onFabPressed() async {
    bool? result;
    if (_tabController.index == 0) {
      result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddTaskScreen(groveId: widget.grove.id),
        ),
      );
    } else {
      result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddHarvestScreen(groveId: widget.grove.id),
        ),
      );
    }
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final advancedAdvice = _getAdvancedFarmingAdvice();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.grove.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Επεξεργασία Χωραφιού',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddGroveScreen(existingGrove: widget.grove),
                ),
              );
              if (result == true) Navigator.pop(context, true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: 'Στατιστικά Εξόδων',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatisticsScreen(
                    groveId: widget.grove.id,
                    groveName: widget.grove.name,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green[200],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.build), text: 'ΕΡΓΑΣΙΕΣ'),
            Tab(icon: Icon(Icons.opacity), text: 'ΣΥΓΚΟΜΙΔΗ'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- ΤΟΠΙΚΟΣ ΚΑΙΡΟΣ & ΣΥΜΒΟΥΛΗ ΓΙΑ ΤΟ ΣΥΓΚΕΚΡΙΜΕΝΟ ΧΩΡΑΦΙ ---
                if (widget.grove.lat != null &&
                    !isWeatherLoading &&
                    dailyDates.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Λίστα 14 Ημερών
                      Container(
                        height:
                            90, // Πιο συμπαγές για να μην πιάνει όλη την οθόνη
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dailyDates.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            final dateParts = dailyDates[index]
                                .toString()
                                .split('-');
                            final formattedDate =
                                '${dateParts[2]}/${dateParts[1]}';
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(
                                right: 6,
                                bottom: 4,
                                left: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Container(
                                width: 70,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade50, Colors.white],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      index == 0 ? "Σήμερα" : formattedDate,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      _getWeatherIcon(dailyWeatherCodes[index]),
                                      color: Colors.blue[600],
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${dailyMaxTemps[index].round()}°/${dailyMinTemps[index].round()}°',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Η Έξυπνη Κάρτα Συμβουλής
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: advancedAdvice['color'].withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: advancedAdvice['color'].withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  advancedAdvice['icon'],
                                  color: advancedAdvice['color'],
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${currentTemp}°C',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                advancedAdvice['msg'],
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Μήνυμα αν δεν υπάρχει τοποθεσία
                if (widget.grove.lat == null)
                  Container(
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_off, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Προσθέστε τοποθεσία στο χωράφι (από το εικονίδιο επεξεργασίας πάνω δεξιά) για να λαμβάνετε προγνώσεις καιρού 14 ημερών.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- ΤΟ ΠΕΡΙΕΧΟΜΕΝΟ ΤΩΝ TABS ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ---- ΚΑΡΤΕΛΑ 1: ΕΡΓΑΣΙΕΣ ----
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.red[50],
                            child: Column(
                              children: [
                                const Text(
                                  'Συνολικά Έξοδα',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${totalCost.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.grove.lat != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 6.0,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _navigateToMap,
                                icon: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Πλοήγηση',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  minimumSize: const Size(double.infinity, 36),
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: tasks.length,
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                return Dismissible(
                                  key: Key(task.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance.deleteTask(
                                      task.id,
                                    );
                                    _loadData();
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.agriculture,
                                        color: Colors.green,
                                      ),
                                      title: Text(
                                        task.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${task.type}\n${task.date.day}/${task.date.month}/${task.date.year}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      isThreeLine: true,
                                      trailing: Text(
                                        '${task.cost.toStringAsFixed(2)} €',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
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

                      // ---- ΚΑΡΤΕΛΑ 2: ΣΥΓΚΟΜΙΔΗ ----
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.amber[50],
                            child: Column(
                              children: [
                                const Text(
                                  'Συνολικό Λάδι',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${totalOil.toStringAsFixed(1)} Λίτρα',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: harvests.length,
                              itemBuilder: (context, index) {
                                final harvest = harvests[index];
                                return Dismissible(
                                  key: Key(harvest.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance.deleteHarvest(
                                      harvest.id,
                                    );
                                    _loadData();
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.water_drop,
                                        color: Colors.amber,
                                      ),
                                      title: Text(
                                        '${harvest.oilVolume} L Λαδιού',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Από ${harvest.olivesWeight} kg • Οξύτητα: ${harvest.acidity}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Text(
                                        '${harvest.date.day}/${harvest.date.month}/${harvest.date.year}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
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
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Νέα Εργασία' : 'Νέα Συγκομιδή',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
