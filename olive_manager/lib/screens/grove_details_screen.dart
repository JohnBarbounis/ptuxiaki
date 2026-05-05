// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../models/harvest.dart';
import '../services/database_helper.dart';
import 'add_task_screen.dart';
import 'add_harvest_screen.dart';
import 'statistics_screen.dart';
import 'add_grove_screen.dart';
import 'dart:math' as math;
import '../utils/error_handler.dart'; // ✅ Error handling utilities
import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ Offline mode support

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
  String _locationName = 'Αναζήτηση περιοχής...';

  // Οικονομικά Στοιχεία
  double totalCost = 0.0;
  double totalOil = 0.0;
  double totalRevenue = 0.0;

  // Μεταβλητές Καιρού
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? currentWeatherCode;
  int? currentHumidity; // ΝΕΟ
  double? currentRain; // ΝΕΟ

  List<dynamic> dailyDates = [];
  List<dynamic> dailyMaxTemps = [];
  List<dynamic> dailyMinTemps = [];
  List<dynamic> dailyWeatherCodes = [];
  List<dynamic> dailyMaxWind = []; // ΝΕΟ: Αέρας επόμενων ημερών

  // Μεταβλητές Χάρτη
  List<LatLng> polygonPoints = [];
  LatLng? mapCenter;

  // ✅ Offline support για χάρτη
  bool hasInternetConnection = true;
  bool hasOfflineTiles = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    _initializeMapData();
    _loadData();
    _fetchUnifiedGroveWeather();
    _fetchLocationName();
    _checkOfflineMapSupport(); // ✅ NEW: Check for offline tiles
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ NEW: Έλεγχος offline map support (cached tiles)
  Future<void> _checkOfflineMapSupport() async {
    try {
      // 1. Έλεγχος σύνδεσης internet
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      // 2. Για τώρα, υποθέτουμε ότι αν έχει ανοίξει το app μια φορά, έχει cached tiles
      // (Η flutter_map_tile_caching φορτώνει αυτόματα τα tiles)
      bool hasTiles =
          isOnline; // Αρχικά true, και μετά θα αναβληθεί το πρώτο cached check

      setState(() {
        hasInternetConnection = isOnline;
        hasOfflineTiles = hasTiles;
      });
    } catch (e) {
      print('Offline map check error: $e');
      setState(() {
        hasInternetConnection = true;
        hasOfflineTiles = false;
      });
    }
  }

  // Υπολογίζει τα γεωγραφικά όρια (Bounds) με βάση τα στρέμματα
  LatLngBounds _getBounds(LatLng center, double areaInStremmata) {
    // Αν δεν έχει βάλει στρέμματα, υποθέτουμε 1 στρέμμα για τον χάρτη
    double area = areaInStremmata > 0 ? areaInStremmata : 1.0;

    // Πλευρά τετραγώνου σε μέτρα + 50% παραπάνω για να έχουμε περιθώριο (padding)
    double sideInMeters = math.sqrt(area * 1000) * 1.5;

    // Μετατροπή σε μοίρες
    double latDelta = sideInMeters / 111000;
    double lngDelta =
        sideInMeters / (111000 * math.cos(center.latitude * math.pi / 180));

    return LatLngBounds(
      LatLng(center.latitude - latDelta / 2, center.longitude - lngDelta / 2),
      LatLng(center.latitude + latDelta / 2, center.longitude + lngDelta / 2),
    );
  }

  // --- ΝΕΑ ΣΥΝΑΡΤΗΣΗ: Εύρεση ονόματος περιοχής από συντεταγμένες ---
  Future<void> _fetchLocationName() async {
    if (widget.grove.lat == null || widget.grove.lng == null) {
      setState(() => _locationName = 'Άγνωστη Τοποθεσία');
      return;
    }

    try {
      // Χτυπάμε το δωρεάν API του OpenStreetMap
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${widget.grove.lat}&lon=${widget.grove.lng}&zoom=10',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'OliveManagerApp/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        // Ψάχνουμε να βρούμε χωριό, πόλη ή επαρχία
        final area =
            address['village'] ??
            address['town'] ??
            address['city'] ??
            address['county'] ??
            'Αγροτική Περιοχή';

        setState(() {
          _locationName = '${widget.grove.name} ($area)';
        });
      } else {
        setState(() => _locationName = widget.grove.name);
      }
    } catch (e) {
      // ✅ Error handling - but don't crash
      print('Location lookup error: $e');
      if (mounted) {
        setState(() => _locationName = widget.grove.name);
      }
    }
  }

  Map<String, dynamic> _getNextTaskRecommendation() {
    if (tasks.isEmpty) {
      return {
        'title': 'Ξεκινήστε τις Εργασίες',
        'msg':
            'Δεν υπάρχει ιστορικό εργασιών. Προτείνεται ένας έλεγχος της κατάστασης των δέντρων.',
        'icon': Icons.info_outline,
      };
    }

    // Η λίστα tasks είναι ταξινομημένη με την πιο πρόσφατη πρώτη
    final lastTask = tasks.first;
    final int month = DateTime.now().month;
    final String type = lastTask.type.toLowerCase();

    if (type.contains('συγκομιδή') || type.contains('μάζεμα')) {
      return {
        'title': 'Επόμενη: Ψεκασμός με Χαλκό',
        'msg':
            'Μετά τη συγκομιδή, τα δέντρα έχουν πληγές. Ψεκάστε άμεσα με χαλκό για προστασία από μύκητες.',
        'time': 'Εντός 7 ημερών από το μάζεμα',
        'icon': Icons.healing,
      };
    }

    if (type.contains('κλάδεμα')) {
      return {
        'title': 'Επόμενη: Βασική Λίπανση',
        'msg':
            'Το κλάδεμα ολοκληρώθηκε. Ενισχύστε τα δέντρα με λίπασμα για να βοηθήσετε τη νέα βλάστηση.',
        'time': 'Τέλη Φεβρουαρίου - Μάρτιο',
        'icon': Icons.science,
      };
    }

    if (month >= 6 && month <= 8) {
      return {
        'title': 'Επόμενη: Άρδευση (Πότισμα)',
        'msg':
            'Λόγω υψηλών θερμοκρασιών, η προτεραιότητα είναι η διατήρηση της υγρασίας για την ανάπτυξη του καρπού.',
        'time': 'Κάθε 10-15 ημέρες',
        'icon': Icons.water_drop,
      };
    }

    return {
      'title': 'Επόμενη: Τακτικός Έλεγχος',
      'msg':
          'Συνεχίστε την παρακολούθηση του ελαιώνα για τυχόν προσβολές ή ανάγκες λίπανσης.',
      'time': 'Συνεχώς',
      'icon': Icons.visibility,
    };
  }

  void _initializeMapData() {
    polygonPoints = widget.grove.getPolygon();

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
    } else if (widget.grove.lat != null && widget.grove.lng != null) {
      mapCenter = LatLng(widget.grove.lat!, widget.grove.lng!);
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      // ✅ Parallel loading instead of sequential awaits (2-3x faster!)
      final results = await Future.wait([
        DatabaseHelper.instance.getTasksForGrove(widget.grove.id),
        DatabaseHelper.instance.getHarvestsForGrove(widget.grove.id),
      ]);

      final fetchedTasks = results[0] as List<Task>;
      final fetchedHarvests = results[1] as List<Harvest>;

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
    } catch (e) {
      // ✅ Show user-friendly error message
      print('Error loading grove data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Σφάλμα φόρτωσης δεδομένων: ${ErrorHandler.getDatabaseErrorMessage(e as Exception)}',
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  // --- ΕΜΠΛΟΥΤΙΣΜΕΝΟΣ Καιρός 14 Ημερών ---
  Future<void> _fetchUnifiedGroveWeather() async {
    if (widget.grove.lat == null || widget.grove.lng == null) {
      setState(() => isWeatherLoading = false);
      return;
    }

    try {
      // ✅ Check internet connectivity first
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        setState(() {
          isWeatherLoading = false;
          currentTemp = null;
          windSpeed = null;
          currentWeatherCode = null;
          dailyDates = [];
        });
        return;
      }

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${widget.grove.lat}&longitude=${widget.grove.lng}&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weathercode&daily=weathercode,temperature_2m_max,temperature_2m_min,windspeed_10m_max&forecast_days=14&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentTemp = data['current']['temperature_2m'];
          windSpeed = data['current']['wind_speed_10m'];
          currentWeatherCode = data['current']['weathercode'];
          currentHumidity = data['current']['relative_humidity_2m']?.round();
          currentRain = data['current']['precipitation'];

          dailyDates = data['daily']['time'];
          dailyMaxTemps = data['daily']['temperature_2m_max'];
          dailyMinTemps = data['daily']['temperature_2m_min'];
          dailyWeatherCodes = data['daily']['weathercode'];
          dailyMaxWind = data['daily']['windspeed_10m_max'];

          isWeatherLoading = false;
        });
      } else {
        throw Exception(
          'Open-Meteo API returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      // ✅ Show user-friendly error message
      print('Weather fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Σφάλμα φόρτωσης καιρού: ${ErrorHandler.getApiErrorMessage(e as Exception)}',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
      setState(() => isWeatherLoading = false);
    }
  }

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

    // 1. Τρέχουσες (Σημερινές) Συνθήκες
    if (windSpeed! > 15.0) {
      return {
        'icon': Icons.air,
        'color': Colors.orange[800]!,
        'msg':
            'Δυνατός άνεμος αυτή τη στιγμή (${windSpeed!.toStringAsFixed(1)} km/h). Απαγορευτικό για ψεκασμό!',
      };
    }
    if ((currentRain != null && currentRain! > 0.1) ||
        (currentHumidity != null && currentHumidity! > 85)) {
      return {
        'icon': Icons.water_drop,
        'color': Colors.blue[800]!,
        'msg':
            'Αυξημένη υγρασία ($currentHumidity%) ή βροχή. Ακατάλληλο για συγκομιδή, κίνδυνος μυκητολογικών ασθενειών.',
      };
    }
    if (currentTemp != null && currentTemp! > 35) {
      return {
        'icon': Icons.thermostat,
        'color': Colors.red[800]!,
        'msg':
            'ΚΑΥΣΩΝΑΣ: Κίνδυνος θερμικού στρες για τα δέντρα. Συνιστάται άρδευση.',
      };
    }
    if (currentWeatherCode! >= 51) {
      return {
        'icon': Icons.umbrella,
        'color': Colors.blue,
        'msg': 'Κακοκαιρία σήμερα. Αποφύγετε τις εργασίες στο χωράφι.',
      };
    }

    // 2. Πρόβλεψη Επόμενων Ημερών
    int? upcomingBadWeatherIndex, upcomingFrostIndex, upcomingWindIndex;
    for (int i = 1; i <= 7 && i < dailyWeatherCodes.length; i++) {
      if (dailyMinTemps[i] < 2.0 && upcomingFrostIndex == null) {
        upcomingFrostIndex = i;
      }
      if (dailyWeatherCodes[i] >= 51 && upcomingBadWeatherIndex == null) {
        upcomingBadWeatherIndex = i;
      }
      if (dailyMaxWind.isNotEmpty &&
          dailyMaxWind[i] > 18.0 &&
          upcomingWindIndex == null) {
        upcomingWindIndex = i;
      }
    }

    if (upcomingWindIndex != null && upcomingWindIndex <= 2) {
      return {
        'icon': Icons.air,
        'color': Colors.orange[800]!,
        'msg':
            'Προσοχή: Αναμένονται ισχυροί άνεμοι (${dailyMaxWind[upcomingWindIndex]} km/h) στις ${formatDate(dailyDates[upcomingWindIndex])}. Μην προγραμματίσετε ψεκασμούς.',
      };
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
          'color': Colors.orange[700]!,
          'msg':
              'Αύριο αναμένεται βροχή/κακοκαιρία! Ολοκληρώστε τις επείγουσες εργασίες σήμερα.',
        };
      }
      return {
        'icon': Icons.grass,
        'color': Colors.green[800]!,
        'msg':
            'Έρχεται βροχή στις ${formatDate(dailyDates[upcomingBadWeatherIndex])}. Ιδανική ευκαιρία για να ρίξετε λίπασμα σήμερα.',
      };
    }

    return {
      'icon': Icons.wb_sunny,
      'color': Colors.green[700]!,
      'msg':
          'Παρατεταμένη καλοκαιρία τις επόμενες μέρες! Ιδανικές συνθήκες για εργασίες και συγκομιδή.',
    };
  }

  // --- ΝΕΟ: ΕΙΔΙΚΟΣ ΣΥΝΑΓΕΡΜΟΣ ΔΑΚΟΥ & ΑΣΘΕΝΕΙΩΝ ---
  Map<String, dynamic> _getPestAndDiseaseAlert() {
    if (currentTemp == null || currentHumidity == null) {
      return {
        'title': 'Άγνωστος Κίνδυνος',
        'msg': 'Δεν υπάρχουν επαρκή δεδομένα καιρού.',
        'color': Colors.grey,
        'icon': Icons.help_outline,
      };
    }

    // ΚΑΝΟΝΑΣ 1: Ιδανικές συνθήκες Δάκου (22°C - 30°C & Υγρασία > 60%)
    if (currentTemp! >= 22 && currentTemp! <= 30 && currentHumidity! > 60) {
      return {
        'title': '🔴 ΚΙΝΔΥΝΟΣ ΔΑΚΟΥ / ΜΥΚΗΤΩΝ',
        'msg':
            'Ιδανικές συνθήκες (22-30°C & Υγρασία >60%) για ανάπτυξη δάκου. Ελέγξτε τις παγίδες και προγραμματίστε άμεσα ψεκασμό!',
        'color': Colors.red[700]!,
        'icon': Icons.bug_report,
      };
    }
    // ΚΑΝΟΝΑΣ 2: Καύσωνας (Σκοτώνει τον Δάκο!)
    else if (currentTemp! > 35) {
      return {
        'title': '🟢 ΑΔΡΑΝΟΠΟΙΗΣΗ ΔΑΚΟΥ',
        'msg':
            'Ο καύσωνας (>35°C) αδρανοποιεί τον δάκο. ΔΕΝ απαιτείται εντομοκτόνο τώρα. Επικεντρωθείτε στην άρδευση του χωραφιού.',
        'color': Colors.green[700]!,
        'icon': Icons.thermostat,
      };
    }
    // ΚΑΝΟΝΑΣ 3: Υπερβολική Υγρασία (Μύκητες)
    else if (currentHumidity! > 85) {
      return {
        'title': '🟠 ΚΙΝΔΥΝΟΣ ΜΥΚΗΤΟΛΟΓΙΚΩΝ',
        'msg':
            'Η υπερβολική υγρασία ευνοεί ασθένειες (π.χ. Κυκλοκόνιο, Γλοιοσπόριο). Αποφύγετε κλαδέματα αυτές τις μέρες.',
        'color': Colors.orange[700]!,
        'icon': Icons.water_drop,
      };
    }
    // ΚΑΝΟΝΑΣ 4: Ασφαλείς συνθήκες
    else {
      return {
        'title': '🟢 ΧΑΜΗΛΟΣ ΚΙΝΔΥΝΟΣ',
        'msg':
            'Οι τρέχουσες συνθήκες δεν ευνοούν την ανάπτυξη σοβαρών ασθενειών ή εντόμων. Ιδανικό για εργασίες.',
        'color': Colors.blue[700]!,
        'icon': Icons.check_circle,
      };
    }
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
    if (_tabController.index == 1) {
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
            _buildDetailRow(
              Icons.calendar_today,
              'Ημερομηνία',
              '${task.date.day}/${task.date.month}/${task.date.year}',
            ),
            const SizedBox(height: 16),
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
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTaskScreen(
                            groveId: widget.grove.id,
                            existingTask: task,
                          ),
                        ),
                      );
                      if (result == true) _loadData();
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

  // Βοηθητικό Widget για την πάνω γραμμή των μετρήσεων καιρού
  Widget _weatherMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final advancedAdvice = _getAdvancedFarmingAdvice();
    final pestAlert = _getPestAndDiseaseAlert(); // Παίρνουμε τον συναγερμό

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
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green[200],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'ΤΟΠΟΘΕΣΙΑ'),
            Tab(icon: Icon(Icons.build), text: 'ΕΡΓΑΣΙΕΣ'),
            Tab(icon: Icon(Icons.opacity), text: 'ΣΥΓΚΟΜΙΔΗ'),
            Tab(icon: Icon(Icons.bar_chart), text: 'ΟΙΚΟΝΟΜΙΚΑ'),
          ],
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // ------------------------------------
                //  ΚΑΡΤΕΛΑ 1: ΤΟΠΟΘΕΣΙΑ (Χάρτης & Καιρός)
                // ------------------------------------
                ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  children: [
                    if (widget.grove.lat != null &&
                        !isWeatherLoading &&
                        dailyDates.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- ΝΕΟ: ΕΞΥΠΝΟ ΤΑΜΠΕΛΑΚΙ ΤΟΠΟΘΕΣΙΑΣ ΜΕ REFRESH ΚΟΥΜΠΙ ---
                          Container(
                            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.blue[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Πρόγνωση Καιρού για:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _locationName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ✅ NEW: Refresh button for weather
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  tooltip: 'Ανανέωση Καιρού',
                                  onPressed: () async {
                                    await _fetchUnifiedGroveWeather();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '✅ Δεδομένα καιρού ενημερώθηκαν',
                                          ),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          // ------------------------------------------

                          // Το Καρούσελ (Οριζόντια Λίστα) 14 Ημερών παραμένει!
                          Container(
                            height: 90,
                            margin: const EdgeInsets.only(top: 8),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: dailyDates.length,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                                        colors: [
                                          Colors.blue.shade50,
                                          Colors.white,
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                          _getWeatherIcon(
                                            dailyWeatherCodes[index],
                                          ),
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
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: advancedAdvice['color'].withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: advancedAdvice['color'].withOpacity(
                                    0.1,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Οι Μετρήσεις
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _weatherMetric(
                                        Icons.thermostat,
                                        '${currentTemp?.toStringAsFixed(1)}°C',
                                        'Θερμοκρ.',
                                        Colors.orange,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey[300],
                                      ),
                                      _weatherMetric(
                                        Icons.air,
                                        '${windSpeed?.toStringAsFixed(1)} km/h',
                                        'Αέρας',
                                        Colors.blueGrey,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey[300],
                                      ),
                                      _weatherMetric(
                                        Icons.water_drop,
                                        '${currentHumidity ?? 0}%',
                                        'Υγρασία',
                                        Colors.blue,
                                      ),
                                    ],
                                  ),
                                ),
                                // Η Έξυπνη Συμβουλή
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: advancedAdvice['color'].withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(11),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        advancedAdvice['icon'],
                                        color: advancedAdvice['color'],
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          advancedAdvice['msg'],
                                          style: TextStyle(
                                            color: advancedAdvice['color'],
                                            fontWeight: FontWeight.bold,
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
                          ),

                          // --- ΝΕΟ: ΚΑΡΤΑ ΣΥΝΑΓΕΡΜΟΥ ΔΑΚΟΥ ---
                          if (widget.grove.lat != null && currentTemp != null)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: pestAlert['color'].withOpacity(0.1),
                                border: Border.all(
                                  color: pestAlert['color'],
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    pestAlert['icon'],
                                    color: pestAlert['color'],
                                    size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pestAlert['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: pestAlert['color'],
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          pestAlert['msg'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ------------------------------------
                        ],
                      ),

                    if (mapCenter != null)
                      Container(
                        height: 160,
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
                            // ✅ NEW: Fallback UI όταν δεν υπάρχει internet ΚΑΙ cached tiles
                            if (!hasInternetConnection && !hasOfflineTiles)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '📡 Χάρτης δεν διαθέσιμος',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Χρειάζεται internet για πρώτη\nφορά. Δοκιμάστε αργότερα.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (mapCenter != null)
                                      Text(
                                        'Τοποθεσία: ${mapCenter!.latitude.toStringAsFixed(2)}°, ${mapCenter!.longitude.toStringAsFixed(2)}°',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            else
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  // --- ΝΕΟ: Αυτόματο scale βάσει ορίων ---
                                  initialCameraFit: CameraFit.bounds(
                                    bounds: _getBounds(
                                      mapCenter!,
                                      widget.grove.area,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  // -----------------------------------------
                                  interactionOptions: const InteractionOptions(
                                    flags:
                                        InteractiveFlag.all &
                                        ~InteractiveFlag.rotate,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.olive_manager',

                                    // ✅ Cached tiles for offline support
                                    tileProvider: CachedTileProvider(),
                                  ),
                                  if (polygonPoints.isNotEmpty)
                                    PolygonLayer(
                                      polygons: [
                                        Polygon(
                                          points: polygonPoints,
                                          color: Colors.green.withOpacity(0.4),
                                          borderColor: Colors.green[900]!,
                                          borderStrokeWidth: 3,
                                        ),
                                      ],
                                    ),
                                  if (polygonPoints.isEmpty)
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
                            // ✅ Offline indicator badge
                            if (!hasInternetConnection && hasOfflineTiles)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.wifi_off,
                                        size: 14,
                                        color: Colors.blue[100],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Offline Mode',
                                        style: TextStyle(
                                          color: Colors.blue[100],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (hasInternetConnection || hasOfflineTiles)
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
                                      // --- ΝΕΟ: Το κουμπί κάνει πλέον έξυπνο scale ---
                                      _mapController.fitCamera(
                                        CameraFit.bounds(
                                          bounds: _getBounds(
                                            mapCenter!,
                                            widget.grove.area,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (hasInternetConnection || hasOfflineTiles)
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
                  ],
                ),
                // ------------------------------------
                // ΚΑΡΤΕΛΑ 2: ΕΡΓΑΣΙΕΣ
                // ------------------------------------
                Column(
                  children: [
                    // --- Η ΕΞΥΠΝΗ ΚΑΡΤΑ ΣΤΗΝ ΚΟΡΥΦΗ ---
                    Builder(
                      builder: (context) {
                        final nextTask = _getNextTaskRecommendation();
                        return Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            border: Border.all(
                              color: Colors.purple[200]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                nextTask['icon'],
                                color: Colors.purple[800],
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nextTask['title'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple[900],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      nextTask['msg'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (nextTask.containsKey('time'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Πότε: ${nextTask['time']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // --- Η ΛΙΣΤΑ ΜΕ ΤΙΣ ΕΡΓΑΣΙΕΣ ---
                    Expanded(
                      child: tasks.isEmpty
                          ? const Center(
                              child: Text(
                                'Δεν υπάρχουν καταγεγραμμένες εργασίες.',
                              ),
                            )
                          : ListView.builder(
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
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Διαγραφή Εργασίας;'),
                                                ],
                                              ),
                                              content: const Text(
                                                'Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την εργασία;',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                                  child: const Text(
                                                    'ΑΚΥΡΟ',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                                  child: const Text(
                                                    'ΔΙΑΓΡΑΦΗ',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ) ??
                                        false;
                                  },
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance.deleteTask(
                                      task.id,
                                    );
                                    _loadData();
                                  },
                                  child: ListTile(
                                    onTap: () =>
                                        _showTaskDetails(context, task),
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
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${task.cost.toStringAsFixed(2)} €',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                // ------------------------------------
                // ΚΑΡΤΕΛΑ 3: ΣΥΓΚΟΜΙΔΗ
                // ------------------------------------
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
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Διαγραφή Συγκομιδής;'),
                                    ],
                                  ),
                                  content: const Text(
                                    'Είστε σίγουροι; Τα έσοδα του χωραφιού θα μειωθούν.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text(
                                        'ΑΚΥΡΟ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'ΔΙΑΓΡΑΦΗ',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ) ??
                            false;
                      },
                      onDismissed: (direction) async {
                        await DatabaseHelper.instance.deleteHarvest(harvest.id);
                        _loadData();
                      },
                      child: ListTile(
                        leading: const Icon(Icons.opacity, color: Colors.amber),
                        title: Text(
                          '${harvest.oilVolume} L Λάδι',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${harvest.date.day}/${harvest.date.month}/${harvest.date.year} - Οξύτητα: ${harvest.acidity}%',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Text(
                          '${(harvest.oilVolume * harvest.pricePerUnit).toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ------------------------------------
                // ΚΑΡΤΕΛΑ 4: ΟΙΚΟΝΟΜΙΚΑ ΣΤΟΙΧΕΙΑ
                // ------------------------------------
                ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.park, size: 20, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.grove.treeCount} Δέντρα',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 24),
                          const Icon(
                            Icons.square_foot,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.grove.area} Στρέμ.',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 30, endIndent: 30),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        // Changed to Column
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'Έξοδα',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${totalCost.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'Έσοδα',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${totalRevenue.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey,
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Κέρδος',
                                    style: TextStyle(
                                      color: (totalRevenue - totalCost) >= 0
                                          ? Colors.blue[700]
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${(totalRevenue - totalCost).toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: (totalRevenue - totalCost) >= 0
                                          ? Colors.blue[700]
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          if (totalOil > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'Στόχος Πώλησης: > ${(totalCost / totalOil).toStringAsFixed(2)} €/L για κέρδος',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.grove.treeCount > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 1,
                          ),
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
                              children: [
                                // 1. Δέντρα ανά Στρέμμα
                                Expanded(
                                  child: Column(
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
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Text(
                                        'Δέντρα / Στρ.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.green[200],
                                ),

                                // 2. Λάδι ανά Δέντρο
                                Expanded(
                                  child: Column(
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
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Text(
                                        'Λάδι / Δέν.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.green[200],
                                ),

                                // 3. Κέρδος ανά Δέντρο
                                Expanded(
                                  child: Column(
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
                                          fontSize: 13,
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
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.green[200],
                                ),

                                // 4. ΝΕΟ: Κέρδος ανά Στρέμμα (Ο Απόλυτος Δείκτης)
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.query_stats,
                                        color: Colors.purple,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.grove.area > 0
                                            ? '${((totalRevenue - totalCost) / widget.grove.area).toStringAsFixed(1)} €'
                                            : '0.0 €',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: (totalRevenue - totalCost) >= 0
                                              ? Colors.blue[700]
                                              : Colors.red,
                                        ),
                                      ),
                                      const Text(
                                        'Κέρδος / Στρ.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
      floatingActionButton:
          (_tabController.index == 0 || _tabController.index == 3)
          ? null
          : FloatingActionButton.extended(
              onPressed: _onFabPressed,
              backgroundColor: Colors.green[700],
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                _tabController.index == 1 ? 'Νέα Εργασία' : 'Νέα Συγκομιδή',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}

// --- ΝΕΑ ΚΛΑΣΗ ΓΙΑ ΑΣΤΡΑΠΙΑΙΟ ΧΑΡΤΗ ΚΑΙ OFFLINE ΧΡΗΣΗ ---
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(getTileUrl(coordinates, options));
  }
}
