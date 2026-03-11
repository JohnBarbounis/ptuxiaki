// Αρχείο: lib/screens/grove_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../models/harvest.dart';
import '../services/database_helper.dart';
import 'add_task_screen.dart';
import 'add_harvest_screen.dart'; // ΝΕΟ IMPORT

// Προσθέτουμε το SingleTickerProviderStateMixin για να δουλέψουν τα animations των Tabs
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
  double totalOil = 0.0; // Συνολικό λάδι

  @override
  void initState() {
    super.initState();
    // Φτιάχνουμε τον ελεγκτή για 2 καρτέλες
    _tabController = TabController(length: 2, vsync: this);

    // Όταν αλλάζει καρτέλα, ανανεώνουμε την οθόνη (για να αλλάζει το κουμπί +)
    _tabController.addListener(() {
      setState(() {});
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Φορτώνει και τις εργασίες και τις συγκομιδές
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

    double oil = 0.0;
    for (var h in fetchedHarvests) {
      oil += h.oilVolume;
    }

    setState(() {
      tasks = fetchedTasks;
      harvests = fetchedHarvests;
      totalCost = cost;
      totalOil = oil;
      isLoading = false;
    });
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

  // Δυναμική λειτουργία του κουμπιού + ανάλογα με την καρτέλα
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.grove.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        // ΕΔΩ ΜΠΑΙΝΟΥΝ ΤΑ TABS ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ APPBAR
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
          : TabBarView(
              controller: _tabController,
              children: [
                // ---- ΚΑΡΤΕΛΑ 1: ΕΡΓΑΣΙΕΣ ----
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.grove.lat != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: _navigateToMap,
                          icon: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Πλοήγηση',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            minimumSize: const Size(double.infinity, 40),
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
                              await DatabaseHelper.instance.deleteTask(task.id);
                              _loadData();
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.agriculture,
                                  color: Colors.green,
                                ),
                                title: Text(task.title),
                                subtitle: Text(task.type),
                                trailing: Text(
                                  '${task.cost} €',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.amber[50],
                      child: Column(
                        children: [
                          const Text(
                            'Συνολικό Λάδι (Όλων των ετών)',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${totalOil.toStringAsFixed(1)} L/Kg',
                            style: const TextStyle(
                              fontSize: 28,
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
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.water_drop,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  '${harvest.oilVolume} Λίτρα Λαδιού',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Από ${harvest.olivesWeight} κιλά ελιές • Οξύτητα: ${harvest.acidity}',
                                ),
                                trailing: Text(
                                  '${harvest.date.day}/${harvest.date.month}/${harvest.date.year}',
                                  style: const TextStyle(color: Colors.grey),
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
      // Το κουμπί + αλλάζει όνομα (και λειτουργία) ανάλογα την καρτέλα!
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
