// Αρχείο: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';
import 'add_grove_screen.dart';
import '../services/database_helper.dart';
import 'grove_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OliveGrove> myGroves = [];
  bool isLoading = false; // Μεταβλητή για να δείχνουμε ένα "κυκλάκι" φόρτωσης

  // ΝΕΕΣ ΜΕΤΑΒΛΗΤΕΣ ΓΙΑ ΤΑ ΣΤΑΤΙΣΤΙΚΑ
  double totalAppExpenses = 0.0;
  double totalAppOil = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshGroves(); // Φόρτωσε τα χωράφια με το που ανοίγει η εφαρμογή
  }

  // Συνάρτηση που διαβάζει τα δεδομένα από την SQLite
  Future<void> _refreshGroves() async {
    setState(() => isLoading = true);

    myGroves = await DatabaseHelper.instance.getAllGroves();

    // ΝΕΟ: Ζητάμε από τη βάση τα συνολικά νούμερα
    totalAppExpenses = await DatabaseHelper.instance.getTotalExpenses();
    totalAppOil = await DatabaseHelper.instance.getTotalOilProduction();

    setState(() => isLoading = false);
  }

  Future<void> _navigateToAddGrove() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddGroveScreen()));

    // Αν η φόρμα επέστρεψε true (δηλαδή σώθηκε νέο χωράφι), ξαναδιάβασε τη βάση
    if (result == true) {
      _refreshGroves();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Τα Χωράφια μου',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
      ),
      // Το νέο body με το Dashboard
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                // ---- ΤΟ ΝΕΟ DASHBOARD (ΠΙΝΑΚΑΣ ΕΛΕΓΧΟΥ) ----
                Container(
                  margin: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Στήλη Εξόδων
                      Column(
                        children: [
                          const Icon(
                            Icons.trending_down,
                            color: Colors.red,
                            size: 30,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Συνολικά Έξοδα',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            '${totalAppExpenses.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      // Μια κάθετη γραμμή στη μέση
                      Container(height: 50, width: 1, color: Colors.grey[300]),
                      // Στήλη Παραγωγής
                      Column(
                        children: [
                          const Icon(
                            Icons.water_drop,
                            color: Colors.amber,
                            size: 30,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Συνολικό Λάδι',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            '${totalAppOil.toStringAsFixed(1)} L',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Τα Ελαιοτεμάχιά μου',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // ---- Η ΛΙΣΤΑ ΜΕ ΤΑ ΧΩΡΑΦΙΑ (όπως την είχαμε) ----
                Expanded(
                  child: myGroves.isEmpty
                      ? const Center(
                          child: Text(
                            'Δεν έχετε προσθέσει κανένα χωράφι ακόμα.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
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
                                  builder: (BuildContext context) {
                                    return AlertDialog(
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
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) async {
                                await DatabaseHelper.instance.deleteGrove(
                                  grove.id,
                                );
                                _refreshGroves(); // Ανανεώνει τη λίστα και τα νούμερα στο dashboard

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Το χωράφι και τα δεδομένα του διαγράφηκαν',
                                      ),
                                    ),
                                  );
                                }
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
                                    // Το κάναμε async ώστε μόλις γυρίσει ο χρήστης από το χωράφι να ανανεωθούν τα στατιστικά!
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
                ),
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
