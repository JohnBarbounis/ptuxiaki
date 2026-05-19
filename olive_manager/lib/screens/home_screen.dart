import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/backup_service.dart';
import '../models/olive_grove.dart';
import '../services/database_helper.dart';
import 'add_grove_screen.dart';
import 'grove_details_screen.dart';
import 'upcoming_tasks_screen.dart';
import '../services/pdf_service.dart';
import 'calendar_screen.dart';
import 'comparison_screen.dart';
import '../services/agronomist_service.dart';
import '../utils/error_handler.dart';
import '../utils/weather_icons.dart'; //
import '../utils/app_logger.dart'; //
import 'package:connectivity_plus/connectivity_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OliveGrove> myGroves = [];
  bool isLoading = false;

  // Μεταβλητές για το Global Dashboard
  double totalAppExpenses = 0.0;
  double totalAppRevenue = 0.0;
  String _selectedFilter = 'all';
  DateTimeRange? _customDateRange;

  // Μεταβλητές για τον Καιρό (14 Ημερών)
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? currentWeatherCode;
  String locationName = 'Φόρτωση...';
  List<dynamic> dailyDates = [];
  List<dynamic> dailyMaxTemps = [];
  List<dynamic> dailyMinTemps = [];
  List<dynamic> dailyWeatherCodes = [];

  @override
  void initState() {
    super.initState();
    _refreshGroves();
    _fetchUnifiedWeather();
  }

  // --- ΣΥΝΑΡΤΗΣΕΙΣ ΚΑΙΡΟΥ ---
  Future<void> _fetchUnifiedWeather() async {
    try {
      // ✅ Check internet connectivity first
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        setState(() {
          isWeatherLoading = false;
          currentTemp = null;
          windSpeed = null;
          currentWeatherCode = null;
          dailyDates = [];
        });
        // Check mounted BEFORE using context
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Δεν υπάρχει σύνδεση internet. Λειτουργία offline.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      double lat = 35.3387;
      double lon = 25.1442;
      String tempLocation = 'Ηράκλειο';

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            Position position = await Geolocator.getCurrentPosition().timeout(
              const Duration(seconds: 5),
            );
            lat = position.latitude;
            lon = position.longitude;
          }
        }
      } catch (e) {
        AppLogger.warning('GPS Error: $e');
      }

      try {
        final geoUrl = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=el',
        );
        final geoResponse = await http
            .get(geoUrl)
            .timeout(const Duration(seconds: 5));
        if (geoResponse.statusCode == 200) {
          final geoData = json.decode(geoResponse.body);
          tempLocation = geoData['city'] ?? geoData['locality'] ?? tempLocation;
        }

        final weatherUrl = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=14&timezone=auto',
        );
        final weatherResponse = await http
            .get(weatherUrl)
            .timeout(const Duration(seconds: 5));

        if (weatherResponse.statusCode == 200) {
          final data = json.decode(weatherResponse.body);
          setState(() {
            currentTemp = data['current_weather']['temperature'];
            windSpeed = data['current_weather']['windspeed'];
            currentWeatherCode = data['current_weather']['weathercode'];

            dailyDates = data['daily']['time'];
            dailyMaxTemps = data['daily']['temperature_2m_max'];
            dailyMinTemps = data['daily']['temperature_2m_min'];
            dailyWeatherCodes = data['daily']['weathercode'];
            locationName = tempLocation;
            isWeatherLoading = false;
          });
        } else {
          throw Exception(
            'Open-Meteo API returned status ${weatherResponse.statusCode}',
          );
        }
      } catch (e) {
        // ✅ Show offline message instead of mock data
        AppLogger.warning('API Error: $e');
        setState(() {
          currentTemp = null;
          windSpeed = null;
          currentWeatherCode = null;
          dailyDates = [];
          isWeatherLoading = false;
        });
      }
    } catch (e) {
      // ✅ Show user-friendly error message
      // Check mounted BEFORE using context
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getApiErrorMessage(e as Exception)),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red[700],
        ),
      );
      setState(() => isWeatherLoading = false);
    }
  }

  // Ο ΕΞΥΠΝΟΣ ΓΕΩΠΟΝΙΚΟΣ ΑΛΓΟΡΙΘΜΟΣ ΑΠΟΦΑΣΕΩΝ
  Map<String, dynamic> _getAdvancedFarmingAdvice() {
    // 0. Έλεγχος αν υπάρχουν δεδομένα
    if (currentWeatherCode == null ||
        dailyWeatherCodes.isEmpty ||
        windSpeed == null) {
      return {
        'icon': Icons.info_outline,
        'color': Colors.grey,
        'msg': 'Αναμονή δεδομένων καιρού...',
      };
    }

    // Βοηθητική συνάρτηση για μορφοποίηση ημερομηνίας (π.χ. 25/03)
    String formatDate(String dateStr) {
      final parts = dateStr.split('-');
      if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
      return dateStr;
    }

    // --- 1. ΑΜΕΣΟΙ ΠΕΡΙΟΡΙΣΜΟΙ (ΣΗΜΕΡΑ) ---

    // ✅ Βροχή / Χιόνι / Καταιγίδα σήμερα (Κωδικοί >= 51)
    if ((currentWeatherCode ?? 0) >= 51) {
      return {
        'icon': Icons.umbrella,
        'color': Colors.blue,
        'msg':
            'Κακοκαιρία σήμερα. Αποφύγετε την είσοδο στο χωράφι και τους ψεκασμούς.',
      };
    }

    // ✅ Δυνατός άνεμος σήμερα
    if ((windSpeed ?? 0.0) > 15.0) {
      return {
        'icon': Icons.air,
        'color': Colors.orange,
        'msg':
            'Δυνατός άνεμος σήμερα (${windSpeed ?? 0}km/h). Αυστηρό απαγορευτικό για ψεκασμό λόγω αερομεταφοράς!',
      };
    }

    // --- 2. ΣΑΡΩΣΗ ΜΕΛΛΟΝΤΙΚΩΝ ΣΥΝΘΗΚΩΝ (Επόμενες 7 ημέρες) ---

    int? upcomingFrostIndex;
    int? upcomingRainIndex;
    int? upcomingHeatwaveIndex;

    // Ξεκινάμε από το index 1 (Αύριο) έως το 7
    for (int i = 1; i <= 7 && i < dailyWeatherCodes.length; i++) {
      // ✅ Ψάχνουμε τον πρώτο Παγετό (< 2°C)
      if (i < dailyMinTemps.length &&
          dailyMinTemps[i] is num &&
          (dailyMinTemps[i] as num) < 2.0 &&
          upcomingFrostIndex == null) {
        upcomingFrostIndex = i;
      }

      // ✅ Ψάχνουμε την πρώτη μέρα με Βροχή/Καταιγίδα (>= 51)
      if (i < dailyWeatherCodes.length &&
          dailyWeatherCodes[i] is int &&
          (dailyWeatherCodes[i] as int) >= 51 &&
          upcomingRainIndex == null) {
        upcomingRainIndex = i;
      }

      // ✅ Ψάχνουμε τον πρώτο Καύσωνα (> 35°C)
      if (dailyMaxTemps.isNotEmpty &&
          i < dailyMaxTemps.length &&
          dailyMaxTemps[i] is num &&
          (dailyMaxTemps[i] as num) > 35.0 &&
          upcomingHeatwaveIndex == null) {
        upcomingHeatwaveIndex = i;
      }
    }

    // --- 3. ΑΠΟΦΑΣΕΙΣ ΒΑΣΕΙ ΜΕΛΛΟΝΤΙΚΩΝ ΣΥΝΘΗΚΩΝ (Ιεραρχικά) ---

    // Προτεραιότητα 1: Παγετός (Καταστρέφει τα δέντρα αν κλαδευτούν)
    if (upcomingFrostIndex != null && upcomingFrostIndex < dailyDates.length) {
      return {
        'icon': Icons.ac_unit,
        'color': Colors.blueGrey,
        'msg':
            'Κίνδυνος παγετού στις ${formatDate(dailyDates[upcomingFrostIndex])}. Απαγορεύεται αυστηρά το κλάδεμα αυτές τις μέρες.',
      };
    }

    // Προτεραιότητα 2: Καύσωνας (Υδατικό στρες για το δέντρο)
    if (upcomingHeatwaveIndex != null &&
        upcomingHeatwaveIndex < dailyDates.length) {
      return {
        'icon': Icons.local_fire_department,
        'color': Colors.redAccent,
        'msg':
            'Αναμένεται καύσωνας στις ${formatDate(dailyDates[upcomingHeatwaveIndex])}. Προγραμματίστε άρδευση (πότισμα) το συντομότερο.',
      };
    }

    // Προτεραιότητα 3: Βροχή (Ευκαιρία για λίπανση)
    if (upcomingRainIndex != null && upcomingRainIndex < dailyDates.length) {
      if (upcomingRainIndex == 1) {
        // Αν η βροχή είναι αύριο
        return {
          'icon': Icons.warning_amber,
          'color': Colors.orange[700],
          'msg':
              'Αύριο αναμένεται βροχή! Τέλεια ευκαιρία να ρίξετε επιφανειακό λίπασμα σήμερα.',
        };
      } else {
        // Αν η βροχή είναι σε 2 έως 7 μέρες
        return {
          'icon': Icons.grass,
          'color': Colors.green[800],
          'msg':
              'Αναμένεται βροχή στις ${formatDate(dailyDates[upcomingRainIndex])}. Προγραμματίστε τη λίπανση κοντά σε εκείνη τη μέρα.',
        };
      }
    }

    // --- 4. ΠΡΟΕΠΙΛΟΓΗ: ΙΔΑΝΙΚΟΣ ΚΑΙΡΟΣ ---
    return {
      'icon': Icons.wb_sunny,
      'color': Colors.green,
      'msg':
          'Ιδανικός καιρός τις επόμενες μέρες! Προχωρήστε ελεύθερα σε ψεκασμούς, κλαδέματα ή συγκομιδή.',
    };
  }

  // ✅ Use centralized weather icon mapping
  IconData _getWeatherIcon(int code) {
    return WeatherIcons.getWeatherIcon(code);
  }

  // --- ΣΥΝΑΡΤΗΣΕΙΣ ΔΕΔΟΜΕΝΩΝ ---
  Future<void> _refreshGroves() async {
    // ΔΕΝ βάζουμε isLoading = true εδώ για να μην "ασπρίζει" η οθόνη.
    // Ο χρήστης συνεχίζει να βλέπει τα παλιά νούμερα για τα ελάχιστα χιλιοστά του δευτερολέπτου που χρειάζεται η βάση.

    // 1. Τραβάμε τα νέα δεδομένα σε προσωρινές μεταβλητές
    final newGroves = await DatabaseHelper.instance.getAllGroves();

    final newExpenses = await DatabaseHelper.instance.getTotalExpenses(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );

    final newRevenue = await DatabaseHelper.instance.getTotalRevenue(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );

    // 2. Ενημερώνουμε την οθόνη αστραπιαία, μόνο όταν τα έχουμε όλα στα χέρια μας!
    setState(() {
      myGroves = newGroves;
      totalAppExpenses = newExpenses;
      totalAppRevenue = newRevenue;
      isLoading =
          false; // Το κλείνουμε για σιγουριά (σε περίπτωση που ερχόμαστε από το initState)
    });
  }

  Future<void> _pickCustomDateRange() async {
    // Παράδειγμα χρησιμοποιώντας το ενσωματωμένο DateRangePicker του Flutter
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[800]!, // Χρώμα ημερολογίου
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      DateTime startDate = picked.start;
      DateTime endDate = picked.end;

      if (startDate.isAfter(endDate)) {
        final tempDate = startDate;
        startDate = endDate;
        endDate = tempDate;
      }
      // ----------------------------------------------------------------

      setState(() {
        _selectedFilter = 'custom';
        // Αποθηκεύουμε το διορθωμένο (ή ήδη σωστό) εύρος
        _customDateRange = DateTimeRange(start: startDate, end: endDate);
      });

      // Ανανεώνουμε τα δεδομένα στην οθόνη με το νέο φίλτρο
      _refreshGroves();
    }
  }

  Future<void> _navigateToAddGrove() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddGroveScreen()));
    if (!mounted) return;
    if (result == true) _refreshGroves();
  }

  Widget _buildFinancialCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${amount >= 0 && title == 'Κέρδος' ? '+' : ''}${amount.toStringAsFixed(0)}€',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double netProfit = totalAppRevenue - totalAppExpenses;
    final advancedAdvice = _getAdvancedFarmingAdvice(); // Καλούμε τη λογική

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Olive Manager',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
        actions: [
          // ΝΕΟ ΚΟΥΜΠΙ: Σύγκριση Χωραφιών
          IconButton(
            icon: const Icon(Icons.pie_chart, color: Colors.white),
            tooltip: 'Σύγκριση Χωραφιών',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComparisonScreen(),
                ),
              ); // Προϋποθέτει import του comparison_screen.dart ψηλά
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.share,
              color: Colors.white,
            ), // Εικονίδιο Αναφορών
            tooltip: 'Εξαγωγή Δεδομένων',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Εξαγωγή Αναφορών',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // --- ΕΠΙΛΟΓΕΣ PDF ---
                        const Divider(),
                        const ListTile(
                          title: Text(
                            'ΑΝΑΦΟΡΑ PDF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.share, color: Colors.blue),
                          title: const Text('Κοινοποίηση PDF'),
                          subtitle: const Text(
                            'Αποστολή σε Gmail, Drive, Viber',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            PdfService.shareReport();
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.print,
                            color: Colors.blueGrey,
                          ),
                          title: const Text('Προβολή & Εκτύπωση'),
                          onTap: () {
                            Navigator.pop(context);
                            PdfService.printReport();
                          },
                        ),

                        // --- ΕΠΙΛΟΓΕΣ EXCEL ---
                        const Divider(),
                        const ListTile(
                          title: Text(
                            'ΑΡΧΕΙΟ EXCEL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.table_chart,
                            color: Colors.green,
                          ),
                          title: const Text(
                            'Κοινοποίηση Excel (.xlsx)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text(
                            'Ιδανικό για λογιστές και επεξεργασία σε PC',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            BackupService.shareExcelReport();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.save, color: Colors.blue),
                          title: const Text(
                            'Αποθήκευση Excel Τοπικά',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text(
                            'Αποθήκευση στο κινητό σας',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Δημιουργία αρχείου...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            final result =
                                await BackupService.saveExcelLocally();
                            if (!mounted) return;
                            if (result) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Excel αποθηκεύθηκε επιτυχώς!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Σφάλμα κατά την αποθήκευση'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green[700]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.agriculture, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Olive Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Διαχείριση & Αντίγραφα',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                  ),
                ],
              ),
            ),

            // --- ΝΕΟ ΜΕΝΟΥ ΓΙΑ JSON BACKUP (ΜΕ ΕΠΙΛΟΓΕΣ) ---
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('Δημιουργία Backup'),
              subtitle: const Text('Εξαγωγή δεδομένων (JSON)'),
              onTap: () {
                Navigator.pop(context); // Κλείνει το πλαϊνό μενού

                // Ανοίγει ένα BottomSheet για να διαλέξει ο χρήστης
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Επιλογές Backup',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.share, color: Colors.blue),
                          title: const Text('Αποστολή (Share)'),
                          subtitle: const Text('Σε Email, Drive, Viber κ.λπ.'),
                          onTap: () async {
                            // 1. Αποθηκεύουμε τον messenger ΠΡΙΝ κλείσουμε το μενού
                            final messenger = ScaffoldMessenger.of(context);

                            // 2. Κλείνουμε το μενού
                            Navigator.pop(context);

                            // 3. Δείχνουμε το μήνυμα με τη νέα μεταβλητή
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Προετοιμασία...')),
                            );

                            // 4. Εκτελούμε τη χρονοβόρα ενέργεια
                            await BackupService.shareJsonBackup();
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.save_alt,
                            color: Colors.green,
                          ),
                          title: const Text('Αποθήκευση στη Συσκευή'),
                          subtitle: const Text('Επιλογή φακέλου στο κινητό'),
                          onTap: () async {
                            // 1. Αποθηκεύουμε τον messenger ΠΡΙΝ το pop!
                            final messenger = ScaffoldMessenger.of(context);

                            Navigator.pop(context);

                            bool success =
                                await BackupService.saveJsonLocally();

                            if (!mounted) return;
                            // 2. Χρησιμοποιούμε τον αποθηκευμένο messenger μόνο αν mounted
                            if (success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Το Backup αποθηκεύτηκε επιτυχώς!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ακύρωση ή σφάλμα αποθήκευσης.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.settings_backup_restore,
                color: Colors.orange,
              ),
              title: const Text('Επαναφορά Δεδομένων'),
              subtitle: const Text('Από αρχείο .json'),
              onTap: () async {
                Navigator.pop(context);

                // Check mounted before using context in showDialog
                if (!mounted) return;
                // Προειδοποίηση πριν τη διαγραφή της τωρινής βάσης
                bool confirm =
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Προσοχή!'),
                        content: const Text(
                          'Η επαναφορά θα διαγράψει τα τρέχοντα δεδομένα της εφαρμογής και θα τα αντικαταστήσει με αυτά του αρχείου. Είστε σίγουροι;',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ΑΚΥΡΟ'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'ΕΠΑΝΑΦΟΡΑ',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirm) {
                  bool success =
                      await BackupService.importDataFromJson(); // Καλεί το JSON Restore
                  if (!mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Τα δεδομένα επαναφέρθηκαν επιτυχώς!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _refreshGroves(); // Ανανεώνουμε την αρχική οθόνη για να δείξει τα νέα δεδομένα
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Αποτυχία επαναφοράς.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // ΚΑΡΤΑ ΓΕΩΠΟΝΟΥ (Μηνιαία Συμβουλή) ---
                      Builder(
                        builder: (context) {
                          final advice = AgronomistService.getMonthlyAdvice();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  advice['color'].withValues(alpha: 0.1),
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: advice['color'].withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: advice['color'].withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        advice['icon'],
                                        color: advice['color'],
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Γεωπονικό Στάδιο Μήνα',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                advice['month'],
                                                style: TextStyle(
                                                  color: advice['color'],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '• ${advice['stage']}',
                                                  style: TextStyle(
                                                    color: advice['color'],
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        advice['advice'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // --- 1. ΠΡΟΓΝΩΣΗ ΚΑΙΡΟΥ 14 ΗΜΕΡΩΝ ---
                      if (isWeatherLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                          ),
                        )
                      else if (dailyDates.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                top: 16.0,
                                bottom: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Καιρός Περιοχής: $locationName",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                  // ✅ NEW: Refresh button for weather
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      size: 20,
                                      color: Colors.blueGrey,
                                    ),
                                    tooltip: 'Ανανέωση Καιρού',
                                    onPressed: () async {
                                      await _fetchUnifiedWeather();
                                      if (!mounted) return;
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Δεδομένα καιρού ενημερώθηκαν',
                                          ),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 90,
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
                                      width: 65,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.blue[50],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            index == 0
                                                ? "Σήμερα"
                                                : '${dateParts[2]}/${dateParts[1]}',
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

                            // ΤΟ ΕΞΥΠΝΟ ΜΗΝΥΜΑ ΠΟΥ ΕΙΧΕ ΧΑΘΕΙ!
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: advancedAdvice['color'].withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: advancedAdvice['color'].withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    advancedAdvice['icon'],
                                    color: advancedAdvice['color'],
                                    size: 32,
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
                        )
                      else
                        // Κάρτα Σφάλματος Καιρού
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off,
                                color: Colors.orange[800],
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Αδυναμία φόρτωσης καιρού',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                    const Text(
                                      'Ελέγξτε τη σύνδεσή σας στο διαδίκτυο.',
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: Colors.orange[800],
                                ),
                                onPressed: () {
                                  setState(() => isWeatherLoading = true);
                                  _fetchUnifiedWeather();
                                },
                              ),
                            ],
                          ),
                        ),

                      // 2. GLOBAL DASHBOARD ΟΙΚΟΝΟΜΙΚΩΝ
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Συνολική Εικόνα',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _selectedFilter,
                                  underline: const SizedBox(),
                                  icon: const Icon(
                                    Icons.filter_list,
                                    color: Colors.green,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Όλα τα έτη'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'year',
                                      child: Text('Φέτος'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'month',
                                      child: Text('Αυτός ο μήνας'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'custom',
                                      child: Text('Προσαρμοσμένη...'),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    if (value == 'custom') {
                                      await _pickCustomDateRange();
                                    } else if (value != null) {
                                      setState(() {
                                        _selectedFilter = value;
                                        _customDateRange = null;
                                      });
                                      _refreshGroves();
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (_selectedFilter == 'custom' &&
                                _customDateRange != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${_customDateRange!.start.day}/${_customDateRange!.start.month}/${_customDateRange!.start.year} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}/${_customDateRange!.end.year}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),

                            // Οι 3 Κάρτες Οικονομικών
                            Row(
                              children: [
                                _buildFinancialCard(
                                  'Έσοδα',
                                  totalAppRevenue,
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                                _buildFinancialCard(
                                  'Έξοδα',
                                  totalAppExpenses,
                                  Icons.trending_down,
                                  Colors.red,
                                ),
                                _buildFinancialCard(
                                  'Κέρδος',
                                  netProfit,
                                  Icons.account_balance_wallet,
                                  netProfit >= 0 ? Colors.blue : Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. ΚΟΥΜΠΙ ΕΡΓΑΣΙΩΝ
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const UpcomingTasksScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.checklist,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Μελλοντικές Εργασίες',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 24.0,
                          bottom: 8.0,
                        ),
                        child: Text(
                          'Η Περιουσία μου (Χωράφια)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // 4. ΛΙΣΤΑ ΧΩΡΑΦΙΩΝ
                      myGroves.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.landscape_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Δεν έχετε χωράφια ακόμα',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Προσθέστε το πρώτο σας χωράφι για να ξεκινήσετε',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AddGroveScreen(),
                                        ),
                                      ).then((_) => _refreshGroves()),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Προσθήκη Χωραφιού'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: myGroves.length,
                              itemBuilder: (context, index) {
                                final grove = myGroves[index];
                                return Dismissible(
                                  key: Key(grove.id),
                                  direction: DismissDirection.endToStart,
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
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Διαγραφή;"),
                                        content: const Text(
                                          "Θα διαγραφούν ΟΛΕΣ οι εργασίες αυτού του χωραφιού!",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text("ΑΚΥΡΩΣΗ"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text(
                                              "ΔΙΑΓΡΑΦΗ",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance.deleteGrove(
                                      grove.id,
                                    );
                                    if (!mounted) return;
                                    _refreshGroves();
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green[100],
                                        child: const Icon(
                                          Icons.nature,
                                          color: Colors.green,
                                        ),
                                      ),
                                      title: Text(
                                        grove.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${grove.area} στρέμματα',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                GroveDetailsScreen(
                                                  grove: grove,
                                                ),
                                          ),
                                        );
                                        if (!mounted) return;
                                        _refreshGroves();
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddGrove,
        backgroundColor: Colors.green[700],
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
