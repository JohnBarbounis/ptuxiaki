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

  // ΝΕΕΣ Μεταβλητές για το Global Dashboard
  double totalAppExpenses = 0.0;
  double totalAppRevenue = 0.0;
  String _selectedFilter = 'all';
  DateTimeRange? _customDateRange;

  // Μεταβλητές για τον Καιρό (14 Ημερών)
  bool isWeatherLoading = true;
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

  // --- ΣΥΝΑΡΤΗΣΕΙΣ ΚΑΙΡΟΥ (Από το προηγούμενο βήμα) ---
  Future<void> _fetchUnifiedWeather() async {
    double lat = 35.3387;
    double lon = 25.1442;
    String tempLocation = 'Ηράκλειο (Προεπιλογή)';

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied)
          permission = await Geolocator.requestPermission();
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
      print('GPS Timeout.');
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
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=14&timezone=auto',
      );
      final weatherResponse = await http
          .get(weatherUrl)
          .timeout(const Duration(seconds: 5));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        setState(() {
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

  IconData _getWeatherIcon(int code) {
    if (code <= 3) return Icons.wb_sunny;
    if (code <= 48) return Icons.cloud;
    if (code <= 67) return Icons.water_drop;
    if (code <= 77) return Icons.ac_unit;
    return Icons.flash_on;
  }

  // --- ΣΥΝΑΡΤΗΣΕΙΣ ΔΕΔΟΜΕΝΩΝ ---
  Future<void> _refreshGroves() async {
    setState(() => isLoading = true);
    myGroves = await DatabaseHelper.instance.getAllGroves();

    // Ανάκτηση Εξόδων ΚΑΙ Εσόδων από τη βάση
    totalAppExpenses = await DatabaseHelper.instance.getTotalExpenses(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );
    totalAppRevenue = await DatabaseHelper.instance.getTotalRevenue(
      filter: _selectedFilter,
      start: _customDateRange?.start,
      end: _customDateRange?.end,
    );

    setState(() => isLoading = false);
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

  // ΝΕΟ WIDGET: Κάρτα Οικονομικού Δείκτη
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Olive Manager',
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
              // Σημείωση: Πρέπει να προσαρμόσεις το PDF service αν έχεις αφαιρέσει το currentOilPrice
              await PdfService.generateAndShareReport(0.0);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : ListView(
              children: [
                // 1. ΠΡΟΓΝΩΣΗ ΚΑΙΡΟΥ (Συμπαγής)
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
                          "Καιρός Περιοχής: $locationName",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dailyDates.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                    ],
                  ),

                // 2. ΝΕΟ GLOBAL DASHBOARD ΟΙΚΟΝΟΜΙΚΩΝ
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
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
                    icon: const Icon(Icons.checklist, color: Colors.white),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                // 4. ΛΙΣΤΑ ΧΩΡΑΦΙΩΝ
                myGroves.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Δεν έχετε προσθέσει κανένα χωράφι.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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
                                  style: TextStyle(color: Colors.grey[600]),
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
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
