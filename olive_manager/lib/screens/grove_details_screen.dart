// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart'; // ΝΕΟ: Για τον χάρτη
import 'package:latlong2/latlong.dart'; // ΝΕΟ: Για τις συντεταγμένες

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
  final MapController _mapController = MapController();

  List<Task> tasks = [];
  List<Harvest> harvests = [];
  bool isLoading = false;

  // Οικονομικά Στοιχεία
  double totalCost = 0.0;
  double totalOil = 0.0;
  double totalRevenue = 0.0;

  // Μεταβλητές Καιρού
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? currentWeatherCode;
  List<dynamic> dailyDates = [];
  List<dynamic> dailyMaxTemps = [];
  List<dynamic> dailyMinTemps = [];
  List<dynamic> dailyWeatherCodes = [];

  // Μεταβλητές Χάρτη
  List<LatLng> polygonPoints = [];
  LatLng? mapCenter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    _initializeMapData();
    _loadData();
    _fetchUnifiedGroveWeather();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- ΝΕΟ: Αρχικοποίηση Δεδομένων Χάρτη ---
  void _initializeMapData() {
    polygonPoints = widget.grove.getPolygon();

    // Αν έχουμε πολύγωνο, βρίσκουμε το κέντρο του για να κεντράρουμε τον χάρτη
    if (polygonPoints.isNotEmpty) {
      double latSum = 0;
      double lngSum = 0;
      for (var p in polygonPoints) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      mapCenter = LatLng(
        latSum / polygonPoints.length,
        lngSum / polygonPoints.length,
      );
    }
    // Αν δεν έχουμε πολύγωνο αλλά έχουμε απλό σημείο (από παλιά εγγραφή)
    else if (widget.grove.lat != null && widget.grove.lng != null) {
      mapCenter = LatLng(widget.grove.lat!, widget.grove.lng!);
    }
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
    for (var t in fetchedTasks) {
      cost += t.cost;
    }

    double oil = 0.0, revenue = 0.0;
    for (var h in fetchedHarvests) {
      oil += h.oilVolume;
      revenue += (h.oilVolume * h.pricePerUnit);
    }

    setState(() {
      tasks = fetchedTasks;
      harvests = fetchedHarvests;
      totalCost = cost;
      totalOil = oil;
      totalRevenue = revenue;
      isLoading = false;
    });
  }

  // --- Καιρός 14 Ημερών ---
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

  // --- Έξυπνη Συμβουλή Καιρού ---
  Map<String, dynamic> _getAdvancedFarmingAdvice() {
    if (currentWeatherCode == null ||
        dailyWeatherCodes.isEmpty ||
        windSpeed == null) {
      return {
        'icon': Icons.info_outline,
        'color': Colors.grey,
        'msg': 'Δεν υπάρχουν δεδομένα καιρού (Προσθέστε τοποθεσία).',
      };
    }
    String formatDate(String dateStr) {
      final parts = dateStr.split('-');
      return '${parts[2]}/${parts[1]}';
    }

    if (windSpeed! > 15.0) {
      return {
        'icon': Icons.air,
        'color': Colors.orange,
        'msg':
            'Δυνατός άνεμος σήμερα (${windSpeed}km/h). Απαγορευτικό για ψεκασμό!',
      };
    }
    if (currentWeatherCode! >= 51) {
      return {
        'icon': Icons.umbrella,
        'color': Colors.blue,
        'msg': 'Κακοκαιρία σήμερα. Αποφύγετε τις εργασίες στο χωράφι.',
      };
    }

    int? upcomingBadWeatherIndex, upcomingFrostIndex;
    for (int i = 1; i <= 7 && i < dailyWeatherCodes.length; i++) {
      if (dailyMinTemps[i] < 2.0 && upcomingFrostIndex == null) {
        upcomingFrostIndex = i;
      }
      if (dailyWeatherCodes[i] >= 51 && upcomingBadWeatherIndex == null) {
        upcomingBadWeatherIndex = i;
      }
    }
    if (upcomingFrostIndex != null) {
      return {
        'icon': Icons.ac_unit,
        'color': Colors.blueGrey,
        'msg':
            'Κίνδυνος παγετού στις ${formatDate(dailyDates[upcomingFrostIndex])}. Αποφύγετε τα κλαδέματα.',
      };
    }
    if (upcomingBadWeatherIndex != null) {
      if (upcomingBadWeatherIndex == 1) {
        return {
          'icon': Icons.warning_amber,
          'color': Colors.orange[700],
          'msg':
              'Αύριο αναμένεται κακοκαιρία! Ολοκληρώστε τις επείγουσες εργασίες σήμερα.',
        };
      }
      return {
        'icon': Icons.grass,
        'color': Colors.green[800],
        'msg':
            'Έρχεται κακοκαιρία στις ${formatDate(dailyDates[upcomingBadWeatherIndex])}. Προλάβετε να ρίξετε λίπασμα.',
      };
    }
    return {
      'icon': Icons.wb_sunny,
      'color': Colors.green,
      'msg':
          'Παρατεταμένη καλοκαιρία! Ιδανικές συνθήκες για ψεκασμούς και συγκομιδή.',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Αδυναμία ανοίγματος χάρτη.')),
        );
      }
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

  // --- ΝΕΟ: Εμφάνιση Λεπτομερειών Εργασίας (Ψηφιακή Απόδειξη) ---
  void _showTaskDetails(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header με Εικονίδιο, Τίτλο και Κόστος
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        task.type,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${task.cost.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1.5),

            // Ημερομηνία
            _buildDetailRow(
              Icons.calendar_today,
              'Ημερομηνία',
              '${task.date.day}/${task.date.month}/${task.date.year}',
            ),
            const SizedBox(height: 16),

            // --- ΠΛΑΙΣΙΟ ΣΗΜΕΙΩΣΕΩΝ ---
            const Text(
              'Σημειώσεις / Φάρμακα:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (task.notes.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow[600]!, width: 1),
                ),
                child: Text(
                  task.notes,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Δεν υπάρχουν σημειώσεις για αυτή την εργασία.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Κουμπί Κλεισίματος
            // --- ΚΟΥΜΠΙΑ: ΕΠΕΞΕΡΓΑΣΙΑ & ΚΛΕΙΣΙΜΟ ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text(
                      'ΕΠΕΞΕΡΓΑΣΙΑ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      Navigator.pop(
                        context,
                      ); // 1. Κλείνουμε το αναδυόμενο παράθυρο

                      // 2. Πάμε στην οθόνη προσθήκης, περνώντας της τα δεδομένα!
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTaskScreen(
                            groveId: widget.grove.id,
                            existingTask: task, // Στέλνουμε την εργασία
                          ),
                        ),
                      );

                      // 3. Αν ο χρήστης έκανε αποθήκευση, ανανεώνουμε τη λίστα!
                      if (result == true) {
                        _loadData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ΚΛΕΙΣΙΜΟ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Βοηθητικό Widget για τις γραμμές του Bottom Sheet
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
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
                // --- 1. ΤΟΠΙΚΟΣ ΚΑΙΡΟΣ & ΣΥΜΒΟΥΛΗ ---
                if (widget.grove.lat != null &&
                    !isWeatherLoading &&
                    dailyDates.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90,
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
                                  '$currentTemp°C',
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
                                style: const TextStyle(
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

                // --- 2. ΝΕΟ: ΕΜΦΑΝΙΣΗ ΧΑΡΤΗ ΜΕ ΣΥΝΟΡΑ (POLYGON) ---
                if (mapCenter != null)
                  Container(
                    height:
                        160, // Συμπαγές μέγεθος για να μην πιάνει όλη την οθόνη
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: mapCenter!,
                            initialZoom: 16.5,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.all &
                                  ~InteractiveFlag
                                      .rotate, // Κλειδώνουμε την περιστροφή
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.olive_manager',
                            ),
                            if (polygonPoints.isNotEmpty)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: polygonPoints,
                                    color: Colors.green.withOpacity(0.4),
                                    borderColor: Colors.green[900]!,
                                    borderStrokeWidth: 3,
                                    // isFilled: true,
                                  ),
                                ],
                              ),
                            if (polygonPoints
                                .isEmpty) // Αν έχει μόνο απλό στίγμα (όχι πολύγωνο)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: mapCenter!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.filter_center_focus,
                                color: Colors.green,
                              ),
                              tooltip: 'Κεντράρισμα στο χωράφι',
                              onPressed: () {
                                // Επαναφέρει τον χάρτη στο κέντρο του χωραφιού με animation
                                _mapController.move(mapCenter!, 16.5);
                              },
                            ),
                          ),
                        ),
                        // Κουμπί Πλοήγησης (Google Maps) που επιπλέει πάνω στον χάρτη μας
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.extended(
                            heroTag: 'nav_btn',
                            backgroundColor: Colors.blue[700],
                            icon: const Icon(
                              Icons.directions,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'Πλοήγηση',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: _navigateToMap,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                            'Προσθέστε τοποθεσία στο χωράφι (εικονίδιο επεξεργασίας) για να βλέπετε τον χάρτη και τον καιρό.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- 3. ΟΙΚΟΝΟΜΙΚΟ DASHBOARD ---
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Έξοδα',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            '${totalCost.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey[300]),
                      Column(
                        children: [
                          const Text(
                            'Έσοδα',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            '${totalRevenue.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey[300]),
                      Column(
                        children: [
                          const Text(
                            'Καθαρό Κέρδος',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(totalRevenue - totalCost) >= 0 ? '+' : ''}${(totalRevenue - totalCost).toStringAsFixed(2)}€',
                            style: TextStyle(
                              color: (totalRevenue - totalCost) >= 0
                                  ? Colors.green[800]
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // --- ΝΕΟ: ΓΕΩΠΟΝΙΚΟ DASHBOARD (ΔΕΙΚΤΕΣ ΔΕΝΤΡΩΝ) ---
                if (widget.grove.treeCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors
                          .green[50], // Ελαφρύ πράσινο φόντο για να ξεχωρίζει ως "Γεωπονικό"
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Αγρονομικοί Δείκτες',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 1ος Δείκτης: Πυκνότητα Φύτευσης
                            Column(
                              children: [
                                const Icon(
                                  Icons.park,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.grove.area > 0
                                      ? (widget.grove.treeCount /
                                                widget.grove.area)
                                            .toStringAsFixed(1)
                                      : '0',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  'Δέντρα / Στρ.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.green[200],
                            ),

                            // 2ος Δείκτης: Λίτρα ανά Δέντρο
                            Column(
                              children: [
                                const Icon(
                                  Icons.water_drop,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(totalOil / widget.grove.treeCount).toStringAsFixed(1)} L',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  'Λάδι / Δέντρο',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.green[200],
                            ),

                            // 3ος Δείκτης: Κέρδος ανά Δέντρο
                            Column(
                              children: [
                                const Icon(
                                  Icons.euro,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${((totalRevenue - totalCost) / widget.grove.treeCount).toStringAsFixed(1)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: (totalRevenue - totalCost) >= 0
                                        ? Colors.blue[700]
                                        : Colors.red,
                                  ),
                                ),
                                const Text(
                                  'Κέρδος / Δέν.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // Προσθήκη στο UI (π.χ. κάτω από τον χάρτη ή μέσα στο Dashboard)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.park, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.grove.treeCount} Δέντρα',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.straighten,
                        size: 16,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.grove.area} Στρέμματα',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 4. TABS (ΕΡΓΑΣΙΕΣ / ΣΥΓΚΟΜΙΔΗ) ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ΚΑΡΤΕΛΑ 1: ΕΡΓΑΣΙΕΣ
                      ListView.builder(
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
                              await DatabaseHelper.instance.deleteTask(task.id);
                              _loadData();
                            },

                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                // --- ΝΕΟ: Ενεργοποιεί το αναδυόμενο παράθυρο ---
                                onTap: () => _showTaskDetails(context, task),

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
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ), // Αλλάξαμε το trailing για να δείχνει ότι πατιέται!
                              ),
                            ),
                          );
                        },
                      ),

                      // ΚΑΡΤΕΛΑ 2: ΣΥΓΚΟΜΙΔΗ
                      ListView.builder(
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
                                  '${harvest.oilVolume} L @ ${harvest.pricePerUnit} €/L',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Από ${harvest.olivesWeight} kg • Οξύτητα: ${harvest.acidity}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Έσοδα: ${(harvest.oilVolume * harvest.pricePerUnit).toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddHarvestScreen(
                                          groveId: widget.grove.id,
                                          existingHarvest: harvest,
                                        ),
                                      ),
                                    );
                                    if (result == true) _loadData();
                                  },
                                ),
                              ),
                            ),
                          );
                        },
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
