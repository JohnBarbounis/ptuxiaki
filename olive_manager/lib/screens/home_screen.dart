import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/olive_grove.dart';
import '../services/database_helper.dart';
import 'add_grove_screen.dart';
import 'grove_details_screen.dart';
import 'upcoming_tasks_screen.dart';
import '../services/pdf_service.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OliveGrove> myGroves = [];
  bool isLoading = false;

  double totalAppExpenses = 0.0;
  double totalAppOil = 0.0;
  String _selectedFilter = 'all';
  DateTimeRange? _customDateRange;

  double currentOilPrice = 7.50;

  // Μεταβλητές για τον Ενοποιημένο Καιρό
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? currentWeatherCode;
  String locationName = 'Φόρτωση...';

  // Λίστες για τις 14 ημέρες
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

  // ΜΙΑ κλήση για όλα τα δεδομένα καιρού (Τώρα για 14 μέρες!)
  Future<void> _fetchUnifiedWeather() async {
    double lat = 35.3387; // Προεπιλογή Ηράκλειο
    double lon = 25.1442;
    String tempLocation = 'Ηράκλειο (Προεπιλογή)';

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 5));

          lat = position.latitude;
          lon = position.longitude;
          tempLocation = 'Τρέχουσα Τοποθεσία';
        }
      }
    } catch (e) {
      print('Το GPS άργησε. Χρήση προεπιλογής.');
    }

    try {
      // Όνομα Περιοχής
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

      // ΚΑΙΡΟΣ: Φέρνουμε Current ΚΑΙ 14-Day Daily
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=14&timezone=auto',
      );
      final weatherResponse = await http
          .get(weatherUrl)
          .timeout(const Duration(seconds: 5));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);

        setState(() {
          // Σημερινά δεδομένα
          currentTemp = data['current_weather']['temperature'];
          windSpeed = data['current_weather']['windspeed'];
          currentWeatherCode = data['current_weather']['weathercode'];

          // Δεδομένα 14 Ημερών
          dailyDates = data['daily']['time'];
          dailyMaxTemps = data['daily']['temperature_2m_max'];
          dailyMinTemps = data['daily']['temperature_2m_min'];
          dailyWeatherCodes = data['daily']['weathercode'];

          locationName = tempLocation;
          isWeatherLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        locationName = 'Εκτός Δικτύου';
        isWeatherLoading = false;
      });
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

  Future<void> _refreshGroves() async {
    setState(() => isLoading = true);
    myGroves = await DatabaseHelper.instance.getAllGroves();
    totalAppExpenses = await DatabaseHelper.instance.getTotalExpenses(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );
    totalAppOil = await DatabaseHelper.instance.getTotalOilProduction(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );
    setState(() => isLoading = false);
  }

  Future<void> _editOilPrice() async {
    final TextEditingController priceController = TextEditingController(
      text: currentOilPrice.toStringAsFixed(2),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Τρέχουσα Τιμή Λαδιού'),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Τιμή ανά λίτρο/κιλό (€)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ΑΚΥΡΩΣΗ'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(priceController.text);
                if (newPrice != null)
                  setState(() => currentOilPrice = newPrice);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              child: const Text(
                'ΑΠΟΘΗΚΕΥΣΗ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickCustomDateRange() async {
    DateTime tempStart =
        _customDateRange?.start ??
        DateTime.now().subtract(const Duration(days: 30));
    DateTime tempEnd = _customDateRange?.end ?? DateTime.now();
    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Επιλογή Περιόδου'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Από:'),
                    subtitle: Text(
                      '${tempStart.day}/${tempStart.month}/${tempStart.year}',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempStart,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null)
                        setDialogState(() => tempStart = picked);
                    },
                  ),
                  ListTile(
                    title: const Text('Έως:'),
                    subtitle: Text(
                      '${tempEnd.day}/${tempEnd.month}/${tempEnd.year}',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempEnd,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null)
                        setDialogState(() => tempEnd = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('ΑΚΥΡΩΣΗ'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DateTimeRange(start: tempStart, end: tempEnd),
                  ),
                  child: const Text('ΕΦΑΡΜΟΓΗ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _selectedFilter = 'custom';
        _customDateRange = pickedRange;
      });
      _refreshGroves();
    } else if (_customDateRange == null) {
      setState(() => _selectedFilter = 'all');
      _refreshGroves();
    }
  }

  Future<void> _navigateToAddGrove() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddGroveScreen()));
    if (result == true) _refreshGroves();
  }

  @override
  Widget build(BuildContext context) {
    final advancedAdvice = _getAdvancedFarmingAdvice();
    final double grossIncome = totalAppOil * currentOilPrice;
    final double netProfit = grossIncome - totalAppExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Τα Χωράφια μου',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Δημιουργία PDF...')),
              );
              await PdfService.generateAndShareReport(currentOilPrice);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : ListView(
              children: [
                // 1. ΠΡΟΓΝΩΣΗ 14 ΗΜΕΡΩΝ ΣΤΗΝ ΚΟΡΥΦΗ
                if (!isWeatherLoading && dailyDates.isNotEmpty)
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
                        child: Text(
                          "Πρόγνωση 14 Ημερών: $locationName",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 110,
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
                              elevation: 2,
                              margin: const EdgeInsets.only(
                                right: 8,
                                bottom: 4,
                                left: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                width: 80,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
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
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Icon(
                                      _getWeatherIcon(dailyWeatherCodes[index]),
                                      color: Colors.blue[600],
                                      size: 28,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${dailyMaxTemps[index].round()}° / ${dailyMinTemps[index].round()}°',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                    ],
                  ),

                // 2. ΣΗΜΕΡΙΝΟΣ ΚΑΙΡΟΣ ΚΑΙ ΕΞΥΠΝΗ ΣΥΜΒΟΥΛΗ
                if (!isWeatherLoading && currentTemp != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.thermostat,
                                  color: Colors.redAccent,
                                ),
                                Text(
                                  ' Τώρα: ${currentTemp}°C',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.air, color: Colors.blueGrey),
                                Text(
                                  ' ${windSpeed} km/h',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: advancedAdvice['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // 3. DASHBOARD ΟΙΚΟΝΟΜΙΚΩΝ
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
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
                            'Οικονομικά Στοιχεία',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _selectedFilter,
                            underline: const SizedBox(),
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
                              if (value == 'custom')
                                await _pickCustomDateRange();
                              else if (value != null) {
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
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Icon(
                                  Icons.trending_down,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const Text(
                                  'Έξοδα',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${totalAppExpenses.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                const Icon(
                                  Icons.water_drop,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                                const Text(
                                  'Λάδι',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${totalAppOil.toStringAsFixed(1)} L',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1, color: Colors.black12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            InkWell(
                              onTap: _editOilPrice,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Τιμή Λαδιού ✎',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${currentOilPrice.toStringAsFixed(2)} €/L',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.black54,
                                  size: 24,
                                ),
                                const Text(
                                  'Καθαρό Κέρδος',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${netProfit > 0 ? '+' : ''}${netProfit.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: netProfit >= 0
                                        ? Colors.green[700]
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. ΚΟΥΜΠΙ ΕΡΓΑΣΙΩΝ
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UpcomingTasksScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: const Text(
                      'Προβολή Μελλοντικών Εργασιών',
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
                    top: 16.0,
                    bottom: 8.0,
                  ),
                  child: Text(
                    'Τα Χωράφια μου',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                // 5. ΛΙΣΤΑ ΧΩΡΑΦΙΩΝ
                myGroves.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Δεν έχετε προσθέσει κανένα χωράφι ακόμα.',
                            style: TextStyle(fontSize: 16),
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
                                builder: (BuildContext context) => AlertDialog(
                                  title: const Text("Διαγραφή Χωραφιού"),
                                  content: const Text(
                                    "Είστε σίγουροι; Θα διαγραφούν οριστικά ΟΛΕΣ οι εργασίες αυτού του χωραφιού!",
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
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              await DatabaseHelper.instance.deleteGrove(
                                grove.id,
                              );
                              _refreshGroves();
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.nature,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                title: Text(
                                  grove.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('${grove.area} στρέμματα'),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GroveDetailsScreen(grove: grove),
                                    ),
                                  );
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddGrove,
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
