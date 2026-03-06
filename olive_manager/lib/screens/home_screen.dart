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

  @override
  void initState() {
    super.initState();
    _refreshGroves(); // Φόρτωσε τα χωράφια με το που ανοίγει η εφαρμογή
  }

  // Συνάρτηση που διαβάζει τα δεδομένα από την SQLite
  Future<void> _refreshGroves() async {
    setState(() => isLoading = true);

    // Ζητάμε από τη βάση όλα τα χωράφια
    myGroves = await DatabaseHelper.instance.getAllGroves();

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
      // Αν φορτώνει, δείξε κυκλάκι. Αλλιώς, αν είναι άδεια δείξε μήνυμα, αλλιώς τη λίστα.
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : myGroves.isEmpty
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
                return Card(
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${grove.treeCount} δέντρα'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Άνοιγμα λεπτομερειών χωραφιού
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              GroveDetailsScreen(grove: grove),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddGrove,
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
