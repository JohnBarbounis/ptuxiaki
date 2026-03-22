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

  double currentOilPrice =
      7.50; // Μια μέση αρχική τιμή λαδιού, μπορεί να αλλάξει από τον χρήστη

  // Μεταβλητές για τον Καιρό
  bool isWeatherLoading = true;
  double? currentTemp;
  double? windSpeed;
  int? weatherCode;
  String locationName = 'Φόρτωση...';

  @override
  void initState() {
    super.initState();
    _refreshGroves();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      double lat = 35.3387;
      double lon = 25.1442;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
          lat = position.latitude;
          lon = position.longitude;
        }
      }

      String tempLocation = 'Ηράκλειο';
      try {
        final geoUrl = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=el',
        );
        final geoResponse = await http.get(geoUrl);
        if (geoResponse.statusCode == 200) {
          final geoData = json.decode(geoResponse.body);
          tempLocation =
              geoData['city'] ?? geoData['locality'] ?? 'Άγνωστη Τοποθεσία';
        }
      } catch (e) {}

      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      );
      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final current = data['current_weather'];

        setState(() {
          currentTemp = current['temperature'];
          windSpeed = current['windspeed'];
          weatherCode = current['weathercode'];
          locationName = tempLocation;
          isWeatherLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        locationName = 'Αδυναμία εύρεσης';
        isWeatherLoading = false;
      });
    }
  }

  Map<String, dynamic> _getSmartFarmingAdvice() {
    if (weatherCode == null || windSpeed == null)
      return {
        'icon': Icons.help,
        'color': Colors.grey,
        'msg': 'Αδυναμία φόρτωσης καιρού.',
      };
    if (windSpeed! > 15.0)
      return {
        'icon': Icons.air,
        'color': Colors.orange,
        'msg': 'Δυνατός αέρας. Αποφύγετε τον ψεκασμό σήμερα.',
      };
    if (weatherCode! >= 51 && weatherCode! <= 67)
      return {
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'msg': 'Βρέχει. Ιδανικό για ρίψη λιπάσματος, ακατάλληλο για ράντισμα.',
      };
    if (currentTemp != null && currentTemp! > 35.0)
      return {
        'icon': Icons.wb_sunny,
        'color': Colors.red,
        'msg':
            'Καύσωνας. Ποτίστε τα ελαιόδεντρα, αποφύγετε εργασίες το μεσημέρι.',
      };
    return {
      'icon': Icons.check_circle,
      'color': Colors.green,
      'msg': 'Ιδανικές συνθήκες για όλες τις αγροτικές εργασίες.',
    };
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

  // Συνάρτηση για αλλαγή της Τιμής Λαδιού ---
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
                if (newPrice != null) {
                  setState(() => currentOilPrice = newPrice);
                }
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
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Επιλογή Περιόδου',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    title: const Text('Από:'),
                    subtitle: Text(
                      '${tempStart.day}/${tempStart.month}/${tempStart.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
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
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    title: const Text('Έως:'),
                    subtitle: Text(
                      '${tempEnd.day}/${tempEnd.month}/${tempEnd.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
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
                  onPressed: () {
                    if (tempStart.isAfter(tempEnd)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Λάθος ημερομηνίες!')),
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      DateTimeRange(start: tempStart, end: tempEnd),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: const Text(
                    'ΕΦΑΡΜΟΓΗ',
                    style: TextStyle(color: Colors.white),
                  ),
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
    final weatherAdvice = _getSmartFarmingAdvice();

    // Υπολογισμός Κέρδους
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
            tooltip: 'Ημερολόγιο Εργασιών',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Εξαγωγή σε PDF',
            onPressed: () async {
              // Δείχνουμε ένα μήνυμα "Αναμονής"
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Δημιουργία PDF... Παρακαλώ περιμένετε.'),
                ),
              );
              // Καλούμε το Service που φτιάξαμε!
              await PdfService.generateAndShareReport(currentOilPrice);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : ListView(
              children: [
                // ΚΑΙΡΟΣ
                if (!isWeatherLoading && currentTemp != null)
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.lightBlue[100]!, Colors.blue[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.blueGrey,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                  '${currentTemp}°C',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.air, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Text(
                                  '${windSpeed} km/h',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Icon(
                              weatherAdvice['icon'],
                              color: weatherAdvice['color'],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                weatherAdvice['msg'],
                                style: TextStyle(
                                  color: weatherAdvice['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // DASHBOARD ΜΕ ΤΑ ΦΙΛΤΡΑ ΚΑΙ ΤΟ ΚΕΡΔΟΣ
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                      const Divider(),

                      // Γραμμή 1: Έξοδα και Λάδι
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

                      // Γραμμή 2: Τιμή Λαδιού και Καθαρό Κέρδος
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Κουμπί για αλλαγή τιμής
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
                            // Εμφάνιση Καθαρού Κέρδους
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
                                        : Colors
                                              .red, // Πράσινο αν έχει κέρδος, κόκκινο αν εχει ζημία
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                // Η ΛΙΣΤΑ ΜΕ ΤΑ ΧΩΡΑΦΙΑ
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
                                    "Είστε σίγουροι; Η διαγραφή του χωραφιού θα διαγράψει οριστικά ΚΑΙ ΟΛΕΣ τις εργασίες/συγκομιδές που έχετε καταχωρήσει σε αυτό!",
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
